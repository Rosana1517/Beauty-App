import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { requestProductLookup } from "../_shared/aiProvider.ts";
import { resolveAuthenticatedUserID } from "../_shared/runtime.ts";

interface ProductLookupRequest {
  name?: string;
  imageBase64?: string;
}

interface ProductLookupResponse {
  name: string;
  brand: string;
  category: string;
  notes: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as ProductLookupRequest;
    const name = typeof payload?.name === "string" ? payload.name.trim() : undefined;
    const imageBase64 = typeof payload?.imageBase64 === "string" ? payload.imageBase64.trim() : undefined;

    if (!name && !imageBase64) {
      return jsonResponse({ error: "請提供產品名稱或照片。" }, 400);
    }

    const result = await requestProductLookup(name, imageBase64, userID);
    if (!result) {
      return jsonResponse(
        { error: "尚未設定 AI 提供者，請先到「個人設定」的「AI 解析設定」填入 OpenAI 或 Anthropic 的 API Key。" },
        422,
      );
    }

    const response: ProductLookupResponse = result;
    return jsonResponse(response);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected product lookup error." },
      500,
    );
  }
});
