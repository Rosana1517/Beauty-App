import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import type { NotionQARequest, NotionQAResponse } from "../_shared/types.ts";
import { extractKeyword } from "./keyword.ts";
import { searchNotes } from "./notion.ts";
import { generateAnswer, type ChatTurn } from "./llm.ts";
import { mirrorImages } from "./media.ts";

const MAX_MESSAGE_LENGTH = 1000;
/** 帶進 LLM 的對話輪數上限（由 App 端傳來），避免 prompt 無限膨脹 */
const MAX_HISTORY_TURNS = 6;
/** 整個流程的逾時；實測 Notion + LLM 約 3~6 秒，留足餘裕但別讓 App 空等太久 */
const OVERALL_TIMEOUT_MS = 60_000;

const FALLBACK_TEXT = "抱歉，這次查詢沒有成功，請再問一次或換個關鍵字。";

/**
 * 美妝知識問答：直接在 Edge Function 裡做 RAG（查 Notion → 組 context → 呼叫 LLM）。
 *
 * 這裡是唯一持有 Notion token 與 LLM 金鑰的地方，全部從 Supabase secrets 讀取。
 * App 端只帶使用者自己的登入 JWT，拿不到也不需要這些金鑰。
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    try {
      await resolveAuthenticatedUserID(req);
    } catch {
      // 驗證失敗屬於 client 端問題，要回 401；不要掉到最下面的 catch 變成 500，
      // 否則 App 會顯示「伺服器錯誤」而不是提示使用者重新登入。
      return jsonResponse({ error: "請先登入雲端同步帳號。" }, 401);
    }

    const notionToken = Deno.env.get("NOTION_TOKEN") ?? "";
    const notionDatabaseId = Deno.env.get("NOTION_DATABASE_ID") ?? "";
    const llmApiBase = Deno.env.get("LLM_API_BASE") ?? "";
    const llmApiKey = Deno.env.get("LLM_API_KEY") ?? "";
    const llmModel = Deno.env.get("LLM_MODEL") ?? "";

    const missing = [
      ["NOTION_TOKEN", notionToken],
      ["NOTION_DATABASE_ID", notionDatabaseId],
      ["LLM_API_BASE", llmApiBase],
      ["LLM_API_KEY", llmApiKey],
      ["LLM_MODEL", llmModel],
    ].filter(([, v]) => !v).map(([k]) => k);

    if (missing.length > 0) {
      // 只列出「哪些變數沒設」，不會洩漏任何已設定的值
      console.error("notion-qa missing secrets:", missing.join(", "));
      return jsonResponse({ error: `伺服器尚未完成設定（缺少 ${missing.join("、")}）。` }, 500);
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

    // App 端把最近幾輪對話一起帶上來，取代先前 n8n 的記憶節點。
    // 這樣 Edge Function 保持無狀態，也不用另外開資料表存對話。
    const history: ChatTurn[] = Array.isArray(payload?.history)
      ? payload.history
        .filter((t) =>
          t && (t.role === "user" || t.role === "assistant") && typeof t.text === "string" && t.text.trim()
        )
        .slice(-MAX_HISTORY_TURNS)
        .map((t) => ({ role: t.role, text: t.text.trim() }))
      : [];

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), OVERALL_TIMEOUT_MS);

    try {
      const keyword = extractKeyword(message);
      const retrieval = await searchNotes(notionToken, notionDatabaseId, keyword, controller.signal);

      // 圖片鏡像跟產生答案沒有相依，並行做才不會把延遲疊上去。
      // 鏡像失敗只退回原始 Notion 網址，不影響文字回答。
      const [answer, images] = await Promise.all([
        generateAnswer({
          apiBase: llmApiBase,
          apiKey: llmApiKey,
          model: llmModel,
          question: message,
          keyword,
          noteCount: retrieval.notes.length,
          contextText: retrieval.contextText,
          history,
          signal: controller.signal,
        }),
        mirrorImages(retrieval.images).catch(() => retrieval.images),
      ]);

      const response: NotionQAResponse = {
        text: answer || FALLBACK_TEXT,
        images,
        source_url: retrieval.sourceUrl,
        session_id: sessionId,
      };
      return jsonResponse(response);
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        return jsonResponse({ error: "查詢逾時，請稍後再試。" }, 504);
      }
      if (error instanceof Error && error.message === "NOTION_QUERY_FAILED") {
        return jsonResponse({ error: "知識庫暫時無法查詢，請稍後再試。" }, 502);
      }
      if (error instanceof Error && error.message === "LLM_REQUEST_FAILED") {
        return jsonResponse({ error: "AI 服務暫時無法回應，請稍後再試。" }, 502);
      }
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  } catch (error) {
    // 不要把原始錯誤訊息回給 client：可能夾帶內部細節。細節只留在伺服器 log。
    console.error("notion-qa unexpected error:", error instanceof Error ? error.message : error);
    return jsonResponse({ error: "發生未預期的錯誤，請稍後再試。" }, 500);
  }
});
