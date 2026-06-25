import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { requestFreeformSuggestions } from "../_shared/aiProvider.ts";
import { resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { AIAdviceRequest, AIAdviceResponse, AIAdviceTopic } from "../_shared/types.ts";

const VALID_TOPICS: AIAdviceTopic[] = ["skincare", "hair", "facialLift", "bodySkin", "diet", "makeup", "exercise", "wellness", "finance", "nourishment"];

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

    const suggestions = await requestFreeformSuggestions(topic, concerns, userID);
    if (!suggestions) {
      return jsonResponse(
        { error: "尚未設定 AI 提供者，請先到「個人設定」的「AI 解析設定」填入 OpenAI 或 Anthropic 的 API Key。" },
        422,
      );
    }

    const response: AIAdviceResponse = { suggestions };
    return jsonResponse(response);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected AI advice error." },
      500,
    );
  }
});
