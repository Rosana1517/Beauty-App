import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { NotionQARequest, NotionQAResponse } from "../_shared/types.ts";

const MAX_MESSAGE_LENGTH = 1000;

// 轉發到自架 n8n 的 Notion 知識庫問答 workflow(webhook 節點掛 Header Auth）。
// 金鑰只存在 Edge Function 環境變數，不會出現在 App 端，避免 client 直接持有。
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    await resolveAuthenticatedUserID(req);

    const n8nURL = Deno.env.get("N8N_NOTION_QA_URL") ?? "";
    const n8nAPIKey = Deno.env.get("N8N_NOTION_QA_API_KEY") ?? "";
    if (!n8nURL || !n8nAPIKey) {
      return jsonResponse({ error: "尚未設定 N8N_NOTION_QA_URL 或 N8N_NOTION_QA_API_KEY。" }, 500);
    }

    const payload = (await req.json()) as NotionQARequest;
    const message = typeof payload?.message === "string" ? payload.message.trim() : "";
    const sessionId = typeof payload?.session_id === "string" && payload.session_id.trim()
      ? payload.session_id.trim()
      : crypto.randomUUID();

    if (!message) {
      return jsonResponse({ error: "message 不可為空。" }, 422);
    }
    if (message.length > MAX_MESSAGE_LENGTH) {
      return jsonResponse({ error: `message 過長，請控制在 ${MAX_MESSAGE_LENGTH} 字以內。` }, 422);
    }

    // App 端 invokeFunction 給 90 秒逾時，這裡抓短一點才能在那之前吐出明確錯誤訊息
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60_000);

    let n8nResponse: Response;
    try {
      n8nResponse = await fetch(n8nURL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": n8nAPIKey,
        },
        body: JSON.stringify({ message, sessionId }),
        signal: controller.signal,
      });
    } catch (error) {
      const timedOut = error instanceof DOMException && error.name === "AbortError";
      return jsonResponse(
        { error: timedOut ? "查詢逾時，請稍後再試。" : "無法連線到知識庫服務，請稍後再試。" },
        504,
      );
    } finally {
      clearTimeout(timeout);
    }

    if (!n8nResponse.ok) {
      console.error("n8n notion-qa webhook returned error status", n8nResponse.status);
      return jsonResponse({ error: "知識庫服務暫時無法回應，請稍後再試。" }, 502);
    }

    // n8n Respond to Webhook 回傳的是 { text, images, sourceUrl, sessionId }（camelCase）
    const raw = await n8nResponse.json();
    const response: NotionQAResponse = {
      text: typeof raw?.text === "string" ? raw.text : "",
      images: Array.isArray(raw?.images) ? raw.images.filter((url: unknown) => typeof url === "string") : [],
      source_url: typeof raw?.sourceUrl === "string" ? raw.sourceUrl : "",
      session_id: typeof raw?.sessionId === "string" ? raw.sessionId : sessionId,
    };
    return jsonResponse(response);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected notion-qa error." },
      500,
    );
  }
});
