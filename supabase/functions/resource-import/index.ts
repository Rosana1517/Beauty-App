import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { parseImportRequest } from "../_shared/metadata.ts";
import { resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { AuthorizedImportRequest } from "../_shared/types.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as AuthorizedImportRequest;
    if (!payload?.url || !payload?.source) {
      return jsonResponse({ error: "Missing source or url." }, 400);
    }

    const parsed = await parseImportRequest(payload);
    return jsonResponse(parsed);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected import error." },
      500,
    );
  }
});
