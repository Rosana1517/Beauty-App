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
  imageList: string[];
  videoURL: string | null;
  likeCount: number | null;
  richSource: "xhsState" | "igSidecar" | "fallback";
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
  const category = analysis.category ?? normalizeCategory(draft.category, draft.title, draft.descriptionText, draft.source);
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

  const base: ParsedMetadata = {
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
    imageList: thumbnailURL ? [thumbnailURL] : [],
    videoURL: null,
    likeCount: null,
    richSource: "fallback",
  };

  if (source === "xiaohongshu") {
    return enrichWithXHSState(base, html);
  }
  if (source === "instagram") {
    return enrichWithInstagramData(base, html);
  }
  return base;
}

function enrichWithXHSState(metadata: ParsedMetadata, html: string): ParsedMetadata {
  const state = extractXHSInitialState(html);
  if (!state) return metadata;

  // The XHS SSR state shape is undocumented and varies by note type, so we
  // intentionally read it as `any` rather than maintaining a brittle type.
  // deno-lint-ignore no-explicit-any
  const note = findNoteDetail(state) as any;
  if (!note) return metadata;

  const images = Array.isArray(note.imageList)
    ? note.imageList
      .map((item: unknown) => (typeof item === "string" ? item : (item as Record<string, unknown>)?.urlDefault ?? (item as Record<string, unknown>)?.url))
      .filter((url: unknown): url is string => typeof url === "string" && url.length > 0)
    : [];
  const videoURL = typeof note.video?.media?.stream?.h264?.[0]?.masterUrl === "string"
    ? note.video.media.stream.h264[0].masterUrl
    : typeof note.video?.url === "string"
      ? note.video.url
      : null;
  const likeCount = typeof note.interactInfo?.likedCount === "string"
    ? Number(note.interactInfo.likedCount) || null
    : typeof note.interactInfo?.likedCount === "number"
      ? note.interactInfo.likedCount
      : null;
  const tags = Array.isArray(note.tagList)
    ? note.tagList.map((tag: Record<string, unknown>) => String(tag?.name ?? "")).filter(Boolean)
    : metadata.tags;

  return {
    ...metadata,
    title: firstNonEmpty(String(note.title ?? ""), metadata.title),
    descriptionText: firstNonEmpty(String(note.desc ?? ""), metadata.descriptionText),
    authorName: firstNonEmpty(String(note.user?.nickname ?? ""), metadata.authorName),
    thumbnailURL: firstNonEmpty(images[0] ?? "", metadata.thumbnailURL),
    publishedAt: normalizeDate(String(note.time ?? "")) ?? metadata.publishedAt,
    tags,
    imageList: images.length > 0 ? images : metadata.imageList,
    videoURL,
    likeCount,
    platformContentType: videoURL ? "video" : images.length > 1 ? "carousel" : images.length === 1 ? "imagePost" : metadata.platformContentType,
    richSource: "xhsState",
  };
}

function enrichWithInstagramData(metadata: ParsedMetadata, html: string): ParsedMetadata {
  const ogImages = extractAllMeta(html, "og:image");
  const sidecarImages = extractInstagramSidecarImages(html);
  const images = dedupe([...sidecarImages, ...ogImages, ...metadata.imageList]);
  if (images.length === 0) return metadata;

  const videoURL = extractMeta(html, "og:video") || extractMeta(html, "og:video:url") || null;

  return {
    ...metadata,
    thumbnailURL: firstNonEmpty(images[0] ?? "", metadata.thumbnailURL),
    imageList: images,
    videoURL: videoURL || metadata.videoURL,
    platformContentType: videoURL ? "video" : images.length > 1 ? "carousel" : "imagePost",
    richSource: sidecarImages.length > 0 ? "igSidecar" : metadata.richSource,
  };
}

/**
 * 小紅書頁面在 SSR 階段會把整篇筆記資料以 `window.__INITIAL_STATE__ = {...}`
 * 的形式內嵌在 HTML 中，這比公開的 og: meta tag 完整得多（含多圖、影片、互動數）。
 * 頁面可能含多個 `<script>` 區塊，較新/完整的狀態通常出現在較後面的區塊，
 * 因此優先嘗試「最後一個」符合前綴的 script，找不到才退回第一個相符的。
 * 物件中可能含 JS 字面量 `undefined`/`NaN`，需先正規化成合法 JSON 再解析；
 * 若仍解析失敗則放寬限制再試一次（移除控制字元、修剪結尾多餘逗號）。
 */
function extractXHSInitialState(html: string): Record<string, unknown> | null {
  const candidates = Array.from(
    html.matchAll(/window\.__INITIAL_STATE__\s*=\s*(\{[\s\S]*?\})\s*(?:;\s*(?:<\/script>|window\.)|<\/script>)/g),
  ).map((match) => match[1]);
  if (candidates.length === 0) return null;

  for (const candidate of [...candidates].reverse()) {
    const parsed = tryParseJSLiteralObject(candidate);
    if (parsed) return parsed;
  }
  return null;
}

function tryParseJSLiteralObject(raw: string): Record<string, unknown> | null {
  const normalized = raw
    .replace(/:\s*undefined/g, ": null")
    .replace(/:\s*NaN/g, ": null")
    // deno-lint-ignore no-control-regex
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, "")
    .replace(/,(\s*[}\]])/g, "$1");
  try {
    return JSON.parse(normalized);
  } catch {
    return null;
  }
}

