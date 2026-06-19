import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient, resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { MediaCleanupJobRequest, SupabaseQueueJobResponse } from "../_shared/types.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as MediaCleanupJobRequest;
    if (!payload?.resourceID || !payload?.retentionPolicy) {
      return jsonResponse({ error: "Missing resourceID or retentionPolicy." }, 400);
    }

    const supabase = createAdminClient();
    const { data: resource, error: resourceError } = await supabase
      .from("resource_items")
      .select("id,user_id")
      .eq("id", payload.resourceID)
      .eq("user_id", userID)
      .single();

    if (resourceError || !resource) {
      return jsonResponse({ error: "Resource not found." }, 404);
    }

    const now = new Date().toISOString();
    const requestPayload = {
      retention_policy: payload.retentionPolicy,
      requested_at: now,
    };

    const { data: queueRow, error: queueError } = await supabase
      .from("resource_sync_queue")
      .insert({
        resource_id: resource.id,
        job_type: "media_cleanup",
        sync_target: "supabase",
        sync_status: "succeeded",
        retry_count: 0,
        request_payload: requestPayload,
      })
      .select("id,sync_status,retry_count,last_error,created_at,updated_at")
      .single();

    if (queueError || !queueRow) {
      throw queueError ?? new Error("Unable to create cleanup queue row.");
    }

    await supabase
      .from("temporary_media_leases")
      .update({
        cleaned_at: now,
        cleanup_status: "succeeded",
      })
      .eq("resource_id", resource.id)
      .is("cleaned_at", null);

    await supabase
      .from("resource_media_assets")
      .update({
        storage_path: null,
        expires_at: null,
      })
      .eq("resource_id", resource.id)
      .neq("retention_policy", "explicitKeep");

    const response: SupabaseQueueJobResponse = {
      id: queueRow.id,
      sync_status: queueRow.sync_status,
      retry_count: queueRow.retry_count,
      last_error: queueRow.last_error,
      created_at: queueRow.created_at,
      updated_at: queueRow.updated_at,
    };
    return jsonResponse(response);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected cleanup error." },
      500,
    );
  }
});
