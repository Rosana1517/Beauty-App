import type { AIAdviceTopic, AIAnalysisResult, ResourceCategory, ResourceImportDraft } from "./types.ts";
import { createAdminClient } from "./runtime.ts";

interface AIProviderConfig {
  provider: "openai" | "anthropic";
  apiKey: string;
  model: string;
  baseURL: string;
}

const VALID_CATEGORIES: ResourceCategory[] = ["skincare", "fitness", "food", "outfit", "learning", "other"];

/**
 * Each signed-in user can bring their own AI provider/key (stored, RLS-scoped
 * to that user, in `user_ai_provider_settings`) so this isn't a single
 * shared key for every installation. Falls back to the global
 * AI_PROVIDER/AI_API_KEY env vars (e.g. for the developer's own testing)
 * when the user hasn't configured one of their own.
 */
async function resolveAIProviderConfig(userID: string): Promise<AIProviderConfig | null> {
  const userConfig = await fetchUserAIProviderConfig(userID);
  return userConfig ?? getEnvAIProviderConfig();
}

async function fetchUserAIProviderConfig(userID: string): Promise<AIProviderConfig | null> {
  try {
    const supabase = createAdminClient();
    const { data, error } = await supabase
      .from("user_ai_provider_settings")
      .select("provider, api_key, base_url, model")
      .eq("user_id", userID)
      .maybeSingle();

    if (error || !data) return null;

    const provider = String(data.provider ?? "").trim().toLowerCase();
    const apiKey = String(data.api_key ?? "").trim();
    if (!apiKey || (provider !== "openai" && provider !== "anthropic")) {
      return null;
    }

    const model = String(data.model ?? "").trim() || defaultModelFor(provider);
    const baseURL = String(data.base_url ?? "").trim().replace(/\/+$/, "") || defaultBaseURLFor(provider);
    return { provider, apiKey, model, baseURL };
  } catch (error) {
    console.error("Failed to load user AI provider settings, falling back.", error);
    return null;
  }
}

function getEnvAIProviderConfig(): AIProviderConfig | null {
  const provider = (Deno.env.get("AI_PROVIDER") ?? "").trim().toLowerCase();
  const apiKey = (Deno.env.get("AI_API_KEY") ?? "").trim();
  if (!apiKey || (provider !== "openai" && provider !== "anthropic")) {
    return null;
  }
  const model = (Deno.env.get("AI_MODEL") ?? "").trim() || defaultModelFor(provider);
  const baseURL = (Deno.env.get("AI_BASE_URL") ?? "").trim().replace(/\/+$/, "") || defaultBaseURLFor(provider);
  return { provider, apiKey, model, baseURL };
}

function defaultModelFor(provider: "openai" | "anthropic"): string {
  return provider === "openai" ? "gpt-4o-mini" : "claude-haiku-4-5-20251001";
}

/**
 * `AI_BASE_URL` lets this point at Azure OpenAI, an OpenAI-compatible
 * gateway (e.g. a self-hosted proxy or another vendor's compatible API),
 * or a private Anthropic-compatible endpoint, without changing code.
 */
function defaultBaseURLFor(provider: "openai" | "anthropic"): string {
  return provider === "openai" ? "https://api.openai.com/v1" : "https://api.anthropic.com/v1";
}

/**
 * Calls the configured external AI provider to analyze a resource draft.
 * Returns null when no provider is configured or the call fails, so the
 * caller can fall back to the local rule engine without breaking the flow.
 */
export async function analyzeWithAI(draft: ResourceImportDraft, userID: string): Promise<AIAnalysisResult | null> {
  const config = await resolveAIProviderConfig(userID);
  if (!config) return null;

  try {
    const prompt = buildPrompt(draft);
    const rawText = config.provider === "openai"
      ? await callOpenAI(config, prompt)
      : await callAnthropic(config, prompt);
    return parseAIResponse(rawText, config);
  } catch (error) {
    console.error("AI provider call failed, falling back to rule engine.", error);
    return null;
  }
}

