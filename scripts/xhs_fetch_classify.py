"""
小紅書筆記內容抓取 + 智能分類 + 回填 Supabase

繞過台灣 DNS 污染：直接以 curl --resolve 指定真實 CDN IP。
訪客 cookie 即可讀取筆記內容（不需登入）。

流程：
    1. 從 Supabase 讀出 source_type='xiaohongshu' 且 import_status='partial' 的記錄
    2. 逐篇用 curl 抓 HTML，解析 window.__INITIAL_STATE__
    3. 全部抓完後，用 LLM (agnes-2.0-flash) 依標題+標籤智能分類
    4. PATCH 回 Supabase：title / description / tags / author / thumbnail / category / import_status='parsed'
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

SUPABASE_URL = "https://iajbkfbpoaswitawdlpm.supabase.co"
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if not SERVICE_ROLE_KEY:
    sys.exit("SUPABASE_SERVICE_ROLE_KEY environment variable is not set.")
XHS_IP = "43.170.214.10"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

LLM_URL = "https://apihub.agnes-ai.com/v1/chat/completions"
LLM_MODEL = "agnes-2.0-flash"
LLM_KEY = "sk-6gq8qp8kTMsijhHZGUTuWtVJw0sVVZMXWYbQsmYfTL7pRU14"

VALID_CATEGORIES = {"skincare", "fitness", "food", "outfit", "learning", "other"}

SB_HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}

COOKIE_JAR = "xhs_session_cookies.txt"


def sb_request(method, path, body=None, extra_headers=None):
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        data=json.dumps(body).encode("utf-8") if body is not None else None,
        method=method,
    )
    for k, v in SB_HEADERS.items():
        req.add_header(k, v)
    for k, v in (extra_headers or {}).items():
        req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
        return resp.status, json.loads(raw) if raw else None


def init_guest_cookies():
    subprocess.run(
        ["curl", "-s", "--max-time", "25",
         "--resolve", f"www.xiaohongshu.com:443:{XHS_IP}",
         "-c", COOKIE_JAR, "-A", UA,
         "https://www.xiaohongshu.com/explore", "-o", "NUL"],
        check=False,
    )


def fetch_note(url):
    result = subprocess.run(
        ["curl", "-s", "--max-time", "25",
         "--resolve", f"www.xiaohongshu.com:443:{XHS_IP}",
         "-b", COOKIE_JAR, "-c", COOKIE_JAR, "-A", UA, url],
        capture_output=True, check=False,
    )
    html = result.stdout.decode("utf-8", errors="ignore")
    m = re.search(r"window\.__INITIAL_STATE__\s*=\s*(\{.+?\})\s*</script>", html, re.DOTALL)
    if not m:
        return None
    try:
        data = json.loads(m.group(1).replace("undefined", "null"))
    except json.JSONDecodeError:
        return None
    note_map = data.get("note", {}).get("noteDetailMap", {})
    for entry in note_map.values():
        note = entry.get("note")
        if note and (note.get("title") or note.get("desc")):
            return note
    return None


def clean_desc(desc):
    # 移除 #xxx[话题]# 標記，保留正文
    return re.sub(r"#([^#\[]+)\[话题\]#\s*", "", desc or "").strip()


def note_to_update(note):
    tags = [t.get("name", "") for t in note.get("tagList", []) if t.get("name")]
    images = note.get("imageList", [])
    thumbnail = images[0].get("urlDefault", "") if images else ""
    interact = note.get("interactInfo", {})
    published = note.get("time")
    published_iso = None
    if isinstance(published, (int, float)) and published > 0:
        published_iso = datetime.fromtimestamp(published / 1000, tz=timezone.utc).isoformat()

    title = (note.get("title") or "").strip() or clean_desc(note.get("desc", ""))[:40] or "小紅書筆記"
    return {
        "title": title,
        "description_text": clean_desc(note.get("desc", "")),
        "author_name": (note.get("user") or {}).get("nickname", ""),
        "thumbnail_url": thumbnail,
        "published_at": published_iso,
        "tags": tags,
        "import_status": "parsed",
        "metadata_confidence": 0.9,
        "raw_metadata_snapshot": {
            "likedCount": interact.get("likedCount"),
            "collectedCount": interact.get("collectedCount"),
            "commentCount": interact.get("commentCount"),
            "ipLocation": note.get("ipLocation", ""),
            "noteType": note.get("type", ""),
        },
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }


def llm_classify(items):
    """items: list of {id, title, tags}；回傳 {id: category}"""
    lines = [
        f"{i + 1}. 標題:{it['title']} 標籤:{','.join(it['tags'][:6])}"
        for i, it in enumerate(items)
    ]
    prompt = (
        "以下是小紅書筆記清單，請為每篇選一個最合適的分類。\n"
        "可用分類（只能用這六個英文值）：skincare(護膚/美白/美容/保養/抗老), "
        "fitness(瘦身/運動/塑形/拉伸/減脂), food(飲食/食譜/營養/減脂餐), "
        "outfit(穿搭/服飾), learning(知識/方法論/學習), other(其他/養身/中醫/睡眠等無法歸類者)\n"
        "只輸出 JSON 陣列，格式：[{\"n\":1,\"c\":\"fitness\"},...]，不要其他文字。\n\n"
        + "\n".join(lines)
    )
    body = {
        "model": LLM_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
    }
    req = urllib.request.Request(LLM_URL, data=json.dumps(body).encode("utf-8"), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {LLM_KEY}")
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read())
        text = data["choices"][0]["message"]["content"]
        m = re.search(r"\[.*\]", text, re.DOTALL)
        parsed = json.loads(m.group(0))
        result = {}
        for entry in parsed:
            idx = int(entry["n"]) - 1
            cat = entry["c"]
            if 0 <= idx < len(items) and cat in VALID_CATEGORIES:
                result[items[idx]["id"]] = cat
        return result
    except Exception as exc:
        print(f"[llm] 分類失敗，改用關鍵字規則: {exc}")
        return {}


def keyword_classify(title, tags):
    text = title + " " + " ".join(tags)
    rules = [
        ("fitness", ["瘦", "减", "減", "锻炼", "運動", "运动", "拉伸", "塑形", "腿", "腰", "臀", "肚子", "体态", "體態", "驼背", "駝背", "燃脂", "有氧", "训练", "訓練", "青蛙趴", "普拉提", "瑜伽"]),
        ("skincare", ["美白", "护肤", "護膚", "保養", "保养", "皮肤", "皮膚", "面膜", "精华", "精華", "防晒", "防曬", "祛痘", "毛孔", "抗老", "淡斑", "水乳", "洗面", "面部"]),
        ("food", ["食谱", "食譜", "吃", "餐", "饮食", "飲食", "营养", "營養", "料理", "热量", "熱量", "卡路里"]),
        ("outfit", ["穿搭", "衣", "裙", "裤", "褲", "鞋"]),
    ]
    for cat, keywords in rules:
        if any(k in text for k in keywords):
            return cat
    return None


def load_token_urls():
    """從 CSV 讀含 xsec_token 的完整連結（Supabase 裡的 original_url 已被清掉 token）"""
    import csv
    from pathlib import Path
    mapping = {}
    root = Path(__file__).parent.parent.parent
    for name in ["瘦身-小紅書-解析結果.csv", "美白、美容、養身-小紅書-解析結果.csv"]:
        path = root / name
        if not path.exists():
            continue
        with open(path, encoding="utf-8-sig") as f:
            for row in csv.DictReader(f):
                note_id = row.get("筆記ID", "").strip()
                full = (row.get("完整連結", "") or "").strip().strip('"')
                if note_id and full:
                    mapping[note_id] = full
    return mapping


def main():
    print("讀取 Supabase 待補記錄...")
    _, rows = sb_request(
        "GET",
        "/rest/v1/resource_items?source_type=eq.xiaohongshu&import_status=eq.partial"
        "&select=id,original_url,category,external_id&order=created_at",
    )
    print(f"共 {len(rows)} 筆待抓取")
    if not rows:
        return

    token_urls = load_token_urls()
    for row in rows:
        full = token_urls.get(row["external_id"])
        if full:
            row["original_url"] = full

    init_guest_cookies()

    parsed_items = []
    failed = []
    for i, row in enumerate(rows):
        url = row["original_url"]
        note = fetch_note(url)
        if note is None:
            time.sleep(2)
            note = fetch_note(url)  # retry once
        if note is None:
            failed.append(row["external_id"])
            print(f"  [{i + 1}/{len(rows)}] FAIL {row['external_id']}")
        else:
            update = note_to_update(note)
            parsed_items.append({"row": row, "update": update})
            print(f"  [{i + 1}/{len(rows)}] OK {update['title'][:30]}")
        time.sleep(1.5)

    print(f"\n抓取完成：成功 {len(parsed_items)}，失敗 {len(failed)}")

    # 智能分類：LLM 優先，關鍵字規則備援
    print("\n開始智能分類...")
    llm_input = [
        {"id": it["row"]["id"], "title": it["update"]["title"], "tags": it["update"]["tags"]}
        for it in parsed_items
    ]
    categories = {}
    BATCH = 40
    for i in range(0, len(llm_input), BATCH):
        categories.update(llm_classify(llm_input[i:i + BATCH]))

    for it in parsed_items:
        rid = it["row"]["id"]
        cat = categories.get(rid)
        if not cat:
            cat = keyword_classify(it["update"]["title"], it["update"]["tags"]) or it["row"]["category"]
        it["update"]["category"] = cat

    # 回填 Supabase
    print("\n回填 Supabase...")
    ok = 0
    for it in parsed_items:
        rid = it["row"]["id"]
        try:
            status, _ = sb_request(
                "PATCH",
                f"/rest/v1/resource_items?id=eq.{rid}",
                body=it["update"],
                extra_headers={"Prefer": "return=minimal"},
            )
            if status in (200, 204):
                ok += 1
        except Exception as exc:
            print(f"  PATCH 失敗 {rid}: {exc}")

    print(f"\n=== 完成 ===")
    print(f"抓取成功: {len(parsed_items)}/{len(rows)}")
    print(f"回填成功: {ok}/{len(parsed_items)}")
    if failed:
        print(f"抓取失敗的筆記ID: {failed}")

    from collections import Counter
    dist = Counter(it["update"]["category"] for it in parsed_items)
    print(f"分類分布: {dict(dist)}")


if __name__ == "__main__":
    main()
