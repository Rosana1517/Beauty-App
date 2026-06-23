import type { AIAnalysisResult, ResourceCategory, ResourceImportDraft } from "./types.ts";

interface AIProviderConfig {
  provider: "openai" | "anthropic";
  apiKey: string;
  model: string;
  baseURL: string;
}

const VALID_CATEGORIES: ResourceCategory[] = ["skincare", "fitness", "food", "outfit", "learning", "other"];

function getAIProviderConfig(): AIProviderConfig | null {
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
export async function analyzeWithAI(draft: ResourceImportDraft): Promise<AIAnalysisResult | null> {
  const config = getAIProviderConfig();
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
