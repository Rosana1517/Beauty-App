"""
新增小紅書筆記一條龍：貼連結 -> 全自動入庫

用法：
    1. 把新筆記連結貼進一個文字檔（每行一個，手機分享的 xhslink.com 短連結即可）
    2. 執行：
        python -X utf8 xhs_add_notes.py new_links.txt
        python -X utf8 xhs_add_notes.py new_links.txt --regen   # 同時重新生成情境推薦

自動完成：
    短連結解析（取得含 xsec_token 的完整連結）
    -> 內容抓取（繞過台灣 DNS 污染）
    -> LLM 智能分類
    -> 寫入 resource_items（重複筆記自動略過）
    -> 縮圖轉存 Supabase Storage
    -> （--regen 時）重跑 9 情境預生成推薦
"""

import json
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

import xhs_fetch_classify as core
import thumbnails_to_storage as thumbs

NOTE_ID_PATTERN = re.compile(r"/(?:explore|discovery/item)/([A-Za-z0-9]+)")


def resolve_short_link(url):
    """xhslink.com 短連結 -> 含 xsec_token 的完整連結（只讀 302 Location，不實際連主站）"""
    if "xiaohongshu.com" in url:
        return url
    out = subprocess.run(
        ["curl", "-s", "-o", "NUL", "-w", "%{redirect_url}", "--max-time", "20", "-A", core.UA, url],
        capture_output=True, check=False,
    )
    redirect = out.stdout.decode("utf-8", errors="ignore").strip()
    return redirect if "xiaohongshu.com" in redirect else None


def existing_note_ids():
    _, rows = core.sb_request(
        "GET", "/rest/v1/resource_items?source_type=eq.xiaohongshu&select=external_id"
    )
    return {r["external_id"] for r in rows}


def insert_note(note, full_url, note_id, category):
    update = core.note_to_update(note)
    now = datetime.now(timezone.utc).isoformat()
    row = {
        "id": str(uuid.uuid4()),
        "source_type": "xiaohongshu",
        "content_type": "video" if note.get("type") == "video" else "imagePost",
        "category": category,
        "original_url": full_url,
        "canonical_url": f"https://www.xiaohongshu.com/discovery/item/{note_id}",
        "external_id": note_id,
        "source_payload": {},
        **{k: update[k] for k in (
            "title", "description_text", "author_name", "thumbnail_url",
            "published_at", "tags", "import_status", "metadata_confidence",
            "raw_metadata_snapshot",
        )},
        "created_at": now,
        "updated_at": now,
    }
    status, _ = core.sb_request(
        "POST", "/rest/v1/resource_items", body=row, extra_headers={"Prefer": "return=minimal"}
    )
    return row if status in (200, 201) else None


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    links_file = sys.argv[1]
    regen = "--regen" in sys.argv

    with open(links_file, encoding="utf-8") as f:
        links = [l.strip() for l in f if l.strip().startswith("http")]
    print(f"讀入 {len(links)} 條連結")

    known = existing_note_ids()
    core.init_guest_cookies()

    added = []
    for i, link in enumerate(links):
        full = resolve_short_link(link)
        if not full:
            print(f"  [{i + 1}] 短連結解析失敗: {link}")
            continue
        m = NOTE_ID_PATTERN.search(full)
        note_id = m.group(1) if m else ""
        if not note_id:
            print(f"  [{i + 1}] 無法取得筆記ID: {link}")
            continue
        if note_id in known:
            print(f"  [{i + 1}] 已存在，略過: {note_id}")
            continue

        note = core.fetch_note(full)
        if note is None:
            time.sleep(2)
            note = core.fetch_note(full)
        if note is None:
            print(f"  [{i + 1}] 內容抓取失敗: {note_id}")
            continue

        title = (note.get("title") or "").strip()
        tags = [t.get("name", "") for t in note.get("tagList", []) if t.get("name")]
        added.append({"note": note, "full": full, "note_id": note_id, "title": title, "tags": tags})
        print(f"  [{i + 1}] 抓取成功: {title[:30]}")
        known.add(note_id)
        time.sleep(1.5)

    if not added:
        print("\n沒有新筆記需要入庫")
        return

    # 智能分類（LLM 優先、關鍵字備援）
    print(f"\n分類 {len(added)} 篇...")
    llm_input = [{"id": str(i), "title": a["title"], "tags": a["tags"]} for i, a in enumerate(added)]
    cats = {}
    for i in range(0, len(llm_input), 15):
        cats.update(core.llm_classify(llm_input[i:i + 15]))
    for i, a in enumerate(added):
        a["category"] = cats.get(str(i)) or core.keyword_classify(a["title"], a["tags"]) or "other"

    # 入庫
    ok_rows = []
    for a in added:
        row = insert_note(a["note"], a["full"], a["note_id"], a["category"])
        if row:
            ok_rows.append(row)
            print(f"  入庫: [{a['category']}] {row['title'][:30]}")

    # 縮圖轉存
    print(f"\n轉存 {len(ok_rows)} 張縮圖...")
    for row in ok_rows:
        url = row["thumbnail_url"]
        if not url:
            continue
        data = thumbs.download(url)
        if data is None:
            print(f"  縮圖下載失敗: {row['external_id']}")
            continue
        path = f"xhs/{row['external_id']}.jpg"
        if thumbs.upload(path, data):
            public_url = f"{core.SUPABASE_URL}/storage/v1/object/public/{thumbs.BUCKET}/{path}"
            core.sb_request(
                "PATCH", f"/rest/v1/resource_items?id=eq.{row['id']}",
                body={"thumbnail_url": public_url},
                extra_headers={"Prefer": "return=minimal"},
            )
            print(f"  縮圖 OK: {row['external_id']}")

    print(f"\n=== 完成：新增 {len(ok_rows)} 篇 ===")
    from collections import Counter
    print("分類分布:", dict(Counter(r["category"] for r in ok_rows)))

    if regen:
        print("\n重新生成情境推薦...")
        import pregenerate_recommendations as pregen
        pregen.generate()
    else:
        print("\n提醒：若要讓新筆記進入 AI 推薦，請執行：")
        print("  python -X utf8 pregenerate_recommendations.py")


if __name__ == "__main__":
    main()
