"""
影片筆記內容解析：下載影片 -> 轉錄語音 -> LLM 整理教學步驟 -> 回填資料庫

針對描述過短（無具體步驟）的影片筆記：
    1. 重抓筆記頁面取得影片串流網址
    2. curl 下載影片、ffmpeg 抽 16kHz 單聲道音軌
    3. faster-whisper (small, CPU) 中文轉錄
    4. agnes LLM 把口語轉錄整理成條列教學步驟
    5. 步驟附加到 resource_items.description_text（app 詳情頁直接可見），
       完整轉錄存入 resource_analysis_results
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import uuid
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

import xhs_fetch_classify as core

WORK_DIR = os.path.join(os.environ.get("TEMP", "."), "xhs_video_work")
os.makedirs(WORK_DIR, exist_ok=True)

STEP_MARKER = "📋 教學步驟"


def extract_video_url(note):
    stream = ((note.get("video") or {}).get("media") or {}).get("stream") or {}
    for codec in ("h264", "h265", "av1"):
        entries = stream.get(codec) or []
        if entries:
            url = entries[0].get("masterUrl") or ""
            if url:
                return url
            for backup in entries[0].get("backupUrls") or []:
                if backup:
                    return backup
    return ""


def download_video(url, note_id):
    mp4 = os.path.join(WORK_DIR, f"{note_id}.mp4")
    result = subprocess.run(
        ["curl", "-s", "-L", "--max-time", "120",
         "-H", "Referer: https://www.xiaohongshu.com/",
         "-A", core.UA, "-o", mp4, url],
        check=False,
    )
    if result.returncode != 0 or not os.path.exists(mp4) or os.path.getsize(mp4) < 50_000:
        return None
    return mp4


def extract_audio(mp4, note_id):
    wav = os.path.join(WORK_DIR, f"{note_id}.wav")
    result = subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", mp4,
         "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1", wav],
        check=False,
    )
    if result.returncode != 0 or not os.path.exists(wav):
        return None
    return wav


_model = None

def transcribe(wav):
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        _model = WhisperModel("small", device="cpu", compute_type="int8")
    segments, _info = _model.transcribe(wav, language="zh", vad_filter=True)
    text = "".join(seg.text for seg in segments).strip()
    return text


def llm_extract_steps(title, transcript):
    prompt = (
        f"以下是一則小紅書教學影片的語音轉錄（標題：{title}）。\n"
        "請整理成條列教學步驟，每步一句話、25字內，最多6步；"
        "若含次數/秒數/組數等關鍵數字務必保留。\n"
        '只輸出 JSON：{"steps":["..."]}\n\n'
        f"轉錄內容：{transcript[:2500]}"
    )
    body = {"model": core.LLM_MODEL, "messages": [{"role": "user", "content": prompt}], "temperature": 0}
    req = urllib.request.Request(core.LLM_URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {core.LLM_KEY}")
    for attempt in range(2):
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                text = json.loads(resp.read())["choices"][0]["message"]["content"]
            m = re.search(r"\{.*\}", text, re.DOTALL)
            steps = json.loads(m.group(0)).get("steps", [])
            return [s.strip() for s in steps if isinstance(s, str) and s.strip()][:6]
        except Exception as exc:
            if attempt == 1:
                print(f"    LLM 整理失敗: {exc}")
    return []


def writeback(row, steps, transcript):
    now = datetime.now(timezone.utc).isoformat()
    step_text = "\n".join(f"{i + 1}. {s}" for i, s in enumerate(steps))
    desc = (row["description_text"] or "").strip()
    new_desc = (desc + "\n\n" if desc else "") + f"{STEP_MARKER}：\n{step_text}"

    core.sb_request(
        "PATCH", f"/rest/v1/resource_items?id=eq.{row['id']}",
        body={"description_text": new_desc, "updated_at": now},
        extra_headers={"Prefer": "return=minimal"},
    )
    core.sb_request(
        "POST", "/rest/v1/resource_analysis_results",
        body={
            "id": str(uuid.uuid4()),
            "resource_id": row["id"],
            "provider": "whisper-small+llm",
            "status": "analyzed",
            "summary": step_text,
            "insights": [transcript[:4000]],
            "confidence": 0.8,
        },
        extra_headers={"Prefer": "return=minimal"},
    )


def cleanup(note_id):
    for ext in (".mp4", ".wav"):
        path = os.path.join(WORK_DIR, f"{note_id}{ext}")
        if os.path.exists(path):
            os.remove(path)


def main():
    _, rows = core.sb_request(
        "GET",
        "/rest/v1/resource_items?source_type=eq.xiaohongshu&content_type=eq.video"
        "&select=id,external_id,title,description_text&order=created_at",
    )
    targets = [r for r in rows if STEP_MARKER not in (r["description_text"] or "")
               and len((r["description_text"] or "")) < 50]
    token_urls = core.load_token_urls()
    print(f"待解析影片: {len(targets)} 篇")

    core.init_guest_cookies()
    ok = fail = 0

    for i, row in enumerate(targets):
        nid = row["external_id"]
        print(f"[{i + 1}/{len(targets)}] {row['title'][:28]}")
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
            print("    音軌抽取失敗"); fail += 1; cleanup(nid); continue

        t0 = time.time()
        transcript = transcribe(wav)
        print(f"    轉錄 {len(transcript)} 字 ({time.time() - t0:.0f}s)")
        cleanup(nid)

        if len(transcript) < 30:
            print("    轉錄過短（可能純音樂無講解），略過")
            fail += 1
            continue

        steps = llm_extract_steps(row["title"], transcript)
        if not steps:
            print("    無法整理出步驟"); fail += 1; continue

        writeback(row, steps, transcript)
        ok += 1
        print(f"    ✔ {len(steps)} 步驟入庫")
        time.sleep(1)

    print(f"\n完成：成功 {ok}，失敗/略過 {fail}")


if __name__ == "__main__":
    main()