/**
 * Calls the configured external AI provider for a free-text request that
 * isn't tied to a resource draft (e.g. "give me facial improvement
 * suggestions for these concerns"). Returns null when no provider is
 * configured or the call fails, so the caller can show a clear "please
 * set up an AI provider" message instead of fabricating fake suggestions.
 *
 * Shared by every "type your concern -> get AI suggestions" screen in the
 * app (skincare/hair/face-lift/body-skin/diet/makeup) so each one doesn't
 * need its own Edge Function - only the persona/framing in the prompt
 * changes per topic.
 */
export async function requestFreeformSuggestions(
  topic: AIAdviceTopic,
  concerns: string[],
  userID: string,
): Promise<string[] | null> {
  const config = await resolveAIProviderConfig(userID);
  if (!config) return null;

  const prompt = buildAdvicePrompt(topic, concerns);
  try {
    const rawText = config.provider === "openai"
      ? await callOpenAI(config, prompt)
      : await callAnthropic(config, prompt);
    return parseSuggestionsResponse(rawText);
  } catch (error) {
    console.error("AI provider call failed for freeform suggestions.", error);
    return null;
  }
}

const TOPIC_FRAMING: Record<AIAdviceTopic, { persona: string; askedFor: string; fallback: string }> = {
  skincare: {
    persona: "你是一個美容生活管理 App 的護膚顧問。",
    askedFor: "請推薦適用的保養品成分與保養方式",
    fallback: "使用者未提供具體問題，請給通用的護膚建議",
  },
  hair: {
    persona: "你是一個美容生活管理 App 的頭髮/頭皮顧問。",
    askedFor: "請給出洗護習慣、頭皮護理或養髮建議",
    fallback: "使用者未提供具體問題，請給通用的頭髮養護建議",
  },
  facialLift: {
    persona: "你是一個美容生活管理 App 的臉部保養顧問。",
    askedFor: "請給出具體、可執行的改善建議（例如：臉部按摩手法、瑜珈動作、保養品成分、生活習慣調整）",
    fallback: "使用者未提供具體問題，請給通用的臉部緊緻保養建議",
  },
  bodySkin: {
    persona: "你是一個美容生活管理 App 的身體皮膚保養顧問。",
    askedFor: "請推薦適用的產品成分與保養方式",
    fallback: "使用者未提供具體問題，請給通用的身體皮膚保養建議",
  },
  diet: {
    persona: "你是一個美容生活管理 App 的營養顧問。",
    askedFor: "請依據今日飲食內容，給出營養補充建議",
    fallback: "使用者未提供今日飲食記錄，請給通用的均衡飲食建議",
  },
  makeup: {
    persona: "你是一個美容生活管理 App 的妝容造型顧問。",
    askedFor: "請推薦適合的妝容風格、配色與技巧",
    fallback: "使用者未提供場合或風格偏好，請給通用的妝容建議",
  },
  exercise: {
    persona: "你是一個美容生活管理 App 的運動健身顧問。",
    askedFor: "請推薦適合的運動類型、訓練動作與頻率",
    fallback: "使用者未提供具體部位或目標，請給通用的運動建議",
  },
  wellness: {
    persona: "你是一個美容生活管理 App 的養生顧問。",
    askedFor: "請依據症狀，給出個人化的養生與生活習慣建議",
    fallback: "使用者未提供想改善的方向，請給通用的養生建議",
  },
  finance: {
    persona: "你是一個美容生活管理 App 的個人理財顧問。",
    askedFor: "請依據消費概況，給出預算分配與節省建議",
    fallback: "使用者未提供消費數據，請給通用的理財建議",
  },
  nourishment: {
    persona: "你是一個美容生活管理 App 的中式養生內調顧問。",
    askedFor: "請依據症狀與想改善的方向，給出茶飲、食療與體質調養建議",
    fallback: "使用者未提供症狀或方向，請給通用的內調養生建議",
  },
};

function buildAdvicePrompt(topic: AIAdviceTopic, concerns: string[]): string {
  const framing = TOPIC_FRAMING[topic];
  return [
    framing.persona,
    `使用者輸入了以下需求，${framing.askedFor}，給出 4 到 6 個具體建議。`,
    "請只回覆一個 JSON 物件，不要有任何其他文字、不要用 markdown code block。",
    `JSON 格式：{"suggestions": string[]}`,
    `使用者輸入：${concerns.join("、") || `（${framing.fallback}）`}`,
  ].join("\n");
}

