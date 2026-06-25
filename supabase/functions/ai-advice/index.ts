import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { requestFreeformSuggestions } from "../_shared/aiProvider.ts";
import { resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { AIAdviceRequest, AIAdviceResponse, AIAdviceTopic } from "../_shared/types.ts";

const VALID_TOPICS: AIAdviceTopic[] = ["skincare", "hair", "facialLift", "bodySkin", "diet", "makeup", "exercise", "wellness", "finance"];

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
        { error: "No AI provider configured. Set one up in 設定 > AI 提供者設定 first." },
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
