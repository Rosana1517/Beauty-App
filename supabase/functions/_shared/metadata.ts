import type {
  AIAnalysisResult,
  AuthorizedImportRequest,
  AuthorizedImportResponse,
  ImportSourceType,
  ImportedContentType,
  MediaRetentionPolicy,
  ResourceCategory,
  ResourceImportDraft,
  ResourceImportStatus,
  ResourceRecommendationCard,
  XHSMediaAsset,
  XHSParsedPayload,
} from "./types.ts";

interface ParsedMetadata {
  title: string;
  descriptionText: string;
  authorName: string;
  thumbnailURL: string;
  canonicalURL: string;
  externalID: string;
  publishedAt?: string | null;
  platformContentType: ImportedContentType;
  tags: string[];
  htmlTitle: string;
  pageHost: string;
  finalURL: string;
  html: string;
}

const USER_AGENT =
  "Mozilla/5.0 (compatible; BeautyDiaryBot/1.0; +https://github.com/Rosana1517/Beauty-App)";

export function detectSource(inputURL: string): ImportSourceType {
  try {
    const url = new URL(inputURL);
    const host = url.hostname.toLowerCase();
    if (host.includes("xiaohongshu") || host.includes("xhslink")) return "xiaohongshu";
    if (host.includes("instagram")) return "instagram";
    if (host.includes("youtu.be") || host.includes("youtube.com")) return "youtube";
    return "web";
  } catch {
    return "web";
  }
}

export async function parseImportRequest(request: AuthorizedImportRequest): Promise<AuthorizedImportResponse> {
  const source = request.source ?? detectSource(request.url);
  const normalizedURL = request.url.trim();
  const metadata = await fetchMetadata(normalizedURL, source);
  const xhsPayload = source === "xiaohongshu" ? buildXHSPayload(metadata, normalizedURL, request.downloadPolicy) : null;
  const draft = buildDraft(metadata, source, request.downloadPolicy, xhsPayload);
  return { draft, xhsPayload };
}

export function createAnalysis(draft: ResourceImportDraft): AIAnalysisResult {
  const category = normalizeCategory(draft.category, draft.title, draft.descriptionText, draft.source);
  return {
    summary: `已整理 ${draft.source} 內容「${draft.title || "未命名資源"}」，可直接進行後續追蹤與推薦。`,
    insights: [
      `分類建議：${category}`,
      `內容型別：${draft.platformContentType}`,
      draft.authorName ? `作者：${draft.authorName}` : "作者資訊不足，建議保留手動補齊入口。",
    ],
    recommendedActions: actionTemplates(category),
    confidence: Math.max(0.45, Math.min(0.95, draft.metadataConfidence)),
    provider: "edge-rule-engine",
    generatedAt: new Date().toISOString(),
  };
}

export function createRecommendations(draft: ResourceImportDraft, analysis: AIAnalysisResult): ResourceRecommendationCard[] {
  const category = normalizeCategory(draft.category, draft.title, draft.descriptionText, draft.source);
  return analysis.recommendedActions.slice(0, 3).map((title, index) => ({
    id: crypto.randomUUID(),
    title,
    detail: `根據「${draft.title || "未命名資源"}」自動產生的第 ${index + 1} 項追蹤建議。`,
    category,
    reason: draft.source,
  }));
}

async function fetchMetadata(inputURL: string, source: ImportSourceType): Promise<ParsedMetadata> {
  const response = await fetch(inputURL, {
    headers: {
      "user-agent": USER_AGENT,
      accept: "text/html,application/xhtml+xml,application/json",
    },
    redirect: "follow",
  });
  const html = await response.text();
  const finalURL = response.url || inputURL;
  const title = firstNonEmpty(
    extractMeta(html, "og:title"),
    extractMeta(html, "twitter:title"),
    extractJSONLDField(html, "headline"),
    extractTitle(html),
    defaultTitle(source),
  );
  const descriptionText = firstNonEmpty(
    extractMeta(html, "og:description"),
    extractMeta(html, "description"),
    extractJSONLDField(html, "description"),
    "",
  );
  const authorName = firstNonEmpty(
    extractMeta(html, "author"),
    extractMeta(html, "article:author"),
    extractJSONLDField(html, "author"),
    "",
  );
  const thumbnailURL = firstNonEmpty(
    extractMeta(html, "og:image"),
    extractMeta(html, "twitter:image"),
    "",
  );
  const canonicalURL = firstNonEmpty(extractCanonicalURL(html), finalURL);
  const externalID = source === "youtube" ? extractYouTubeID(finalURL) : extractTrailingToken(canonicalURL);
  const publishedAt = normalizeDate(
    firstNonEmpty(
      extractMeta(html, "article:published_time"),
      extractJSONLDField(html, "datePublished"),
      "",
    ),
  );
  const tags = extractKeywords(html);
  const platformContentType = detectContentType(source, finalURL, html, thumbnailURL);

  return {
    title,
    descriptionText,
    authorName,
    thumbnailURL,
    canonicalURL,
    externalID,
    publishedAt,
    platformContentType,
    tags,
    htmlTitle: extractTitle(html),
    pageHost: safeHost(finalURL),
    finalURL,
    html: html.slice(0, 12000),
  };
}

