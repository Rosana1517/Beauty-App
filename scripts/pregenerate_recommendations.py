"""
預先生成 AI 推薦 -> resource_recommendations 表

離線為每個常見需求情境生成推薦組合，app 端純查表零等待。

表結構沿用現有 schema（未加欄位）：
    title    = 情境名稱（推薦卡標題，app 依此查詢）
    detail   = 筆記標題＋作者＋讚數（顯示用摘要）
    category = 筆記分類
    reason   = LLM 推薦理由
    resource_id -> resource_items（app join 取縮圖與完整內容）

用法：
    python -X utf8 pregenerate_recommendations.py            # 生成全部情境
    python -X utf8 pregenerate_recommendations.py --verify   # 只驗證查詢速度
"""

import json
import os
import re
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")

SUPABASE_URL = "https://iajbkfbpoaswitawdlpm.supabase.co"
SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if not SERVICE_ROLE_KEY:
    sys.exit("SUPABASE_SERVICE_ROLE_KEY environment variable is not set.")
LLM_URL = "https://apihub.agnes-ai.com/v1/chat/completions"
LLM_MODEL = "agnes-2.0-flash"
LLM_KEY = "sk-6gq8qp8kTMsijhHZGUTuWtVJw0sVVZMXWYbQsmYfTL7pRU14"

# 情境清單：涵蓋 75 篇內容的主要需求面向，app 端的 AI 建議入口對應這些情境
SCENARIOS = [
    ("瘦腿塑形", "想瘦大腿、小腿，改善腿型（假胯宽、脂包肌、小腿外翻）"),
    ("懶人居家運動", "不想去健身房，想躺著或在家就能做的簡單運動"),
    ("體態矯正", "骨盆前傾、駝背、脊椎、大轉子歸位等體態問題"),
    ("翹臀美胸", "臀部下垂凹陷、副乳、想練翹臀豐胸"),
    ("瘦身飲食", "減脂餐、減肥茶、輕斷食、低卡飲食相關"),
    ("美白提亮", "皮膚暗沉發黃、想全身美白、淡化唇周暗沉"),
    ("臉部緊緻抗老", "面部凹陷、太陽穴凹陷、垮臉、提拉緊緻"),
    ("臉部輪廓改善", "咬肌、大小臉、高顱頂、五官立體、眼睛變大"),
    ("養生調理", "補氣血、經期調理、養生茶、痘痘肌調理"),
]

TOP_N = 4  # 每情境推薦篇數


def llm(prompt, timeout=120):
    body = {"model": LLM_MODEL, "messages": [{"role": "user", "content": prompt}], "temperature": 0}
    req = urllib.request.Request(LLM_URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {LLM_KEY}")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())["choices"][0]["message"]["content"]


def sb(method, path, body=None, extra=None):
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
    )
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
        **(extra or {}),
    }
    for k, v in headers.items():
        req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
        return resp.status, json.loads(raw) if raw else None


def pick_for_scenario(scenario_name, scenario_desc, notes):
    listing = "\n".join(
        f"{i + 1}. {n['title']}｜標籤:{','.join((n['tags'] or [])[:4])}｜讚:{(n['raw_metadata_snapshot'] or {}).get('likedCount', '?')}"
        for i, n in enumerate(notes)
    )
    prompt = (
        f"情境：「{scenario_name}」— {scenario_desc}\n\n"
        f"以下是筆記庫：\n{listing}\n\n"
        f"挑選最符合此情境的 {TOP_N} 篇（相關性優先，讚數高者加分），"
        "各給一句繁體中文推薦理由（說明為何適合此需求，25字內）。\n"
        '只輸出 JSON：[{"n":1,"reason":"..."},...]'
    )
    text = llm(prompt)
    m = re.search(r"\[.*\]", text, re.DOTALL)
    return json.loads(m.group(0))


def generate():
    _, notes = sb(
        "GET",
        "/rest/v1/resource_items?source_type=eq.xiaohongshu&import_status=eq.parsed"
        "&select=id,title,author_name,tags,category,raw_metadata_snapshot&order=created_at",
    )
    print(f"筆記庫：{len(notes)} 篇，情境：{len(SCENARIOS)} 個\n")

    # 先清掉舊的預生成結果（重跑冪等）
    scenario_names = [s[0] for s in SCENARIOS]
    in_list = ",".join(f'"{n}"' for n in scenario_names)
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/resource_recommendations?title=in.({urllib.parse.quote(in_list)})",
        method="DELETE",
    )
    req.add_header("apikey", SERVICE_ROLE_KEY)
    req.add_header("Authorization", f"Bearer {SERVICE_ROLE_KEY}")
    req.add_header("Prefer", "return=minimal")
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(f"清除舊預生成結果: {resp.status}")

    total = 0
    for name, desc in SCENARIOS:
        t0 = time.time()
        try:
            picks = pick_for_scenario(name, desc, notes)
        except Exception as exc:
            print(f"[{name}] LLM 失敗: {exc}")
            continue

        rows = []
        for p in picks[:TOP_N]:
            idx = int(p["n"]) - 1
            if not (0 <= idx < len(notes)):
                continue
            note = notes[idx]
            snap = note.get("raw_metadata_snapshot") or {}
            rows.append({
                "resource_id": note["id"],
                "title": name,
                "detail": f"{note['title']}｜{note['author_name']}｜讚 {snap.get('likedCount', '?')}",
                "category": note["category"],
                "reason": p.get("reason", ""),
            })

        if rows:
            status, _ = sb("POST", "/rest/v1/resource_recommendations", rows, {"Prefer": "return=minimal"})
            total += len(rows)
            print(f"[{name}] {len(rows)} 篇入庫 ({time.time() - t0:.1f}s)")
            for r in rows:
                print(f"    ・{r['detail'][:45]}")
                print(f"      {r['reason']}")

    print(f"\n完成：共寫入 {total} 筆預生成推薦")


def verify():
    print("驗證 app 端查表速度：\n")
    for name, _ in SCENARIOS:
        t0 = time.time()
        _, rows = sb(
            "GET",
            f"/rest/v1/resource_recommendations?title=eq.{urllib.parse.quote(name)}"
            f"&select=detail,reason,category,resource_id",
        )
        print(f"  {name}: {len(rows)} 筆, {time.time() - t0:.2f}s")


if __name__ == "__main__":
    import urllib.parse
    if "--verify" in sys.argv:
        verify()
    else:
        generate()
