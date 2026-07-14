import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { requestFreeformSuggestions } from "../_shared/aiProvider.ts";
import { createAdminClient, resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { AIAdviceRelatedResource, AIAdviceRequest, AIAdviceResponse, AIAdviceTopic } from "../_shared/types.ts";

const VALID_TOPICS: AIAdviceTopic[] = ["skincare", "hair", "facialLift", "bodySkin", "diet", "makeup", "exercise", "wellness", "finance", "nourishment"];

// 各主題對應的小紅書筆記庫分類，讓建議能附上庫內真實實測內容
const TOPIC_CATEGORY: Partial<Record<AIAdviceTopic, string[]>> = {
  skincare: ["skincare"],
  facialLift: ["skincare"],
  bodySkin: ["skincare"],
  diet: ["food"],
  exercise: ["fitness"],
  wellness: ["other", "food"],
  nourishment: ["other", "food"],
};

/**
 * 通用詞黑名單：這些詞出現在幾乎所有需求描述裡，拿去 ilike 會把
 * 不相關的筆記也撈進來（使用者回報的「錯誤引用」主因之一）。
 */
const KEYWORD_STOPWORDS = new Set([
  "推薦", "建議", "方法", "改善", "如何", "怎麼", "怎么", "什麼", "什么",
  "想要", "我想", "希望", "可以", "最好", "有效", "真的", "適合", "适合",
  "需求", "內容", "内容", "記錄", "记录", "打卡", "次數", "次数", "目標", "目标",
  "問題", "问题", "困擾", "困扰", "一個", "一个", "每天", "分鐘", "分钟",
  "大卡", "熱量", "热量", "公斤", "kg", "我的", "近期", "症狀", "症状",
]);

/**
 * 依使用者輸入搜尋庫內小紅書筆記。只回傳「確實命中具體關鍵字」的
 * 筆記並按命中程度排序（標題命中權重高於內文）；完全沒命中時回傳
 * 空陣列，寧可不附也不亂附——先前沒命中會隨機退回分類熱門，
 * 導致與需求無關的筆記被當成「相關教學」引用。
 */
async function searchRelatedNotes(topic: AIAdviceTopic, concerns: string[]): Promise<AIAdviceRelatedResource[]> {
  const categories = TOPIC_CATEGORY[topic];
  if (!categories) return [];

  const keywords = [...new Set(
    concerns
      .flatMap((c) => c.split(/[、，,。．\s：:（）()「」!？?！0-9]+/))
      .map((k) => k.trim())
      .filter((k) => k.length >= 2 && k.length <= 10 && !KEYWORD_STOPWORDS.has(k)),
  )].slice(0, 8);
  if (keywords.length === 0) return [];

  try {
    const supabase = createAdminClient();
    // 只在主題對應分類內搜尋，避免例如護膚需求配到健身筆記
    const { data } = await supabase
      .from("resource_items")
      .select("id, title, author_name, category, thumbnail_url, description_text")
      .eq("source_type", "xiaohongshu")
      .eq("import_status", "parsed")
      .in("category", categories)
      .limit(200);

    const scored = (data ?? [])
      .map((row) => {
        let score = 0;
        const matchedKeywords: string[] = [];
        for (const keyword of keywords) {
          const inTitle = row.title?.includes(keyword);
          const inDesc = row.description_text?.includes(keyword);
          if (inTitle) score += 3;
          else if (inDesc) score += 1;
          if (inTitle || inDesc) matchedKeywords.push(keyword);
        }
        return { row, score, matchedCount: matchedKeywords.length };
      })
      // 至少要有標題命中（score>=3）或內文命中兩個不同關鍵字，
      // 單一內文弱命中視為巧合不引用
      .filter((entry) => entry.score >= 3 || entry.matchedCount >= 2)
      .sort((a, b) => b.score - a.score);

    return scored.slice(0, 3).map(({ row }) => ({
      id: row.id,
      title: row.title,
      category: row.category ?? "other",
      author: row.author_name ?? "",
      thumbnail_url: row.thumbnail_url ?? "",
    }));
  } catch (error) {
    console.error("Related note search failed; returning advice without notes.", error);
    return [];
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as AIAdviceRequest;
    const concerns = Array.isArray(payload?.concerns)
      ? payload.concerns.filter((item) => typeof item === "string" && item.trim()).map((item) => item.trim())
      : [];
    const topic: AIAdviceTopic = VALID_TOPICS.includes(payload?.topic) ? payload.topic : "skincare";

    const result = await requestFreeformSuggestions(topic, concerns, userID);
    if (!result) {
      return jsonResponse(
        { error: "尚未設定 AI 提供者，請先到「個人設定」的「AI 解析設定」填入 OpenAI 或 Anthropic 的 API Key。" },
        422,
      );
    }

    const relatedNotes = await searchRelatedNotes(topic, concerns);
    const response: AIAdviceResponse = {
      suggestions: result.suggestions,
      routineSteps: result.routineSteps.length > 0 ? result.routineSteps : undefined,
      products: result.products.length > 0 ? result.products : undefined,
      relatedResources: relatedNotes.length > 0 ? relatedNotes : undefined,
    };
    return jsonResponse(response);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected AI advice error." },
      500,
    );
  }
});
