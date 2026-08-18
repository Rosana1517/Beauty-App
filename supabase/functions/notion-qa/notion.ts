// 直接呼叫 Notion API 查小紅書筆記，並把結果整理成給 LLM 的 context。
//
// 這裡刻意不依賴 LLM 產生 images / sourceUrl —— 這兩個欄位由程式從真實資料抽出，
// 才能保證正確（先前讓模型自己填，常常漏欄位或把陣列輸出成字串）。

const NOTION_VERSION = "2022-06-28";

/** 只保留這些分類的筆記。資料庫裡「养身」有簡繁兩種寫法，兩個都要列。 */
const ALLOWED_CATEGORIES = ["美容", "健身", "养身", "養身", "變美", "变美"];

/** 過濾後最多給 LLM 幾筆 */
const MAX_NOTES = 3;
/** 跟 Notion 要幾筆。要比 MAX_NOTES 大，才有餘裕在丟掉非美妝筆記後仍湊得到內容。 */
const FETCH_SIZE = 8;

export interface RetrievedNote {
  title: string;
  url: string;
  lines: string[];
  images: string[];
}

export interface RetrievalResult {
  notes: RetrievedNote[];
  contextText: string;
  images: string[];
  sourceUrl: string;
  fetchedCount: number;
  droppedByCategory: number;
}

// deno-lint-ignore no-explicit-any
type NotionProp = any;

function textOf(prop: NotionProp): string {
  if (!prop) return "";
  if (Array.isArray(prop.title)) return prop.title.map((t: NotionProp) => t.plain_text ?? "").join("");
  if (Array.isArray(prop.rich_text)) return prop.rich_text.map((t: NotionProp) => t.plain_text ?? "").join("");
  if (Array.isArray(prop.multi_select)) return prop.multi_select.map((s: NotionProp) => s.name).join("、");
  if (prop.select?.name) return prop.select.name;
  if (prop.type === "url") return prop.url ?? "";
  if (prop.type === "date" && prop.date) return prop.date.start ?? "";
  return "";
}

function filesOf(prop: NotionProp): string[] {
  if (!prop || !Array.isArray(prop.files)) return [];
  return prop.files
    .map((f: NotionProp) => f.file?.url ?? f.external?.url ?? "")
    .filter((u: string) => !!u);
}

/** 找出「分類」欄位的值；欄位改名時退而用第一個 multi_select 型別的欄位 */
function categoryOf(props: Record<string, NotionProp>): string {
  if (props["分類"]) return textOf(props["分類"]);
  for (const prop of Object.values(props)) {
    if (Array.isArray(prop?.multi_select)) return textOf(prop);
  }
  return "";
}

/**
 * 用關鍵字查 Notion 資料庫（標題 OR 摘要 命中），再用分類白名單過濾。
 *
 * 分類這一層放在程式裡而不是 Notion filter，是因為要的語意是
 * 「(標題 OR 摘要) AND 分類」，用單一 filter 物件表達會複雜且容易寫錯。
 */
export async function searchNotes(
  token: string,
  databaseId: string,
  keyword: string,
  signal: AbortSignal,
): Promise<RetrievalResult> {
  const empty: RetrievalResult = {
    notes: [],
    contextText: "（查無筆記）",
    images: [],
    sourceUrl: "",
    fetchedCount: 0,
    droppedByCategory: 0,
  };

  if (!keyword) return empty;

  const res = await fetch(`https://api.notion.com/v1/databases/${databaseId}/query`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Notion-Version": NOTION_VERSION,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      page_size: FETCH_SIZE,
      filter: {
        or: [
          { property: "標題", title: { contains: keyword } },
          { property: "摘要", rich_text: { contains: keyword } },
        ],
      },
    }),
    signal,
  });

  if (!res.ok) {
    // 不要把 Notion 的原始回應塞進 log 或錯誤訊息，避免夾帶 token 或內部細節
    console.error("Notion query failed with status", res.status);
    throw new Error("NOTION_QUERY_FAILED");
  }

  const data = await res.json();
  const rows: NotionProp[] = Array.isArray(data?.results) ? data.results : [];

  // 分類白名單；完全讀不到分類欄位時保留（寧可多給，不要因欄位改名就全刪）
  const kept = rows.filter((row) => {
    const cat = categoryOf(row.properties ?? {});
    if (!cat) return true;
    return ALLOWED_CATEGORIES.some((c) => cat.includes(c));
  });

  const used = kept.slice(0, MAX_NOTES);
  const images: string[] = [];
  const notes: RetrievedNote[] = [];

  for (const row of used) {
    const props: Record<string, NotionProp> = row.properties ?? {};
    const lines: string[] = [];
    const noteImages: string[] = [];
    let title = "";

    for (const [name, prop] of Object.entries(props)) {
      const v = textOf(prop);
      if (v) {
        lines.push(`${name}：${v}`);
        if (Array.isArray(prop?.title) && !title) title = v;
      }
      for (const url of filesOf(prop)) {
        noteImages.push(url);
        if (images.length < 3) images.push(url);
      }
    }

    if (row.url) lines.push(`Notion 連結：${row.url}`);
    notes.push({ title, url: row.url ?? "", lines, images: noteImages });
  }

  const contextText = notes.length > 0
    ? notes.map((n, i) => `【筆記 ${i + 1}】\n${n.lines.join("\n")}`).join("\n\n")
    : "（查無筆記）";

  return {
    notes,
    contextText,
    images,
    sourceUrl: notes[0]?.url ?? "",
    fetchedCount: rows.length,
    droppedByCategory: rows.length - kept.length,
  };
}
