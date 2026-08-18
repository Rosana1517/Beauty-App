// 呼叫 OpenAI 相容的 Chat Completions 端點產生回答。
//
// 只要求純文字輸出，不要求結構化 JSON —— 先前讓模型同時做工具呼叫與嚴格 JSON，
// 成功率只有三到五成；改成「模型只寫文字、其餘欄位由程式填」之後才穩定。

export interface ChatTurn {
  role: "user" | "assistant";
  text: string;
}

export const SYSTEM_PROMPT = `# 角色
你是「美麗日記」App 的美妝保養知識助理。使用者的問題，以及從 Notion 知識庫（內容整理自小紅書變美筆記）查到的筆記，都會一併給你。

# 回答規則
- 只根據提供的筆記內容回答，不要自行編造知識庫沒有的內容
- 筆記是簡體中文，請一律用繁體中文回答
- 語氣口語、簡潔，適合在手機聊天畫面閱讀；重點多的話用短編號清單
- 不要輸出 Notion 頁面 ID、欄位代碼等技術性內容
- 不需要自己貼圖片網址或來源連結，系統會另外附上

# 查無資料時
若筆記內容是「（查無筆記）」或明顯與問題無關：
- 誠實說知識庫目前沒有這個主題的筆記
- 依問題主題建議 2~3 個可能有收錄的替代關鍵字讓使用者再問
- 不要假裝有查到

# 追問
若使用者的問題是在追問前一輪的內容（例如「那第二個方法呢」「要做幾天」），
而這次附上的筆記與問題無關，請直接根據對話歷史回答。`;

export async function generateAnswer(
  opts: {
    apiBase: string;
    apiKey: string;
    model: string;
    question: string;
    keyword: string;
    noteCount: number;
    contextText: string;
    history: ChatTurn[];
    signal: AbortSignal;
  },
): Promise<string> {
  const { apiBase, apiKey, model, question, keyword, noteCount, contextText, history, signal } = opts;

  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    ...history.map((t) => ({ role: t.role, content: t.text })),
    {
      role: "user",
      content:
        `使用者問題：${question}\n\n` +
        `以下是用關鍵字「${keyword}」從知識庫查到的 ${noteCount} 筆筆記：\n\n${contextText}`,
    },
  ];

  const url = `${apiBase.replace(/\/+$/, "")}/chat/completions`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model, messages, temperature: 0.4 }),
    signal,
  });

  if (!res.ok) {
    // 只記狀態碼，不記 body：回應內容可能夾帶送出去的 prompt 或金鑰片段
    console.error("LLM request failed with status", res.status);
    throw new Error("LLM_REQUEST_FAILED");
  }

  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content;
  return typeof text === "string" ? text.trim() : "";
}
