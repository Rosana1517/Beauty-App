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
 * 依使用者輸入的關鍵字搜尋庫內小紅書筆記（標題/描述 ilike），
 * 關鍵字沒中時退回主題分類熱門，回傳可直接附加到建議清單的字串。
 */
async function searchRelatedNotes(topic: AIAdviceTopic, concerns: string[]): Promise<AIAdviceRelatedResource[]> {
  const categories = TOPIC_CATEGORY[topic];
  if (!categories) return [];

  try {
    const supabase = createAdminClient();
    const found = new Map<string, AIAdviceRelatedResource>();
    const columns = "id, title, author_name, category, thumbnail_url";

    const keywords = concerns
      .flatMap((c) => c.split(/[、，,\s：:（）()]+/))
      .map((k) => k.trim())
      .filter((k) => k.length >= 2 && k.length <= 12)
      .slice(0, 6);

    for (const keyword of keywords) {
      if (found.size >= 3) break;
      const { data } = await supabase
        .from("resource_items")
        .select(columns)
        .eq("source_type", "xiaohongshu")
        .eq("import_status", "parsed")
        .or(`title.ilike.%${keyword}%,description_text.ilike.%${keyword}%`)
        .limit(2);
      for (const row of data ?? []) {
        if (!found.has(row.id)) {
          found.set(row.id, {
            id: row.id,
            title: row.title,
            category: row.category ?? "other",
            author: row.author_name ?? "",
            thumbnail_url: row.thumbnail_url ?? "",
          });
        }
      }
    }

    if (found.size === 0) {
      const { data } = await supabase
        .from("resource_items")
        .select(columns)
        .eq("source_type", "xiaohongshu")
        .eq("import_status", "parsed")
        .in("category", categories)
        .limit(2);
      for (const row of data ?? []) {
        found.set(row.id, {
          id: row.id,
          title: row.title,
          category: row.category ?? "other",
          author: row.author_name ?? "",
          thumbnail_url: row.thumbnail_url ?? "",
        });
      }
    }

    return [...found.values()].slice(0, 3);
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
