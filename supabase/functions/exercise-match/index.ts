import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { matchExercisesFromCatalog } from "../_shared/aiProvider.ts";
import type { ExerciseMatchCandidate } from "../_shared/aiProvider.ts";
import { createAdminClient, resolveAuthenticatedUserID } from "../_shared/runtime.ts";

/**
 * 需求文字 → body_part_zh 的關鍵字對照。命中的部位會作為候選動作的
 * 預篩條件,避免把全庫 1,372 筆都塞進 LLM prompt。
 */
const BODY_PART_KEYWORDS: [string, string[]][] = [
  ["腰腹", ["腹", "肚", "核心", "腰", "馬甲線", "川字"]],
  ["大腿", ["大腿", "瘦腿", "腿部", "臀", "胯", "下半身", "深蹲"]],
  ["小腿", ["小腿", "蘿蔔腿"]],
  ["背部", ["背", "駝背", "引體"]],
  ["胸部", ["胸", "副乳"]],
  ["肩部", ["肩", "斜方", "圓肩", "脖子前傾"]],
  ["上臂", ["手臂", "掰掰袖", "蝴蝶袖", "二頭", "三頭"]],
  ["前臂", ["前臂", "手腕"]],
  ["心肺", ["有氧", "心肺", "燃脂", "減脂", "瘦身", "體能", "耐力", "減肥"]],
  ["頸部", ["頸", "落枕"]],
];

const YOGA_KEYWORDS = ["瑜伽", "瑜珈", "拉伸", "伸展", "放鬆", "舒緩", "柔軟", "體式", "開肩", "開髖", "睡前", "冥想"];

/** 居家常見器材;沒點名器材時避免推薦大型器械動作 */
const HOME_EQUIPMENT = ["徒手", "啞鈴", "彈力帶", "阻力帶", "壺鈴", "抗力球", "滾筒", "健腹輪"];
const GYM_KEYWORDS = ["健身房", "器械", "槓鈴", "滑輪", "史密斯"];

function inferFilters(need: string): { bodyParts: string[]; wantsYoga: boolean; homeOnly: boolean } {
  const bodyParts = BODY_PART_KEYWORDS
    .filter(([, keywords]) => keywords.some((keyword) => need.includes(keyword)))
    .map(([part]) => part);
  const wantsYoga = YOGA_KEYWORDS.some((keyword) => need.includes(keyword));
  const homeOnly = !GYM_KEYWORDS.some((keyword) => need.includes(keyword));
  return { bodyParts, wantsYoga, homeOnly };
}

const CANDIDATE_SELECT = "id, name_zh, name_en, item_type, body_part_zh, equipment_zh, difficulty_zh, target_muscle";

interface CandidateRow {
  id: string;
  name_zh: string | null;
  name_en: string;
  item_type: string;
  body_part_zh: string | null;
  equipment_zh: string | null;
  difficulty_zh: string | null;
  target_muscle: string | null;
}

/** 候選少於此數時補進瑜伽體式,避免冷門部位只回傳 2-3 個動作 */
const THIN_POOL_THRESHOLD = 25;

async function fetchYogaPoses(supabase: ReturnType<typeof createAdminClient>): Promise<CandidateRow[]> {
  const { data } = await supabase
    .from("exercise_library")
    .select(CANDIDATE_SELECT)
    .eq("item_type", "yoga")
    .limit(48);
  return (data ?? []) as CandidateRow[];
}

async function fetchCandidates(need: string): Promise<CandidateRow[]> {
  const supabase = createAdminClient();
  const { bodyParts, wantsYoga, homeOnly } = inferFilters(need);
  const rows: CandidateRow[] = [];
  let yogaIncluded = false;

  // 瑜伽需求(或無明確部位)一律附上全部 48 個體式讓 LLM 挑
  if (wantsYoga || bodyParts.length === 0) {
    rows.push(...await fetchYogaPoses(supabase));
    yogaIncluded = true;
  }

  if (bodyParts.length > 0) {
    for (const part of bodyParts.slice(0, 3)) {
      let query = supabase
        .from("exercise_library")
        .select(CANDIDATE_SELECT)
        .eq("item_type", "strength")
        .eq("body_part_zh", part);
      if (homeOnly) {
        query = query.in("equipment_zh", HOME_EQUIPMENT);
      }
      const { data } = await query.limit(45);
      rows.push(...((data ?? []) as CandidateRow[]));
    }
  } else if (!wantsYoga) {
    // 完全推不出部位:各主要部位取常見居家動作,讓 LLM 自行組合
    for (const part of ["腰腹", "大腿", "背部", "肩部", "上臂"]) {
      const { data } = await supabase
        .from("exercise_library")
        .select(CANDIDATE_SELECT)
        .eq("item_type", "strength")
        .eq("body_part_zh", part)
        .in("equipment_zh", HOME_EQUIPMENT)
        .limit(18);
      rows.push(...((data ?? []) as CandidateRow[]));
    }
  }

  // 冷門部位(如「頸部」全庫僅 2 筆、「前臂」37 筆)過濾後候選過少,
  // LLM 湊不出承諾的 5-8 個動作。補進瑜伽伸展體式讓組合完整,
  // 對頸部/肩背這類需求本來就適合搭配伸展收尾。
  if (!yogaIncluded && rows.length < THIN_POOL_THRESHOLD) {
    rows.push(...await fetchYogaPoses(supabase));
  }

  return rows;
}

