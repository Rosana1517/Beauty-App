import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient, resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { ReparseJobRequest, SupabaseQueueJobResponse } from "../_shared/types.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as ReparseJobRequest;
    if (!payload?.resourceID || !payload?.reason) {
      return jsonResponse({ error: "Missing resourceID or reason." }, 400);
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

    const requestPayload = {
      reason: payload.reason,
      requested_at: new Date().toISOString(),
    };

    const { data: queueRow, error: queueError } = await supabase
      .from("resource_sync_queue")
      .insert({
        resource_id: resource.id,
        job_type: "reparse",
        sync_target: "supabase",
        sync_status: "pending",
        retry_count: 0,
        request_payload: requestPayload,
      })
      .select("id,sync_status,retry_count,last_error,created_at,updated_at")
      .single();

    if (queueError || !queueRow) {
      throw queueError ?? new Error("Unable to create reparse queue row.");
    }

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
      { error: error instanceof Error ? error.message : "Unexpected reparse error." },
      500,
    );
  }
});
