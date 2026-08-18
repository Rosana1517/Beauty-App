// 把 Notion 的圖片鏡像到 Supabase Storage，換成長效簽章網址。
//
// Notion 回傳的是 AWS presigned URL（X-Amz-Expires=3600），一小時後就失效。
// 聊天訊息會存在 App 本機，隔天回看舊對話圖片就會破圖，所以在回應前先把圖片
// 複製一份到自己的 bucket。bucket 保持 private，只發簽章網址，避免整個知識庫
// 的圖片被人列舉。

import { createAdminClient } from "../_shared/runtime.ts";

const BUCKET = "notion-media";
/** 簽章網址有效期。聊天紀錄會長期留在 App 裡，所以給一年。 */
const SIGNED_URL_TTL_SECONDS = 60 * 60 * 24 * 365;
/** 單張圖片的下載逾時；超過就放棄鏡像，改用原始網址 */
const PER_IMAGE_TIMEOUT_MS = 10_000;
/** 單張圖片大小上限，跟 bucket 設定一致 */
const MAX_BYTES = 10 * 1024 * 1024;

const EXTENSION_BY_MIME: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
};

/**
 * 由圖片網址算出穩定的 object key。
 *
 * 只取 pathname（不含 query）做雜湊 —— Notion 每次查詢都會重新簽章，query 一直在變，
 * 但 pathname 裡的檔案 UUID 是固定的，這樣同一張圖才不會被重複上傳。
 */
async function objectKeyFor(url: string): Promise<string | null> {
  let pathname: string;
  try {
    pathname = new URL(url).pathname;
  } catch {
    return null;
  }

  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(pathname));
  const hex = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");

  const matched = pathname.toLowerCase().match(/\.(jpe?g|png|webp|gif)$/);
  const ext = matched ? (matched[1] === "jpeg" ? "jpg" : matched[1]) : "jpg";
  return `notes/${hex}.${ext}`;
}

// deno-lint-ignore no-explicit-any
async function signedUrl(storage: any, key: string): Promise<string> {
  const { data, error } = await storage.createSignedUrl(key, SIGNED_URL_TTL_SECONDS);
  if (error || !data?.signedUrl) return "";
  return data.signedUrl;
}

/** 下載原圖並上傳到 bucket；成功回傳 true */
// deno-lint-ignore no-explicit-any
async function upload(storage: any, key: string, sourceURL: string): Promise<boolean> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PER_IMAGE_TIMEOUT_MS);
  try {
    const res = await fetch(sourceURL, { signal: controller.signal });
    if (!res.ok) {
      console.error("mirror: source fetch failed with status", res.status);
      return false;
    }

    const contentType = (res.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
    if (!EXTENSION_BY_MIME[contentType]) {
      console.error("mirror: unsupported content-type", contentType);
      return false;
    }

    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.byteLength === 0 || bytes.byteLength > MAX_BYTES) {
      console.error("mirror: unexpected size", bytes.byteLength);
      return false;
    }

    // upsert:true —— 同一個 key 代表同一張圖，重跑時直接覆蓋比先查存在再寫簡單
    const { error } = await storage.upload(key, bytes, { contentType, upsert: true });
    if (error) {
      console.error("mirror: upload failed");
      return false;
    }
    return true;
  } catch (error) {
    console.error("mirror: upload aborted", error instanceof Error ? error.name : "unknown");
    return false;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * 把圖片網址逐一換成 Storage 的長效簽章網址。
 *
 * 任何一張失敗都只是退回原始 Notion 網址（當下一小時內仍可顯示），
 * 不會讓整個問答失敗 —— 圖片是附加價值，文字答案才是主體。
 */
export async function mirrorImages(urls: string[]): Promise<string[]> {
  if (urls.length === 0) return [];

  let storage;
  try {
    storage = createAdminClient().storage.from(BUCKET);
  } catch {
    console.error("mirror: admin client unavailable, keeping original URLs");
    return urls;
  }

  return await Promise.all(urls.map(async (url) => {
    const key = await objectKeyFor(url);
    if (!key) return url;

    // 先試簽章：圖片多半已經鏡像過，可以省掉一次下載＋上傳
    const existing = await signedUrl(storage, key);
    if (existing) return existing;

    if (!await upload(storage, key, url)) return url;
    return (await signedUrl(storage, key)) || url;
  }));
}
