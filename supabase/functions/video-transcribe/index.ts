import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { createAdminClient, resolveAuthenticatedUserID } from "../_shared/runtime.ts";
import { summarizeTranscriptAsSteps } from "../_shared/aiProvider.ts";

// Groq's free-tier Whisper upload limit; leave margin below the documented 25MB.
const MAX_VIDEO_BYTES = 24 * 1024 * 1024;
const STEP_MARKER = "📋 教學步驟";

interface TranscribeRequest {
  // Swift 端請求體用 JSONEncoder.keyEncodingStrategy = .convertToSnakeCase 編碼，
  // "resourceID" 會變成 "resource_id"（尾端的大寫縮寫視為一個詞），故此處收 snake_case。
  resource_id: string;
  video_url: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 由 app 在資源同步成功後即時觸發，仍要求登入態，避免被匿名濫用配額
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as TranscribeRequest;
    if (!payload?.resource_id || !payload?.video_url) {
      return jsonResponse({ error: "Missing resourceID or videoURL." }, 400);
    }

    const groqKey = (Deno.env.get("GROQ_API_KEY") ?? "").trim();
    if (!groqKey) {
      return jsonResponse({ error: "GROQ_API_KEY not configured; skipping transcription." }, 200);
    }

    const supabase = createAdminClient();

    // 已經有教學步驟的筆記不重複轉錄（例如使用者重新整理觸發二次同步）
    const { data: existing } = await supabase
      .from("resource_items")
      .select("description_text, title")
      .eq("id", payload.resource_id)
      .maybeSingle();
    if (existing?.description_text?.includes(STEP_MARKER)) {
      return jsonResponse({ skipped: true, reason: "already_transcribed" });
    }

    const videoResponse = await fetch(payload.video_url, {
      headers: {
        "Referer": "https://www.xiaohongshu.com/",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
    });
    if (!videoResponse.ok) {
      return jsonResponse({ error: `Video fetch failed: ${videoResponse.status}` }, 200);
    }

    const contentLength = Number(videoResponse.headers.get("content-length") ?? "0");
    if (contentLength > 0 && contentLength > MAX_VIDEO_BYTES) {
      await markFallback(supabase, payload.resource_id, "影片檔案過大（超過 24MB），暫無法自動轉錄教學步驟。");
      return jsonResponse({ skipped: true, reason: "video_too_large", sizeBytes: contentLength });
    }

    const videoBytes = new Uint8Array(await videoResponse.arrayBuffer());
    if (videoBytes.byteLength > MAX_VIDEO_BYTES) {
      await markFallback(supabase, payload.resource_id, "影片檔案過大（超過 24MB），暫無法自動轉錄教學步驟。");
      return jsonResponse({ skipped: true, reason: "video_too_large", sizeBytes: videoBytes.byteLength });
    }

    const transcript = await transcribeWithGroq(groqKey, videoBytes);
    if (!transcript || transcript.trim().length < 30) {
      return jsonResponse({ skipped: true, reason: "transcript_too_short" });
    }

    const steps = await summarizeTranscriptAsSteps(existing?.title ?? "", transcript, userID);
    if (steps.length === 0) {
      return jsonResponse({ skipped: true, reason: "no_steps_extracted" });
    }

    const stepText = steps.map((step, index) => `${index + 1}. ${step}`).join("\n");
    const currentDesc = (existing?.description_text ?? "").trim();
    const newDesc = (currentDesc ? `${currentDesc}\n\n` : "") + `${STEP_MARKER}：\n${stepText}`;

    await supabase
      .from("resource_items")
      .update({ description_text: newDesc, updated_at: new Date().toISOString() })
      .eq("id", payload.resource_id);

    await supabase.from("resource_analysis_results").insert({
      resource_id: payload.resource_id,
      provider: "groq-whisper+llm",
      status: "analyzed",
      summary: stepText,
      insights: [transcript.slice(0, 4000)],
      confidence: 0.8,
    });

    return jsonResponse({ ok: true, steps: steps.length });
  } catch (error) {
    console.error("video-transcribe failed", error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected transcription error." },
      200, // 轉錄失敗不應讓匯入流程視為錯誤，一律回 200 附錯誤說明
    );
  }
});

async function markFallback(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  resourceID: string,
  note: string,
) {
  await supabase.from("resource_analysis_results").insert({
    resource_id: resourceID,
    provider: "groq-whisper+llm",
    status: "fallback",
    summary: note,
    insights: [],
    confidence: 0,
  });
}

async function transcribeWithGroq(apiKey: string, videoBytes: Uint8Array): Promise<string> {
  const form = new FormData();
  form.append("model", "whisper-large-v3-turbo");
  form.append("language", "zh");
  form.append("response_format", "text");
  form.append("file", new Blob([videoBytes], { type: "video/mp4" }), "note.mp4");

  const response = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
    method: "POST",
    headers: { authorization: `Bearer ${apiKey}` },
    body: form,
  });
  if (!response.ok) {
    throw new Error(`Groq transcription failed: ${response.status} ${await response.text()}`);
  }
  return await response.text();
}