function toCandidate(row: CandidateRow): ExerciseMatchCandidate {
  const meta = [
    row.item_type === "yoga" ? "瑜伽" : "健身",
    row.body_part_zh,
    row.equipment_zh,
    row.difficulty_zh,
    row.target_muscle,
  ].filter(Boolean).join("/");
  return {
    id: row.id,
    name: row.name_zh?.trim() || row.name_en,
    meta,
  };
}

// ---------------------------------------------------------------------------
// 面部動作庫(face_exercise_library):變美 → 面部拉提/瑜珈 的 AI 匹配。
// 全庫僅數十筆,直接全量送入 LLM 挑選,不需部位預篩。
// ---------------------------------------------------------------------------

const FACE_TYPE_LABELS: Record<string, string> = {
  face_yoga: "面部瑜珈",
  face_massage: "面部按摩",
  face_training: "面部訓練",
};

interface FaceCandidateRow {
  id: string;
  name_zh: string | null;
  name_en: string;
  item_type: string;
  category_zh: string | null;
  target_area_zh: string[] | null;
  benefits_zh: string | null;
  tags: string[] | null;
}

async function fetchFaceCandidates(): Promise<FaceCandidateRow[]> {
  const supabase = createAdminClient();
  const { data } = await supabase
    .from("face_exercise_library")
    .select("id, name_zh, name_en, item_type, category_zh, target_area_zh, benefits_zh, tags")
    .limit(100);
  return (data ?? []) as FaceCandidateRow[];
}

function toFaceCandidate(row: FaceCandidateRow): ExerciseMatchCandidate {
  const meta = [
    FACE_TYPE_LABELS[row.item_type] ?? row.item_type,
    row.category_zh,
    (row.target_area_zh ?? []).join("·"),
    row.benefits_zh,
    (row.tags ?? []).join("·"),
  ].filter(Boolean).join("/");
  return {
    id: row.id,
    name: row.name_zh?.trim() || row.name_en,
    meta,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userID = await resolveAuthenticatedUserID(req);
    const payload = (await req.json()) as { need?: unknown; library?: unknown };
    const need = typeof payload?.need === "string" ? payload.need.trim() : "";
    if (!need) {
      return jsonResponse({ error: "請輸入想改善的部位或訓練需求。" }, 400);
    }
    const isFaceLibrary = payload?.library === "face";

    const candidates = isFaceLibrary
      ? (await fetchFaceCandidates()).map(toFaceCandidate)
      : (await fetchCandidates(need)).map(toCandidate);
    if (candidates.length === 0) {
      return jsonResponse({ error: "找不到可匹配的動作資料,請稍後再試。" }, 500);
    }

    const selections = await matchExercisesFromCatalog(
      need,
      candidates,
      userID,
    );
    if (!selections) {
      return jsonResponse(
        { error: "尚未設定 AI 提供者,請先到「個人設定」的「AI 解析設定」填入 OpenAI 或 Anthropic 的 API Key。" },
        422,
      );
    }

    // 取回完整欄位(含教學/圖片),讓 App 端直接沿用資料庫詳情頁
    const supabase = createAdminClient();
    const { data: fullRows } = await supabase
      .from(isFaceLibrary ? "face_exercise_library" : "exercise_library")
      .select("*")
      .in("id", selections.map((s) => s.id));

    const rowByID = new Map((fullRows ?? []).map((row: { id: string }) => [row.id, row]));
    const matches = selections
      .filter((s) => rowByID.has(s.id))
      .map((s) => ({ item: rowByID.get(s.id), reason: s.reason }));

    return jsonResponse({ matches });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected exercise match error." },
      500,
    );
  }
});
