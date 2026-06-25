export type ImportSourceType = "xiaohongshu" | "youtube" | "instagram" | "web";
export type ImportedContentType = "video" | "imagePost" | "carousel" | "article" | "unknown";
export type ResourceCategory = "skincare" | "fitness" | "food" | "outfit" | "learning" | "other";
export type ResourceImportStatus = "parsed" | "partial" | "manualCompleted" | "failedFallbackSaved";
export type MediaRetentionPolicy = "metadataOnly" | "temporaryCache" | "explicitKeep";
export type ResourceAnalysisStatus = "pending" | "analyzing" | "analyzed" | "fallback";
export type ResourceSyncStatus = "pending" | "syncing" | "succeeded" | "failed";
export type XHSNoteContentType = "video" | "imagePost" | "carousel" | "livePhoto" | "unknown";
export type XHSMediaAssetType = "image" | "video" | "cover" | "livePhoto" | "unknown";

export interface AuthorizedImportRequest {
  source: ImportSourceType;
  url: string;
  downloadPolicy: MediaRetentionPolicy;
  selectedIndexes?: number[] | null;
  needComments: boolean;
}

export interface XHSNoteIdentifier {
  noteID: string;
  authorID: string;
  canonicalURL: string;
  shareURL: string;
  xsecToken: string;
}

export interface XHSAuthorProfile {
  authorID: string;
  name: string;
  avatarURL: string;
  noteCountSummary: string;
}

export interface XHSMediaAsset {
  id: string;
  assetID: string;
  type: XHSMediaAssetType;
  remoteURL: string;
  previewURL: string;
  width?: number | null;
  height?: number | null;
  duration?: number | null;
  index: number;
  retentionPolicy: MediaRetentionPolicy;
  localStoragePath?: string | null;
  checksum?: string | null;
  isSelectedForImport: boolean;
  expiresAt?: string | null;
}

export interface XHSParsedPayload {
  identifier: XHSNoteIdentifier;
  title: string;
  description: string;
  author: XHSAuthorProfile;
  likeCount?: number | null;
  tags: string[];
  publishedAt?: string | null;
  contentType: XHSNoteContentType;
  mediaAssets: XHSMediaAsset[];
  commentsPreview: string[];
  rawSnapshot: string;
}

export interface AIAnalysisResult {
  summary: string;
  insights: string[];
  recommendedActions: string[];
  confidence: number;
  provider: string;
  generatedAt: string;
  category?: ResourceCategory;
}

export interface ResourceRecommendationCard {
  id: string;
  title: string;
  detail: string;
  category: ResourceCategory;
  reason: string;
}

export interface TemporaryMediaLease {
  id: string;
  assetID: string;
  resourceID?: string | null;
  storagePath: string;
  retentionPolicy: MediaRetentionPolicy;
  expiresAt: string;
  cleanedAt?: string | null;
  cleanupStatus: ResourceSyncStatus;
}

export interface ResourceImportDraft {
  id: string;
  source: ImportSourceType;
  category: ResourceCategory | "all";
  platformContentType: ImportedContentType;
  title: string;
  canonicalURL: string;
  originalURL: string;
  externalID: string;
  authorName: string;
  thumbnailURL: string;
  publishedAt?: string | null;
  descriptionText: string;
  tags: string[];
  importStatus: ResourceImportStatus;
  metadataConfidence: number;
  importedAt?: string | null;
  rawMetadataSnapshot: string;
  mediaRetentionPolicy: MediaRetentionPolicy;
  mediaAssets: XHSMediaAsset[];
  temporaryMediaLeases: TemporaryMediaLease[];
  sourcePayloadSummary?: XHSParsedPayload | null;
  analysisStatus: ResourceAnalysisStatus;
  aiAnalysis?: AIAnalysisResult | null;
  recommendationCards: ResourceRecommendationCard[];
  syncStatus: ResourceSyncStatus;
  remoteRecordID: string;
  lastSyncedAt?: string | null;
  lastErrorMessage?: string | null;
}

export interface AuthorizedImportResponse {
  draft: ResourceImportDraft;
  xhsPayload?: XHSParsedPayload | null;
}

export interface ReparseJobRequest {
  resourceID: string;
  reason: string;
}

export interface MediaCleanupJobRequest {
  resourceID: string;
  retentionPolicy: MediaRetentionPolicy;
}

export interface RecommendationFunctionRequest {
  resourceID: string;
}

export interface RecommendationFunctionResponse {
  cards: ResourceRecommendationCard[];
}

export type AIAdviceTopic = "skincare" | "hair" | "facialLift" | "bodySkin" | "diet" | "makeup" | "exercise" | "wellness" | "finance" | "nourishment";

export interface AIAdviceRequest {
  topic: AIAdviceTopic;
  concerns: string[];
}

export interface AIAdviceResponse {
  suggestions: string[];
  routineSteps?: string[];
  products?: string[];
}

export interface SupabaseQueueJobResponse {
  id: string;
  sync_status: ResourceSyncStatus;
  retry_count: number;
  last_error?: string | null;
  created_at: string;
  updated_at: string;
}
