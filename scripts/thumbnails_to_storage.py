"""
下載小紅書縮圖並轉存 Supabase Storage，回寫 thumbnail_url。

小紅書 CDN 縮圖是帶時效簽名的連結，會過期；轉存後 app 可永久讀取。
bucket: resource-thumbnails (public)
路徑: xhs/{external_id}.jpg
"""

import json
import os
import subprocess
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")

SUPABASE_URL = "https://iajbkfbpoaswitawdlpm.supabase.co"
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if not SERVICE_ROLE_KEY:
    sys.exit("SUPABASE_SERVICE_ROLE_KEY environment variable is not set.")
BUCKET = "resource-thumbnails"

SB_HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
}


def sb_json(method, path, body=None, extra=None):
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
    )
    for k, v in {**SB_HEADERS, "Content-Type": "application/json", **(extra or {})}.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="ignore")


def ensure_bucket():
    status, body = sb_json("POST", "/storage/v1/bucket", {"id": BUCKET, "name": BUCKET, "public": True})
    if status in (200, 201):
        print(f"bucket '{BUCKET}' 已建立")
    elif status == 409 or (isinstance(body, str) and "already" in body.lower()):
        print(f"bucket '{BUCKET}' 已存在")
    else:
        print(f"bucket 建立回應 {status}: {body}")


def download(url):
    out = subprocess.run(
        ["curl", "-s", "--max-time", "20", "-L", url],
        capture_output=True, check=False,
    )
    data = out.stdout
    return data if data and len(data) > 1000 else None


def upload(path, data):
    req = urllib.request.Request(
        f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{path}",
        data=data, method="POST",
    )
    for k, v in SB_HEADERS.items():
        req.add_header(k, v)
    req.add_header("Content-Type", "image/jpeg")
    req.add_header("x-upsert", "true")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        print(f"    upload {e.code}: {e.read().decode(errors='ignore')[:150]}")
        return False


def main():
    ensure_bucket()

    _, rows = sb_json(
        "GET",
        "/rest/v1/resource_items?source_type=eq.xiaohongshu&select=id,external_id,thumbnail_url&order=created_at",
    )
    print(f"共 {len(rows)} 筆")

    ok = fail = skipped = 0
    for i, row in enumerate(rows):
        url = row["thumbnail_url"] or ""
        if not url:
            skipped += 1
            continue
        if f"/{BUCKET}/" in url:
            skipped += 1  # 已轉存過
            continue

        data = download(url)
        if data is None:
            print(f"  [{i + 1}/{len(rows)}] 下載失敗 {row['external_id']}")
            fail += 1
            continue

        path = f"xhs/{row['external_id']}.jpg"
        if not upload(path, data):
            fail += 1
            continue

        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{path}"
        status, _ = sb_json(
            "PATCH",
            f"/rest/v1/resource_items?id=eq.{row['id']}",
            {"thumbnail_url": public_url},
            extra={"Prefer": "return=minimal"},
        )
        if status in (200, 204):
            ok += 1
            print(f"  [{i + 1}/{len(rows)}] OK {row['external_id']} ({len(data) // 1024}KB)")
        else:
            fail += 1
        time.sleep(0.3)

    print(f"\n完成：轉存 {ok}，失敗 {fail}，略過 {skipped}")


if __name__ == "__main__":
    main()
