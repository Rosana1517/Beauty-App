import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { createAnalysis, createRecommendations } from "../_shared/metadata.ts";
import { createAdminClient, resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type {
  RecommendationFunctionRequest,
  RecommendationFunctionResponse,
  ResourceImportDraft,
} from "../_shared/types.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as RecommendationFunctionRequest;
    if (!payload?.resourceID) {
      return jsonResponse({ error: "Missing resourceID." }, 400);
    }

    const supabase = createAdminClient();
    const { data: resource, error: resourceError } = await supabase
      .from("resource_items")
      .select("*")
      .eq("id", payload.resourceID)
      .eq("user_id", userID)
      .single();

    if (resourceError || !resource) {
      return jsonResponse({ error: "Resource not found." }, 404);
    }

    const draft = resourceRowToDraft(resource);
    const analysis = createAnalysis(draft);
    const cards = createRecommendations(draft, analysis);

    const { error: clearAnalysisError } = await supabase
      .from("resource_analysis_results")
      .delete()
      .eq("resource_id", payload.resourceID);

    if (clearAnalysisError) {
      throw clearAnalysisError;
    }

    const { error: analysisError } = await supabase
      .from("resource_analysis_results")
      .insert({
        resource_id: payload.resourceID,
        provider: analysis.provider,
        status: "analyzed",
        summary: analysis.summary,
        insights: analysis.insights,
        recommended_actions: analysis.recommendedActions,
        confidence: analysis.confidence,
      });

    if (analysisError) {
      throw analysisError;
    }

    const { error: deleteError } = await supabase
      .from("resource_recommendations")
      .delete()
      .eq("resource_id", payload.resourceID);

    if (deleteError) {
      throw deleteError;
    }

    if (cards.length > 0) {
      const { error: insertError } = await supabase
        .from("resource_recommendations")
        .insert(cards.map((card) => ({
          resource_id: payload.resourceID,
          title: card.title,
          detail: card.detail,
          category: card.category,
          reason: card.reason,
        })));

      if (insertError) {
        throw insertError;
      }
    }

    const response: RecommendationFunctionResponse = { cards };
    return jsonResponse(response);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected recommendation error." },
      500,
    );
  }
});

function resourceRowToDraft(row: Record<string, unknown>): ResourceImportDraft {
  return {
    id: String(row.id),
    source: String(row.source_type) as ResourceImportDraft["source"],
    category: String(row.category) as ResourceImportDraft["category"],
    platformContentType: String(row.content_type) as ResourceImportDraft["platformContentType"],
    title: String(row.title ?? ""),
    canonicalURL: String(row.canonical_url ?? ""),
    originalURL: String(row.original_url ?? ""),
    externalID: String(row.external_id ?? ""),
    authorName: String(row.author_name ?? ""),
    thumbnailURL: String(row.thumbnail_url ?? ""),
    publishedAt: row.published_at ? String(row.published_at) : null,
    descriptionText: String(row.description_text ?? ""),
    tags: Array.isArray(row.tags) ? row.tags.map(String) : [],
    importStatus: String(row.import_status ?? "partial") as ResourceImportDraft["importStatus"],
    metadataConfidence: Number(row.metadata_confidence ?? 0),
    importedAt: row.created_at ? String(row.created_at) : null,
    rawMetadataSnapshot: typeof row.raw_metadata_snapshot === "string"
      ? row.raw_metadata_snapshot
      : JSON.stringify(row.raw_metadata_snapshot ?? {}),
    mediaRetentionPolicy: String(row.media_retention_policy ?? "metadataOnly") as ResourceImportDraft["mediaRetentionPolicy"],
    mediaAssets: [],
    temporaryMediaLeases: [],
    sourcePayloadSummary: null,
    analysisStatus: "analyzing",
    aiAnalysis: null,
    recommendationCards: [],
    syncStatus: "pending",
    remoteRecordID: String(row.id),
    lastSyncedAt: row.updated_at ? String(row.updated_at) : null,
    lastErrorMessage: null,
  };
}
