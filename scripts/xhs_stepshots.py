"""
影片教學步驟配圖：對已有「📋 教學步驟」文字的影片筆記，
補上每個步驟對應的畫面截圖（display_index 對齊步驟編號，
asset_id 命名為 step-N，供 app 端 TeachingStepParser 配對顯示）。

流程：下載影片 -> faster-whisper 帶時間戳重新轉錄 -> LLM 把既有步驟文字
對應到逐字稿時間點 -> ffmpeg 在該時間點擷取畫面 -> 上傳 Storage -> 寫入
resource_media_assets。

僅需跑一次；已補過的筆記（已有 step- 開頭 asset）會自動略過，可重複執行。
"""

import json
import os
import re
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

import xhs_fetch_classify as core
import thumbnails_to_storage as thumbs
from xhs_transcribe_videos import extract_video_url, download_video, extract_audio, cleanup, WORK_DIR

STEP_MARKER = "📋 教學步驟"


def parse_steps(description):
    if STEP_MARKER not in description:
        return []
    after = description.split(STEP_MARKER, 1)[1]
    steps = []
    for line in after.split("\n"):
        m = re.match(r"\s*(\d+)[\.\、]\s*(.+)", line.strip())
        if m:
            steps.append((int(m.group(1)), m.group(2).strip()))
    return steps


_model = None

def transcribe_with_segments(wav):
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        _model = WhisperModel("small", device="cpu", compute_type="int8")
    segments, _info = _model.transcribe(wav, language="zh", vad_filter=True, word_timestamps=False)
    return [{"start": round(s.start, 1), "end": round(s.end, 1), "text": s.text.strip()} for s in segments]


def match_steps_to_timestamps(steps, segments):
    seg_lines = "\n".join(f"[{s['start']}s-{s['end']}s] {s['text']}" for s in segments)
    step_lines = "\n".join(f"{i}. {t}" for i, t in steps)
    prompt = (
        "以下是逐字稿片段（含時間戳，秒為單位）與已整理好的教學步驟。\n"
        "請為每個步驟找出逐字稿中最相關片段的「開始時間」（秒，數字），"
        "作為該步驟畫面截圖的時間點。\n"
        f"逐字稿片段：\n{seg_lines}\n\n步驟：\n{step_lines}\n\n"
        '只輸出 JSON：[{"step":1,"start":12.3},...]，每個步驟都要有對應項。'
    )
    body = {"model": core.LLM_MODEL, "messages": [{"role": "user", "content": prompt}], "temperature": 0}
    import urllib.request
    req = urllib.request.Request(core.LLM_URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {core.LLM_KEY}")
    with urllib.request.urlopen(req, timeout=90) as resp:
        text = json.loads(resp.read())["choices"][0]["message"]["content"]
    m = re.search(r"\[.*\]", text, re.DOTALL)
    mapping = json.loads(m.group(0))
    return {int(item["step"]): float(item["start"]) for item in mapping if "step" in item and "start" in item}


def grab_frame(mp4, note_id, step_index, timestamp):
    jpg = os.path.join(WORK_DIR, f"{note_id}_step{step_index}.jpg")
    result = subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", str(timestamp), "-i", mp4,
         "-frames:v", "1", "-q:v", "3", jpg],
        check=False,
    )
    if result.returncode != 0 or not os.path.exists(jpg) or os.path.getsize(jpg) < 1000:
        return None
    return jpg


def main():
    _, rows = core.sb_request(
        "GET",
        "/rest/v1/resource_items?source_type=eq.xiaohongshu&content_type=eq.video"
        "&select=id,external_id,title,description_text&order=created_at",
    )
    targets = [r for r in rows if STEP_MARKER in (r["description_text"] or "")]
    print(f"已有教學步驟的影片: {len(targets)} 篇")

    _, existing = core.sb_request(
        "GET", "/rest/v1/resource_media_assets?asset_id=like.step-*&select=resource_id",
    )
    done_ids = {e["resource_id"] for e in (existing or [])}
    print(f"已補過配圖: {len(done_ids)} 篇")

    token_urls = core.load_token_urls()
    core.init_guest_cookies()

    ok = fail = 0
    for i, row in enumerate(targets):
        if row["id"] in done_ids:
            continue
        nid = row["external_id"]
        print(f"[{i + 1}/{len(targets)}] {row['title'][:28]}")

        steps = parse_steps(row["description_text"])
        if not steps:
            print("    無法解析步驟文字"); fail += 1; continue

        url = token_urls.get(nid)
        if not url:
            print("    無 token 連結"); fail += 1; continue

        note = core.fetch_note(url)
        if note is None:
            print("    筆記抓取失敗"); fail += 1; continue

        video_url = extract_video_url(note)
        if not video_url:
            print("    找不到影片串流"); fail += 1; continue

        mp4 = download_video(video_url, nid)
        if mp4 is None:
            print("    影片下載失敗"); fail += 1; continue

        wav = extract_audio(mp4, nid)
        if wav is None:
            print("    音軌抽取失敗"); cleanup(nid); fail += 1; continue

        t0 = time.time()
        segments = transcribe_with_segments(wav)
        print(f"    分段轉錄 {len(segments)} 段 ({time.time() - t0:.0f}s)")

        try:
            timestamps = match_steps_to_timestamps(steps, segments)
        except Exception as exc:
            print(f"    時間點對應失敗: {exc}")
            cleanup(nid)
            fail += 1
            continue

        now = datetime.now(timezone.utc).isoformat()
        uploaded = 0
        for step_index, _text in steps:
            ts = timestamps.get(step_index)
            if ts is None:
                continue
            jpg_path = grab_frame(mp4, nid, step_index, ts)
            if jpg_path is None:
                continue
            with open(jpg_path, "rb") as f:
                data = f.read()
            os.remove(jpg_path)
            storage_path = f"xhs/{nid}/step_{step_index}.jpg"
            if not thumbs.upload(storage_path, data):
                continue
            public_url = f"{core.SUPABASE_URL}/storage/v1/object/public/{thumbs.BUCKET}/{storage_path}"
            core.sb_request(
                "POST", "/rest/v1/resource_media_assets",
                body={
                    "id": str(uuid.uuid4()),
                    "resource_id": row["id"],
                    "asset_id": f"step-{step_index}",
                    "asset_type": "image",
                    "remote_url": public_url,
                    "preview_url": public_url,
                    "display_index": step_index,
                    "retention_policy": "explicitKeep",
                    "storage_path": storage_path,
                    "created_at": now,
                },
                extra_headers={"Prefer": "return=minimal"},
            )
            uploaded += 1

        cleanup(nid)
        if uploaded > 0:
            ok += 1
            print(f"    ✔ {uploaded}/{len(steps)} 步驟配圖完成")
        else:
            fail += 1
            print("    無成功配圖")
        time.sleep(1)

    print(f"\n完成：成功 {ok} 篇，失敗/略過 {fail} 篇")


if __name__ == "__main__":
    main()
