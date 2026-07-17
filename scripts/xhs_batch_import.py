"""
小紅書貼文批次解析 -> 本機 SQLite 資料庫

用法：
    1. 在 Chrome 登入 xiaohongshu.com，打開 DevTools Console，貼上：

        copy(JSON.stringify(document.cookie.split('; ').map(c => {
          const [name, ...rest] = c.split('=');
          return { name, value: rest.join('='), domain: '.xiaohongshu.com', path: '/' };
        })))

       將剪貼簿內容存成 cookies.json（預設讀取 ./cookies.json，可用 --cookies 指定路徑）。

    2. 準備一個文字檔，每行一個小紅書貼文網址（預設讀取 ./urls.txt，可用 --urls 指定路徑）。

    3. 執行：
        python xhs_batch_import.py --urls urls.txt --cookies cookies.json --db resource_items.db

輸出：
    - 寫入本機 SQLite db，欄位對齊 supabase_resource_schema.sql 的 resource_items / resource_import_events
    - 之後要同步到正式 Supabase，可從這個 db 讀出再用 upsert 補上去
"""

import argparse
import json
import re
import sqlite3
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)

INITIAL_STATE_PATTERN = re.compile(
    r"window\.__INITIAL_STATE__\s*=\s*(\{.+?\})\s*</script>", re.DOTALL
)

NOTE_ID_PATTERN = re.compile(r"/(?:explore|discovery/item)/([A-Za-z0-9]+)")

SCHEMA = """
CREATE TABLE IF NOT EXISTS resource_items (
    id TEXT PRIMARY KEY,
    source_type TEXT NOT NULL DEFAULT 'xiaohongshu',
    content_type TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'other',
    title TEXT NOT NULL,
    description_text TEXT,
    author_name TEXT,
    original_url TEXT NOT NULL,
    canonical_url TEXT,
    external_id TEXT,
    thumbnail_url TEXT,
    published_at TEXT,
    tags TEXT,
    import_status TEXT NOT NULL,
    metadata_confidence REAL NOT NULL DEFAULT 0,
    like_count INTEGER,
    collect_count INTEGER,
    comment_count INTEGER,
    ip_location TEXT,
    raw_metadata_snapshot TEXT,
    source_payload TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS resource_import_events (
    id TEXT PRIMARY KEY,
    resource_id TEXT,
    source_type TEXT NOT NULL,
    request_url TEXT NOT NULL,
    status TEXT NOT NULL,
    error_message TEXT,
    parser_mode TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS resource_media_assets (
    id TEXT PRIMARY KEY,
    resource_id TEXT NOT NULL,
    asset_type TEXT NOT NULL,
    remote_url TEXT NOT NULL,
    display_index INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);
"""


def load_cookie_header(cookies_path):
    with open(cookies_path, "r", encoding="utf-8") as f:
        cookies = json.load(f)
    return "; ".join(f"{c['name']}={c['value']}" for c in cookies)


def fetch_html(url, cookie_header, timeout=15):
    req = urllib.request.Request(url)
    req.add_header("Cookie", cookie_header)
    req.add_header("User-Agent", USER_AGENT)
    req.add_header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

    ctx = ssl.create_default_context()
    resp = urllib.request.urlopen(req, timeout=timeout, context=ctx)
    return resp.read().decode("utf-8", errors="ignore")


def parse_initial_state(html):
    match = INITIAL_STATE_PATTERN.search(html)
    if not match:
        return None
    raw = match.group(1).replace("undefined", "null")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def extract_note_id(url):
    match = NOTE_ID_PATTERN.search(url)
    return match.group(1) if match else ""


def first_note_from_state(state):
    try:
        note_map = state["note"]["noteDetailMap"]
    except (KeyError, TypeError):
        return None
    for entry in note_map.values():
        note = entry.get("note")
        if note:
            return note
    return None


def map_note_to_record(note, original_url):
    note_type = note.get("type", "normal")
    content_type = "video" if note_type == "video" else (
        "carousel" if len(note.get("imageList", [])) > 1 else "imagePost"
    )

    image_list = note.get("imageList", [])
    thumbnail_url = image_list[0].get("urlDefault", "") if image_list else ""

    interact = note.get("interactInfo", {})
    published_at = note.get("time")
    published_iso = None
    if isinstance(published_at, (int, float)):
        published_iso = datetime.fromtimestamp(published_at / 1000, tz=timezone.utc).isoformat()

    tags = [t.get("name", "") for t in note.get("tagList", []) if t.get("name")]

    record = {
        "id": str(uuid.uuid4()),
        "source_type": "xiaohongshu",
        "content_type": content_type,
        "category": "other",
        "title": note.get("title") or note.get("desc", "")[:40] or "小紅書收藏",
        "description_text": note.get("desc", ""),
        "author_name": note.get("user", {}).get("nickname", ""),
        "original_url": original_url,
        "canonical_url": original_url,
        "external_id": note.get("noteId", ""),
        "thumbnail_url": thumbnail_url,
        "published_at": published_iso,
        "tags": json.dumps(tags, ensure_ascii=False),
        "import_status": "parsed",
        "metadata_confidence": 0.95,
        "like_count": _safe_int(interact.get("likedCount")),
        "collect_count": _safe_int(interact.get("collectedCount")),
        "comment_count": _safe_int(interact.get("commentCount")),
        "ip_location": note.get("ipLocation", ""),
        "raw_metadata_snapshot": json.dumps(note, ensure_ascii=False)[:8000],
        "source_payload": json.dumps(note, ensure_ascii=False),
    }
    return record, image_list


