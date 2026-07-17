"""
將兩份小紅書 CSV 清單 upsert 到 Supabase resource_items。

因為 CSV 只有 URL + 筆記ID + 類型，沒有 title/description，
所以 import_status = 'partial'，app 之後可觸發重新解析補齊欄位。

用法：
    python csv_to_supabase.py
"""

from __future__ import annotations
import csv
import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
import urllib.request
import urllib.error

SUPABASE_URL = "https://iajbkfbpoaswitawdlpm.supabase.co"
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if not SERVICE_ROLE_KEY:
    sys.exit("SUPABASE_SERVICE_ROLE_KEY environment variable is not set.")

NOW = datetime.now(timezone.utc).isoformat()

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates",
}

CSV_FILES = [
    {
        "path": Path(__file__).parent.parent.parent / "瘦身-小紅書-解析結果.csv",
        "category": "fitness",
    },
    {
        "path": Path(__file__).parent.parent.parent / "美白、美容、養身-小紅書-解析結果.csv",
        "category": "skincare",
    },
]


def map_content_type(raw_type: str) -> str:
    return "video" if "影片" in raw_type else "imagePost"


def clean_url(url: str) -> str:
    url = url.strip().strip('"')
    m = re.match(r"(https://www\.xiaohongshu\.com/(?:discovery|explore)/item/[A-Za-z0-9]+)", url)
    return m.group(1) if m else url


def build_record(row: dict, category: str) -> dict:
    note_id = row.get("筆記ID", "").strip()
    raw_url = row.get("完整連結", "") or row.get("短連結", "")
    original_url = clean_url(raw_url)
    canonical_url = f"https://www.xiaohongshu.com/discovery/item/{note_id}" if note_id else original_url
    content_type = map_content_type(row.get("類型", ""))
    seq = row.get("序號", "")

    return {
        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, canonical_url)),
        "source_type": "xiaohongshu",
        "content_type": content_type,
        "category": category,
        "title": f"小紅書筆記 #{seq} ({note_id[:8]})" if note_id else f"小紅書筆記 #{seq}",
        "description_text": "",
        "author_name": "",
        "original_url": original_url,
        "canonical_url": canonical_url,
        "external_id": note_id,
        "thumbnail_url": "",
        "published_at": None,
        "tags": [],
        "import_status": "partial",
        "metadata_confidence": 0.1,
        "media_retention_policy": "metadataOnly",
        "raw_metadata_snapshot": {},
        "source_payload": {},
        "created_at": NOW,
        "updated_at": NOW,
    }


def upsert_batch(records: list[dict]) -> tuple[int, str | None]:
    payload = json.dumps(records).encode("utf-8")
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/resource_items",
        data=payload,
        method="POST",
    )
    for k, v in HEADERS.items():
        req.add_header(k, v)

    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, None
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        return e.code, body


def main():
    all_records: list[dict] = []

    for csv_info in CSV_FILES:
        path = csv_info["path"]
        category = csv_info["category"]
        if not path.exists():
            print(f"[warn] 找不到檔案：{path}")
            continue
        with open(path, encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if not row.get("筆記ID", "").strip():
                    continue
                all_records.append(build_record(row, category))
        print(f"[read] {path.name}：{sum(1 for r in all_records if r['category'] == category)} 筆")

    if not all_records:
        print("沒有可匯入的資料")
        sys.exit(1)

    print(f"\n共 {len(all_records)} 筆，開始 upsert 到 Supabase...")

    BATCH = 25
    success = 0
    for i in range(0, len(all_records), BATCH):
        chunk = all_records[i:i + BATCH]
        status, err = upsert_batch(chunk)
        if status in (200, 201):
            success += len(chunk)
            print(f"  [{i + 1}–{i + len(chunk)}] OK")
        else:
            print(f"  [{i + 1}–{i + len(chunk)}] 失敗 HTTP {status}: {err}")

    print(f"\n完成：{success}/{len(all_records)} 筆成功寫入 Supabase resource_items")


if __name__ == "__main__":
    main()