function buildDraft(
  metadata: ParsedMetadata,
  source: ImportSourceType,
  retentionPolicy: MediaRetentionPolicy,
  xhsPayload: XHSParsedPayload | null,
): ResourceImportDraft {
  const category = normalizeCategory("all", metadata.title, metadata.descriptionText, source);
  const mediaAssets = xhsPayload?.mediaAssets ?? buildGenericAssets(metadata.thumbnailURL, metadata.platformContentType, retentionPolicy);
  const importStatus: ResourceImportStatus = metadata.title ? "parsed" : "partial";
  const confidence = scoreConfidence(metadata);
  return {
    id: crypto.randomUUID(),
    source,
    category,
    platformContentType: metadata.platformContentType,
    title: metadata.title,
    canonicalURL: metadata.canonicalURL,
    originalURL: metadata.finalURL,
    externalID: metadata.externalID,
    authorName: metadata.authorName,
    thumbnailURL: metadata.thumbnailURL,
    publishedAt: metadata.publishedAt ?? null,
    descriptionText: metadata.descriptionText,
    tags: metadata.tags,
    importStatus,
    metadataConfidence: confidence,
    importedAt: null,
    rawMetadataSnapshot: JSON.stringify({
      title: metadata.title,
      descriptionText: metadata.descriptionText,
      authorName: metadata.authorName,
      thumbnailURL: metadata.thumbnailURL,
      canonicalURL: metadata.canonicalURL,
      externalID: metadata.externalID,
      publishedAt: metadata.publishedAt,
      pageHost: metadata.pageHost,
      finalURL: metadata.finalURL,
    }),
    mediaRetentionPolicy: retentionPolicy,
    mediaAssets,
    temporaryMediaLeases: [],
    sourcePayloadSummary: xhsPayload,
    analysisStatus: "pending",
    aiAnalysis: null,
    recommendationCards: [],
    syncStatus: "pending",
    remoteRecordID: "",
    lastSyncedAt: null,
    lastErrorMessage: importStatus === "partial" ? "Metadata incomplete. Manual completion may still be needed." : null,
  };
}

function buildXHSPayload(
  metadata: ParsedMetadata,
  originalURL: string,
  retentionPolicy: MediaRetentionPolicy,
): XHSParsedPayload {
  const noteID = extractTrailingToken(metadata.canonicalURL);
  const mediaAssets = buildGenericAssets(metadata.thumbnailURL, metadata.platformContentType, retentionPolicy);
  return {
    identifier: {
      noteID,
      authorID: "",
      canonicalURL: metadata.canonicalURL,
      shareURL: originalURL,
      xsecToken: extractQueryValue(originalURL, "xsec_token"),
    },
    title: metadata.title,
    description: metadata.descriptionText,
    author: {
      authorID: "",
      name: metadata.authorName,
      avatarURL: "",
      noteCountSummary: "",
    },
    likeCount: null,
    tags: metadata.tags,
    publishedAt: metadata.publishedAt ?? null,
    contentType: mapToXHSContentType(metadata.platformContentType),
    mediaAssets,
    commentsPreview: [],
    rawSnapshot: metadata.html,
  };
}

function buildGenericAssets(
  thumbnailURL: string,
  contentType: ImportedContentType,
  retentionPolicy: MediaRetentionPolicy,
): XHSMediaAsset[] {
  if (!thumbnailURL) return [];
  return [
    {
      id: crypto.randomUUID(),
      assetID: "cover-0",
      type: contentType === "video" ? "cover" : "image",
      remoteURL: thumbnailURL,
      previewURL: thumbnailURL,
      width: null,
      height: null,
      duration: null,
      index: 0,
      retentionPolicy,
      localStoragePath: null,
      checksum: null,
      isSelectedForImport: true,
      expiresAt: null,
    },
  ];
}

function normalizeCategory(
  current: ResourceCategory | "all",
  title: string,
  description: string,
  source: ImportSourceType,
): ResourceCategory {
  if (current !== "all") return current;
  const haystack = `${title} ${description} ${source}`.toLowerCase();
  if (/(skin|護膚|保養|面膜|精華|乳液)/.test(haystack)) return "skincare";
  if (/(fitness|workout|體重|體脂|運動|塑形)/.test(haystack)) return "fitness";
  if (/(food|meal|recipe|飲食|餐|熱量)/.test(haystack)) return "food";
  if (/(outfit|style|穿搭|衣服|穿搭)/.test(haystack)) return "outfit";
  if (/(book|study|learning|閱讀|學習|筆記)/.test(haystack)) return "learning";
  return "other";
}

