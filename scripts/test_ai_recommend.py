"""
AI 建議推薦流程端到端測試

模擬 app 內流程：
    使用者輸入需求 → LLM 解析成分類+關鍵字 → Supabase 檢索 → LLM 挑選並給推薦理由

量測每步耗時，驗證資料庫內容能支撐真實推薦。
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


def llm(prompt, timeout=60):
    body = {"model": LLM_MODEL, "messages": [{"role": "user", "content": prompt}], "temperature": 0}
    req = urllib.request.Request(LLM_URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {LLM_KEY}")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())["choices"][0]["message"]["content"]


def sb_get(path):
    req = urllib.request.Request(f"{SUPABASE_URL}{path}")
    req.add_header("apikey", SERVICE_ROLE_KEY)
    req.add_header("Authorization", f"Bearer {SERVICE_ROLE_KEY}")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def parse_intent(user_query):
    """步驟1：LLM 解析使用者需求成 分類 + 關鍵字"""
    prompt = (
        f"使用者需求：「{user_query}」\n"
        "解析成檢索條件。分類限用：skincare/fitness/food/outfit/learning/other。\n"
        "關鍵字給 2-4 個簡體中文詞（資料庫內容是簡體）。\n"
        '只輸出 JSON：{"category":"...","keywords":["..."]}'
    )
    text = llm(prompt)
    m = re.search(r"\{.*\}", text, re.DOTALL)
    return json.loads(m.group(0))


def search_db(intent):
    """步驟2：Supabase 關鍵字檢索（title/description/tags）"""
    ors = []
    for kw in intent["keywords"]:
        ors.append(f"title.ilike.*{kw}*")
        ors.append(f"description_text.ilike.*{kw}*")
    or_clause = ",".join(ors)
    path = (
        f"/rest/v1/resource_items?source_type=eq.xiaohongshu"
        f"&or=({or_clause})"
        f"&select=id,title,description_text,author_name,thumbnail_url,tags,category,raw_metadata_snapshot"
        f"&limit=15"
    )
    results = sb_get(urllib.parse.quote(path, safe="/?&=().,*:"))
    if len(results) < 3:  # 關鍵字太窄時退回分類
        results += sb_get(
            f"/rest/v1/resource_items?source_type=eq.xiaohongshu"
            f"&category=eq.{intent['category']}"
            f"&select=id,title,description_text,author_name,thumbnail_url,tags,category,raw_metadata_snapshot"
            f"&limit=10"
        )
        seen, dedup = set(), []
        for r in results:
            if r["id"] not in seen:
                seen.add(r["id"])
                dedup.append(r)
        results = dedup
    return results


def rank_and_reason(user_query, candidates):
    """步驟3：LLM 從候選中挑 3 篇並給推薦理由"""
    listing = "\n".join(
        f"{i + 1}. {c['title']}｜{(c['description_text'] or '')[:60]}｜讚:{(c['raw_metadata_snapshot'] or {}).get('likedCount', '?')}"
        for i, c in enumerate(candidates)
    )
    prompt = (
        f"使用者需求：「{user_query}」\n候選筆記：\n{listing}\n\n"
        "挑最相關的 3 篇，各給一句繁體中文推薦理由。\n"
        '只輸出 JSON：[{"n":1,"reason":"..."},...]'
    )
    text = llm(prompt)
    m = re.search(r"\[.*\]", text, re.DOTALL)
    return json.loads(m.group(0))


def run_case(user_query):
    print(f"\n{'=' * 60}")
    print(f"使用者需求：「{user_query}」")

    t0 = time.time()
    intent = parse_intent(user_query)
    t1 = time.time()
    print(f"  [1] 意圖解析 {t1 - t0:.1f}s → 分類={intent['category']} 關鍵字={intent['keywords']}")

    candidates = search_db(intent)
    t2 = time.time()
    print(f"  [2] 資料庫檢索 {t2 - t1:.1f}s → 命中 {len(candidates)} 篇")

    if not candidates:
        print("  ✗ 無結果")
        return

    picks = rank_and_reason(user_query, candidates)
    t3 = time.time()
    print(f"  [3] LLM 排序+理由 {t3 - t2:.1f}s")
    print(f"  總耗時 {t3 - t0:.1f}s\n")

    for p in picks:
        c = candidates[int(p["n"]) - 1]
        snap = c.get("raw_metadata_snapshot") or {}
        print(f"  ★ {c['title']}")
        print(f"    作者:{c['author_name']}｜讚:{snap.get('likedCount', '?')}｜分類:{c['category']}")
        print(f"    理由:{p['reason']}")
        print(f"    縮圖:{c['thumbnail_url'][:80]}")
        print()


if __name__ == "__main__":
    import urllib.parse
    for query in [
        "我想瘦大腿，最好是能躺著做的懶人運動",
        "皮膚暗沉想變白，有什麼便宜的方法",
        "臉頰凹陷、太陽穴凹陷怎麼改善",
    ]:
        run_case(query)
