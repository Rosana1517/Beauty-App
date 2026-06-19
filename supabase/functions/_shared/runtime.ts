import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export function createAdminClient() {
  const supabaseURL = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseURL || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
  }

  return createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function resolveAuthenticatedUserID(req: Request): Promise<string> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "").trim() ?? "";
  if (!token) {
    throw new Error("Missing bearer token.");
  }

  const client = createAdminClient();
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new Error("Unable to resolve authenticated user.");
  }
  return data.user.id;
}
