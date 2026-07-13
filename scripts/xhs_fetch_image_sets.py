"""
補抓小紅書筆記的完整圖組 -> Supabase Storage + resource_media_assets

對庫內每篇已解析筆記重新抓取頁面，取出 imageList 全部圖片，
下載後轉存 Storage（xhs/{note_id}/img_{i}.jpg），
並寫入 resource_media_assets 供 app 讀取輪播圖。
"""

import json
import subprocess
import sys
import time
import urllib.request
import uuid
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

import xhs_fetch_classify as core
import thumbnails_to_storage as thumbs

BUCKET = thumbs.BUCKET  # resource-thumbnails


def storage_upload(path, data):
    return thumbs.upload(path, data)


def main():
    _, rows = core.sb_request(
        "GET",
        "/rest/v1/resource_items?source_type=eq.xiaohongshu&import_status=eq.parsed"
        "&select=id,external_id,content_type&order=created_at",
    )
    token_urls = core.load_token_urls()
    print(f"筆記 {len(rows)} 篇，token 連結 {len(token_urls)} 條")

    # 先查已補過的，重跑冪等
    _, existing = core.sb_request(
        "GET",
        "/rest/v1/resource_media_assets?select=resource_id&asset_type=eq.image",
    )
    done_ids = {e["resource_id"] for e in (existing or [])}
    print(f"已有圖組的筆記: {len(done_ids)} 篇")

    core.init_guest_cookies()

    ok_notes = fail_notes = skip_notes = 0
    total_images = 0
    now = datetime.now(timezone.utc).isoformat()

    for i, row in enumerate(rows):
        if row["id"] in done_ids:
            skip_notes += 1
            continue
        url = token_urls.get(row["external_id"])
        if not url:
            print(f"  [{i + 1}] 無 token 連結: {row['external_id']}")
            fail_notes += 1
            continue

        note = core.fetch_note(url)
        if note is None:
            time.sleep(2)
            note = core.fetch_note(url)
        if note is None:
            print(f"  [{i + 1}] 抓取失敗（token 可能過期）: {row['external_id']}")
            fail_notes += 1
            time.sleep(1.5)
            continue

        image_list = note.get("imageList", [])
        image_urls = [img.get("urlDefault", "") for img in image_list if img.get("urlDefault")]
        if not image_urls:
            print(f"  [{i + 1}] 無圖片（影片筆記）: {row['external_id']}")
            skip_notes += 1
            time.sleep(1.5)
            continue

        assets = []
        for idx, img_url in enumerate(image_urls):
            data = thumbs.download(img_url)
            if data is None:
                continue
            path = f"xhs/{row['external_id']}/img_{idx}.jpg"
            if not storage_upload(path, data):
                continue
            public_url = f"{core.SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{path}"
            assets.append({
                "id": str(uuid.uuid4()),
                "resource_id": row["id"],
                "asset_id": f"xhs-image-{idx}",
                "asset_type": "image",
                "remote_url": public_url,
                "preview_url": public_url,
                "display_index": idx,
                "retention_policy": "explicitKeep",
                "storage_path": path,
                "created_at": now,
            })

        if assets:
            status, body = core.sb_request(
                "POST", "/rest/v1/resource_media_assets",
                body=assets, extra_headers={"Prefer": "return=minimal"},
            )
            if status in (200, 201):
                ok_notes += 1
                total_images += len(assets)
                print(f"  [{i + 1}] OK {row['external_id']}: {len(assets)} 張")
            else:
                fail_notes += 1
                print(f"  [{i + 1}] 入庫失敗 {status}: {body}")
        else:
            fail_notes += 1
            print(f"  [{i + 1}] 圖片全部下載失敗: {row['external_id']}")

        time.sleep(1.5)

    print(f"\n完成：補圖 {ok_notes} 篇共 {total_images} 張，略過 {skip_notes}（已補/無圖），失敗 {fail_notes}")


if __name__ == "__main__":
    main()