function parseSuggestionsResponse(rawText: string): string[] {
  const jsonText = extractJSONObject(rawText);
  const parsed = JSON.parse(jsonText);
  const suggestions = Array.isArray(parsed.suggestions)
    ? parsed.suggestions.filter((item: unknown) => typeof item === "string" && item.trim()).slice(0, 8)
    : [];

  if (suggestions.length === 0) {
    throw new Error("AI response did not include any suggestions.");
  }

  return suggestions;
}

function buildPrompt(draft: ResourceImportDraft): string {
  return [
    "你是一個美容生活管理 App 的內容分析助手。",
    "請分析以下使用者收藏的內容，並只回覆一個 JSON 物件，不要有任何其他文字、不要用 markdown code block。",
    "JSON 格式：",
    `{"summary": string, "insights": string[], "recommendedActions": string[](最多3個), "category": "skincare"|"fitness"|"food"|"outfit"|"learning"|"other", "confidence": number(0到1)}`,
    "內容資訊：",
    `來源平台：${draft.source}`,
    `標題：${draft.title || "（無標題）"}`,
    `描述：${draft.descriptionText || "（無描述）"}`,
    `作者：${draft.authorName || "（未知）"}`,
    `標籤：${draft.tags.join(", ") || "（無）"}`,
  ].join("\n");
}

async function callOpenAI(config: AIProviderConfig, prompt: string): Promise<string> {
  const response = await fetch(`${config.baseURL}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${config.apiKey}`,
    },
    body: JSON.stringify({
      model: config.model,
      temperature: 0.3,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: "You only respond with strict JSON matching the requested schema." },
        { role: "user", content: prompt },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`OpenAI request failed: ${response.status} ${await response.text()}`);
  }
  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("OpenAI response missing message content.");
  }
  return content;
}

async function callAnthropic(config: AIProviderConfig, prompt: string): Promise<string> {
  const response = await fetch(`${config.baseURL}/messages`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": config.apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: config.model,
      max_tokens: 1024,
      temperature: 0.3,
      messages: [
        { role: "user", content: `${prompt}\n\n只回覆 JSON，不要加任何說明文字或 markdown code block。` },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`Anthropic request failed: ${response.status} ${await response.text()}`);
  }
  const data = await response.json();
  const content = data?.content?.[0]?.text;
  if (typeof content !== "string") {
    throw new Error("Anthropic response missing content text.");
  }
  return content;
}

function parseAIResponse(rawText: string, config: AIProviderConfig): AIAnalysisResult {
  const jsonText = extractJSONObject(rawText);
  const parsed = JSON.parse(jsonText);

  const summary = typeof parsed.summary === "string" && parsed.summary.trim()
    ? parsed.summary.trim()
    : "AI 分析未提供摘要。";
  const insights = Array.isArray(parsed.insights)
    ? parsed.insights.filter((item: unknown) => typeof item === "string" && item.trim()).slice(0, 6)
    : [];
  const recommendedActions = Array.isArray(parsed.recommendedActions)
    ? parsed.recommendedActions.filter((item: unknown) => typeof item === "string" && item.trim()).slice(0, 3)
    : [];
  const category: ResourceCategory | undefined = VALID_CATEGORIES.includes(parsed.category)
    ? parsed.category
    : undefined;
  const confidence = typeof parsed.confidence === "number"
    ? Math.max(0, Math.min(1, parsed.confidence))
    : 0.6;

  if (recommendedActions.length === 0) {
    throw new Error("AI response did not include any recommendedActions.");
  }

  return {
    summary,
    insights,
    recommendedActions,
    confidence,
    provider: `${config.provider}:${config.model}`,
    generatedAt: new Date().toISOString(),
    category,
  };
}

function extractJSONObject(text: string): string {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]+?)\s*```/i);
  const candidate = fenced ? fenced[1] : trimmed;
  const start = candidate.indexOf("{");
  const end = candidate.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) {
    throw new Error("AI response did not contain a JSON object.");
  }
  return candidate.slice(start, end + 1);
}