function actionTemplates(category: ResourceCategory): string[] {
  switch (category) {
    case "skincare":
      return ["建立護膚步驟", "加入保養品追蹤", "安排 7 天打卡"];
    case "fitness":
      return ["建立體態計畫", "記錄體重與體脂", "安排下一次運動"];
    case "food":
      return ["建立飲食紀錄", "整理營養重點", "補一筆餐點追蹤"];
    case "outfit":
      return ["建立穿搭靈感卡", "整理搭配關鍵字", "收藏到風格分類"];
    case "learning":
      return ["加入閱讀追蹤", "整理 3 個重點", "轉成成長筆記"];
    default:
      return ["加入資源庫", "補齊分類資訊", "建立後續行動"];
  }
}

function scoreConfidence(metadata: ParsedMetadata): number {
  let score = 0.25;
  if (metadata.title) score += 0.25;
  if (metadata.descriptionText) score += 0.15;
  if (metadata.authorName) score += 0.1;
  if (metadata.thumbnailURL) score += 0.1;
  if (metadata.externalID) score += 0.1;
  if (metadata.publishedAt) score += 0.05;
  return Math.min(0.95, score);
}

function detectContentType(source: ImportSourceType, url: string, html: string, thumbnailURL: string): ImportedContentType {
  const lowered = `${url} ${html}`.toLowerCase();
  if (source === "youtube" || lowered.includes("video") || lowered.includes("shorts/")) return "video";
  if (lowered.includes("carousel")) return "carousel";
  if (thumbnailURL) return source === "web" ? "article" : "imagePost";
  return source === "web" ? "article" : "unknown";
}

function mapToXHSContentType(contentType: ImportedContentType): XHSParsedPayload["contentType"] {
  switch (contentType) {
    case "video":
      return "video";
    case "carousel":
      return "carousel";
    case "imagePost":
      return "imagePost";
    default:
      return "unknown";
  }
}

function extractMeta(html: string, name: string): string {
  const patterns = [
    new RegExp(`<meta[^>]+property=["']${escapeRegExp(name)}["'][^>]+content=["']([^"']+)["']`, "i"),
    new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+property=["']${escapeRegExp(name)}["']`, "i"),
    new RegExp(`<meta[^>]+name=["']${escapeRegExp(name)}["'][^>]+content=["']([^"']+)["']`, "i"),
    new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+name=["']${escapeRegExp(name)}["']`, "i"),
  ];
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match?.[1]) return decodeHTMLEntities(match[1].trim());
  }
  return "";
}

function extractCanonicalURL(html: string): string {
  const match = html.match(/<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']/i);
  return match?.[1]?.trim() ?? "";
}

function extractTitle(html: string): string {
  const match = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  return decodeHTMLEntities(match?.[1]?.trim() ?? "");
}

function extractJSONLDField(html: string, field: string): string {
  const match = html.match(new RegExp(`"${escapeRegExp(field)}"\\s*:\\s*"([^"]+)"`, "i"));
  return decodeHTMLEntities(match?.[1]?.trim() ?? "");
}

function extractKeywords(html: string): string[] {
  const raw = extractMeta(html, "keywords");
  return raw
    .split(/[,\u3001]/)
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 8);
}

function extractYouTubeID(value: string): string {
  try {
    const url = new URL(value);
    if (url.hostname.includes("youtu.be")) return url.pathname.replace(/^\//, "");
    if (url.pathname.includes("/shorts/")) return url.pathname.split("/shorts/")[1]?.split("/")[0] ?? "";
    return url.searchParams.get("v") ?? "";
  } catch {
    return "";
  }
}

function extractTrailingToken(value: string): string {
  return value.split("/").filter(Boolean).pop() ?? "";
}

function extractQueryValue(value: string, key: string): string {
  try {
    return new URL(value).searchParams.get(key) ?? "";
  } catch {
    return "";
  }
}

function normalizeDate(value: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function safeHost(value: string): string {
  try {
    return new URL(value).host;
  } catch {
    return "";
  }
}

function firstNonEmpty(...values: string[]): string {
  return values.find((value) => value && value.trim().length > 0)?.trim() ?? "";
}

function defaultTitle(source: ImportSourceType): string {
  switch (source) {
    case "xiaohongshu":
      return "小紅書收藏";
    case "instagram":
      return "Instagram 收藏";
    case "youtube":
      return "YouTube 收藏";
    case "web":
      return "網頁收藏";
  }
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function decodeHTMLEntities(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");
}
