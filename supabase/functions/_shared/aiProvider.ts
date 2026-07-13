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
export interface FreeformAdviceResult {
  suggestions: string[];
  routineSteps: string[];
  products: string[];
}

/**
 * 產品類主題先打 Tavily 即時網頁搜尋，把最新市售產品/評價摘要餵給 LLM，
 * 讓推薦不受模型知識截止時間限制。沒設 TAVILY_API_KEY 或搜尋失敗時
 * 直接略過，不影響建議產生。
 */
const WEB_SEARCH_TOPICS: AIAdviceTopic[] = ["skincare", "hair", "bodySkin", "makeup", "diet", "nourishment"];

async function searchWebForProducts(topic: AIAdviceTopic, concerns: string[]): Promise<string> {
  const apiKey = (Deno.env.get("TAVILY_API_KEY") ?? "").trim();
  if (!apiKey || !WEB_SEARCH_TOPICS.includes(topic) || concerns.length === 0) return "";

  try {
    const query = `${concerns.slice(0, 3).join(" ")} 推薦 產品 評價 ${new Date().getFullYear()}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    const response = await fetch("https://api.tavily.com/search", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        api_key: apiKey,
        query,
        search_depth: "basic",
        max_results: 4,
        include_answer: false,
      }),
      signal: controller.signal,
    });
    clearTimeout(timer);
    if (!response.ok) return "";

    const data = await response.json();
    const results = Array.isArray(data?.results) ? data.results : [];
    const lines = results
      .filter((r: { title?: string; content?: string }) => r?.title && r?.content)
      .slice(0, 4)
      .map((r: { title: string; content: string }) => `- ${r.title}：${r.content.slice(0, 160)}`);
    return lines.length > 0 ? lines.join("\n") : "";
  } catch (error) {
    console.error("Tavily search failed; continuing without web context.", error);
    return "";
  }
}

export async function requestFreeformSuggestions(
  topic: AIAdviceTopic,
  concerns: string[],
  userID: string,
): Promise<FreeformAdviceResult | null> {
  const config = await resolveAIProviderConfig(userID);
  if (!config) return null;

  const webContext = await searchWebForProducts(topic, concerns);
  const prompt = buildAdvicePrompt(topic, concerns, webContext);
  try {
    const rawText = config.provider === "openai"
      ? await callOpenAI(config, prompt)
      : await callAnthropic(config, prompt);
    return parseSuggestionsResponse(rawText, topic);
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

function buildAdvicePrompt(topic: AIAdviceTopic, concerns: string[], webContext = ""): string {
  const framing = TOPIC_FRAMING[topic];
  const lines = [
    framing.persona,
    // 輸出 token 量直接決定回應速度，限制條數與每條長度讓使用者不用等太久
    `使用者輸入了以下需求，${framing.askedFor}，給出 3 到 5 個具體建議，每個建議一句話、40 字以內。`,
  ];

  if (webContext) {
    lines.push(
      "以下是即時網路搜尋到的最新產品與評價摘要，產品推薦請優先根據這些最新資訊，並在推薦時保留品牌與產品名：",
      webContext,
    );
  }

  if (topic === "skincare") {
    lines.push(
      "另外，請額外整理出可以直接加入使用者「護膚流程」的具體步驟，以及可以加入「保養品清單」的產品推薦。",
      "產品推薦請給出真實市售產品（品牌＋產品名＋關鍵成分），優先挑選近年口碑好、廣泛好評的產品，每項一句話內；不確定的品牌寧可給成分類型也不要虛構產品名。",
      "請只回覆一個 JSON 物件，不要有任何其他文字、不要用 markdown code block。",
      `JSON 格式：{"suggestions": string[], "routineSteps": string[](2到3個), "products": string[](2到3個)}`,
    );
  } else {
    lines.push(
      "如果建議中涉及可購買的產品或用品，請在建議句中直接點名真實市售產品（品牌＋產品名），優先近年口碑好者；不確定就描述成分/類型即可，不要虛構。",
      "請只回覆一個 JSON 物件，不要有任何其他文字、不要用 markdown code block。",
      `JSON 格式：{"suggestions": string[]}`,
    );
  }

  lines.push(`使用者輸入：${concerns.join("、") || `（${framing.fallback}）`}`);
  return lines.join("\n");
}

function parseSuggestionsResponse(rawText: string, topic: AIAdviceTopic): FreeformAdviceResult {
  const jsonText = extractJSONObject(rawText);
  const parsed = JSON.parse(jsonText);
  const suggestions = Array.isArray(parsed.suggestions)
    ? parsed.suggestions.filter((item: unknown) => typeof item === "string" && item.trim()).slice(0, 8)
    : [];

  if (suggestions.length === 0) {
    throw new Error("AI response did not include any suggestions.");
  }

  const routineSteps = topic === "skincare" && Array.isArray(parsed.routineSteps)
    ? parsed.routineSteps.filter((item: unknown) => typeof item === "string" && item.trim()).slice(0, 4)
    : [];
  const products = topic === "skincare" && Array.isArray(parsed.products)
    ? parsed.products.filter((item: unknown) => typeof item === "string" && item.trim()).slice(0, 4)
    : [];

  return { suggestions, routineSteps, products };
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
      // 沒有上限時部分模型會生成過長內容，拖慢回應
      max_tokens: 700,
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

export interface ProductLookupResult {
  name: string;
  brand: string;
  category: string;
  notes: string;
}

/**
 * Identifies a skincare/haircare product from a name and/or a photo, so
 * 新增保養品 doesn't require typing in brand/category/notes by hand.
 * Photo lookups use a vision-capable model (OpenAI gpt-4o-mini and recent
 * Claude models both support image input); name-only lookups are a plain
 * text best-effort guess.
 */
export async function requestProductLookup(
  name: string | undefined,
  imageBase64: string | undefined,
  userID: string,
): Promise<ProductLookupResult | null> {
  const config = await resolveAIProviderConfig(userID);
  if (!config) return null;

  const instructions = [
    "你是一個美容產品辨識助手。",
    imageBase64
      ? "請辨識照片中的美容/保養/洗護產品，盡量判斷品牌、產品名稱、分類（如：精華液、乳液、洗面乳、洗髮精等）與成分/用途備註。"
      : `請根據產品名稱「${name ?? ""}」推測這個產品的品牌、分類與成分/用途備註，盡量符合真實市售產品；如果不確定真實品牌，類別與備註仍要給出合理的推測。`,
    "請只回覆一個 JSON 物件，不要有任何其他文字、不要用 markdown code block。",
    `JSON 格式：{"name": string, "brand": string, "category": string, "notes": string}`,
    name && imageBase64 ? `使用者輸入的名稱：${name}` : "",
  ].filter(Boolean).join("\n");

  try {
    const rawText = imageBase64
      ? config.provider === "openai"
        ? await callOpenAIVision(config, instructions, imageBase64)
        : await callAnthropicVision(config, instructions, imageBase64)
      : config.provider === "openai"
        ? await callOpenAI(config, instructions)
        : await callAnthropic(config, instructions);

    const jsonText = extractJSONObject(rawText);
    const parsed = JSON.parse(jsonText);
    const resultName = typeof parsed.name === "string" ? parsed.name.trim() : "";
    if (!resultName) return null;

    return {
      name: resultName,
      brand: typeof parsed.brand === "string" ? parsed.brand.trim() : "",
      category: typeof parsed.category === "string" ? parsed.category.trim() : "",
      notes: typeof parsed.notes === "string" ? parsed.notes.trim() : "",
    };
  } catch (error) {
    console.error("AI provider call failed for product lookup.", error);
    return null;
  }
}

async function callOpenAIVision(config: AIProviderConfig, prompt: string, imageBase64: string): Promise<string> {
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
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } },
          ],
        },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`OpenAI vision request failed: ${response.status} ${await response.text()}`);
  }
  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("OpenAI vision response missing message content.");
  }
  return content;
}

async function callAnthropicVision(config: AIProviderConfig, prompt: string, imageBase64: string): Promise<string> {
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
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
            { type: "text", text: `${prompt}\n\n只回覆 JSON，不要加任何說明文字或 markdown code block。` },
          ],
        },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`Anthropic vision request failed: ${response.status} ${await response.text()}`);
  }
  const data = await response.json();
  const content = data?.content?.[0]?.text;
  if (typeof content !== "string") {
    throw new Error("Anthropic vision response missing content text.");
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