/**
 * 手機版頁面（`noteData.data.noteData`）與桌面版頁面
 * （`note.noteDetailMap.<noteID>.note`）的狀態結構不同，因此兩條路徑都嘗試。
 * `noteDetailMap` 可能含多筆（例如同時帶入相關推薦筆記），取「最後一筆」
 * 通常對應目前瀏覽的筆記本身。
 */
function findNoteDetail(state: Record<string, unknown>): Record<string, unknown> | null {
  const phonePath = deepGet(state, ["noteData", "data", "noteData"]);
  if (phonePath) return phonePath as Record<string, unknown>;

  const noteData = state?.note as Record<string, unknown> | undefined;
  const noteDetailMap = noteData?.noteDetailMap as Record<string, unknown> | undefined;
  if (!noteDetailMap) return null;
  const entries = Object.values(noteDetailMap) as Record<string, unknown>[];
  const lastEntry = entries[entries.length - 1];
  const note = lastEntry?.note as Record<string, unknown> | undefined;
  return note ?? null;
}

function deepGet(data: unknown, keys: string[]): unknown {
  let current = data;
  for (const key of keys) {
    if (current == null || typeof current !== "object") return undefined;
    current = (current as Record<string, unknown>)[key];
  }
  return current;
}

/**
 * Instagram 對未登入的爬蟲已大幅限制資料，但部分公開貼文頁仍會在
 * `edge_sidecar_to_children` 結構中以 SEO 用途留下完整輪播圖網址。
 * 這裡用寬鬆字串掃描而非完整 JSON parse，因為該結構通常深埋在大型
 * `additionalDataLoaded`／`__NEXT_DATA__` blob 裡，完整 parse 容易因
 * 版面變動而整段失敗。
 */
function extractInstagramSidecarImages(html: string): string[] {
  const matches = html.matchAll(/"display_url":"([^"]+)"/g);
  const urls = Array.from(matches, (m) => m[1].replace(/\\u0026/g, "&").replace(/\\\//g, "/"));
  return dedupe(urls);
}

function dedupe(values: string[]): string[] {
  return Array.from(new Set(values.filter((value) => value && value.trim().length > 0)));
}

function buildDraft(
  metadata: ParsedMetadata,
  source: ImportSourceType,
  retentionPolicy: MediaRetentionPolicy,
  xhsPayload: XHSParsedPayload | null,
): ResourceImportDraft {
  const category = normalizeCategory("all", metadata.title, metadata.descriptionText, source);
  const mediaAssets = xhsPayload?.mediaAssets ?? buildAssetsFromImages(
    metadata.imageList.length > 0 ? metadata.imageList : [metadata.thumbnailURL].filter(Boolean),
    metadata.platformContentType,
    retentionPolicy,
    metadata.videoURL,
  );
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
  const mediaAssets = buildAssetsFromImages(
    metadata.imageList.length > 0 ? metadata.imageList : [metadata.thumbnailURL].filter(Boolean),
    metadata.platformContentType,
    retentionPolicy,
    metadata.videoURL,
  );
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
    likeCount: metadata.likeCount,
    tags: metadata.tags,
    publishedAt: metadata.publishedAt ?? null,
    contentType: mapToXHSContentType(metadata.platformContentType),
    mediaAssets,
    commentsPreview: [],
    rawSnapshot: metadata.html,
  };
}

function buildAssetsFromImages(
  imageURLs: string[],
  contentType: ImportedContentType,
  retentionPolicy: MediaRetentionPolicy,
  videoURL?: string | null,
): XHSMediaAsset[] {
  const assets: XHSMediaAsset[] = imageURLs.map((url, index) => ({
    id: crypto.randomUUID(),
    assetID: `image-${index}`,
    type: contentType === "video" && index === 0 ? "cover" : "image",
    remoteURL: url,
    previewURL: url,
    width: null,
    height: null,
    duration: null,
    index,
    retentionPolicy,
    localStoragePath: null,
    checksum: null,
    isSelectedForImport: true,
    expiresAt: null,
  }));

  if (videoURL) {
    assets.push({
      id: crypto.randomUUID(),
      assetID: "video-0",
      type: "video",
      remoteURL: videoURL,
      previewURL: imageURLs[0] ?? videoURL,
      width: null,
      height: null,
      duration: null,
      index: assets.length,
      retentionPolicy,
      localStoragePath: null,
      checksum: null,
      isSelectedForImport: true,
      expiresAt: null,
    });
  }

  return assets;
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
  if (metadata.title) score += 0.2;
  if (metadata.descriptionText) score += 0.1;
  if (metadata.authorName) score += 0.1;
  if (metadata.thumbnailURL) score += 0.1;
  if (metadata.externalID) score += 0.1;
  if (metadata.publishedAt) score += 0.05;
  if (metadata.imageList.length > 1) score += 0.05;
  if (metadata.videoURL) score += 0.05;
  if (metadata.richSource !== "fallback") score += 0.1;
  return Math.min(0.97, score);
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

function extractAllMeta(html: string, name: string): string[] {
  const patterns = [
    new RegExp(`<meta[^>]+property=["']${escapeRegExp(name)}["'][^>]+content=["']([^"']+)["']`, "gi"),
    new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+property=["']${escapeRegExp(name)}["']`, "gi"),
  ];
  const results: string[] = [];
  for (const pattern of patterns) {
    for (const match of html.matchAll(pattern)) {
      if (match[1]) results.push(decodeHTMLEntities(match[1].trim()));
    }
  }
  return dedupe(results);
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