def _safe_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def make_fallback_record(original_url, error_message):
    return {
        "id": str(uuid.uuid4()),
        "source_type": "xiaohongshu",
        "content_type": "unknown",
        "category": "other",
        "title": "小紅書收藏（待手動補齊）",
        "description_text": "",
        "author_name": "",
        "original_url": original_url,
        "canonical_url": original_url,
        "external_id": extract_note_id(original_url),
        "thumbnail_url": "",
        "published_at": None,
        "tags": "[]",
        "import_status": "failedFallbackSaved",
        "metadata_confidence": 0.0,
        "like_count": None,
        "collect_count": None,
        "comment_count": None,
        "ip_location": "",
        "raw_metadata_snapshot": json.dumps({"error": error_message}),
        "source_payload": "{}",
    }


def ensure_schema(conn):
    conn.executescript(SCHEMA)
    conn.commit()


def insert_record(conn, record, image_list, original_url, status, parser_mode, error_message=None):
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO resource_items (
            id, source_type, content_type, category, title, description_text,
            author_name, original_url, canonical_url, external_id, thumbnail_url,
            published_at, tags, import_status, metadata_confidence,
            like_count, collect_count, comment_count, ip_location,
            raw_metadata_snapshot, source_payload, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            record["id"], record["source_type"], record["content_type"], record["category"],
            record["title"], record["description_text"], record["author_name"],
            record["original_url"], record["canonical_url"], record["external_id"],
            record["thumbnail_url"], record["published_at"], record["tags"],
            record["import_status"], record["metadata_confidence"],
            record["like_count"], record["collect_count"], record["comment_count"],
            record["ip_location"], record["raw_metadata_snapshot"], record["source_payload"],
            now, now,
        ),
    )

    for index, image in enumerate(image_list or []):
        url = image.get("urlDefault", "")
        if not url:
            continue
        conn.execute(
            "INSERT INTO resource_media_assets (id, resource_id, asset_type, remote_url, display_index, created_at) "
            "VALUES (?, ?, 'image', ?, ?, ?)",
            (str(uuid.uuid4()), record["id"], url, index, now),
        )

    conn.execute(
        "INSERT INTO resource_import_events (id, resource_id, source_type, request_url, status, error_message, parser_mode, created_at) "
        "VALUES (?, ?, 'xiaohongshu', ?, ?, ?, ?, ?)",
        (str(uuid.uuid4()), record["id"], original_url, status, error_message, parser_mode, now),
    )
    conn.commit()


def process_url(conn, url, cookie_header, delay_seconds):
    url = url.strip()
    if not url:
        return

    print(f"[parse] {url}")
    try:
        html = fetch_html(url, cookie_header)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
        print(f"  [fail] 連線失敗: {exc}")
        record = make_fallback_record(url, str(exc))
        insert_record(conn, record, [], url, "failedFallbackSaved", "manualFallback", str(exc))
        return

    state = parse_initial_state(html)
    note = first_note_from_state(state) if state else None

    if not note:
        print("  [warn] 無法解析 __INITIAL_STATE__，可能是 cookie 過期或頁面結構改變")
        record = make_fallback_record(url, "INITIAL_STATE not found or cookie expired")
        insert_record(conn, record, [], url, "failedFallbackSaved", "manualFallback", "cookie 可能已過期")
        return

    record, image_list = map_note_to_record(note, url)
    insert_record(conn, record, image_list, url, "parsed", "publicHTML")
    print(f"  [ok] {record['title']}")

    if delay_seconds > 0:
        time.sleep(delay_seconds)


def main():
    parser = argparse.ArgumentParser(description="小紅書貼文批次解析 -> 本機 SQLite")
    parser.add_argument("--urls", default="urls.txt", help="每行一個小紅書貼文網址的文字檔")
    parser.add_argument("--cookies", default="cookies.json", help="從 Chrome 匯出的 cookies.json")
    parser.add_argument("--db", default="resource_items.db", help="輸出的 SQLite 檔案路徑")
    parser.add_argument("--delay", type=float, default=2.0, help="每篇貼文請求間隔秒數，避免過於頻繁")
    args = parser.parse_args()

    try:
        cookie_header = load_cookie_header(args.cookies)
    except FileNotFoundError:
        print(f"找不到 cookies 檔案：{args.cookies}")
        print("請先依照腳本開頭的說明匯出 cookies.json")
        sys.exit(1)

    try:
        with open(args.urls, "r", encoding="utf-8") as f:
            urls = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"找不到網址清單：{args.urls}")
        sys.exit(1)

    if not urls:
        print("網址清單是空的")
        sys.exit(1)

    conn = sqlite3.connect(args.db)
    ensure_schema(conn)

    for url in urls:
        process_url(conn, url, cookie_header, args.delay)

    total = conn.execute("SELECT COUNT(*) FROM resource_items").fetchone()[0]
    parsed = conn.execute("SELECT COUNT(*) FROM resource_items WHERE import_status = 'parsed'").fetchone()[0]
    print(f"\n完成。共 {total} 筆，成功解析 {parsed} 筆，失敗 {total - parsed} 筆。資料庫：{args.db}")
    conn.close()


if __name__ == "__main__":
    main()
