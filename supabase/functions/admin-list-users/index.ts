import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedOrigins = new Set([
  "https://salsabil-global-academy.vercel.app",
  "https://salsabil-global-academy-sgaglobal26-2083.vercel.app",
  "https://salsabil-global-academy-git-main-sgaglobal26-2083.vercel.app",
  "https://salsabil-global-academy-5d5vtgrw9-sgaglobal26-2083.vercel.app",
]);

function corsHeaders(req: Request) {
  const origin = req.headers.get("Origin");
  return {
    ...(origin && allowedOrigins.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "600",
  };
}

function json(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  if (origin && !allowedOrigins.has(origin)) {
    return json(req, { error: "এই ওয়েবসাইট থেকে অনুরোধ গ্রহণ করা হচ্ছে না।" }, 403);
  }
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "শুধু POST অনুরোধ গ্রহণযোগ্য।" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(req, { error: "সার্ভারের Supabase configuration অসম্পূর্ণ।" }, 500);
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(req, { error: "Admin লগইন প্রয়োজন।" }, 401);

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData.user) return json(req, { error: "Admin session যাচাই করা যায়নি।" }, 401);

  const { data: adminRole, error: roleError } = await callerClient
    .from("user_roles")
    .select("role")
    .eq("user_id", callerData.user.id)
    .eq("role", "admin")
    .maybeSingle();
  if (roleError || !adminRole) return json(req, { error: "শুধু অনুমোদিত Admin এই তালিকা দেখতে পারবেন।" }, 403);

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const authUsers = [];
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) return json(req, { error: "Auth user তালিকা আনা যায়নি: " + error.message }, 500);
    const batch = data?.users || [];
    authUsers.push(...batch);
    if (batch.length < 1000) break;
  }

  const userIds = authUsers.map((user) => user.id);
  if (!userIds.length) return json(req, { users: [] });

  const [{ data: roles, error: rolesError }, { data: profiles, error: profilesError }] = await Promise.all([
    adminClient.from("user_roles").select("user_id,role").in("user_id", userIds),
    adminClient.from("profiles").select("id,full_name,phone").in("id", userIds),
  ]);
  if (rolesError) return json(req, { error: "অ্যাকাউন্টের role পড়া যায়নি: " + rolesError.message }, 500);
  if (profilesError) return json(req, { error: "প্রোফাইল পড়া যায়নি: " + profilesError.message }, 500);

  const roleById = new Map((roles || []).map((row) => [row.user_id, row.role]));
  const profileById = new Map((profiles || []).map((row) => [row.id, row]));

  const users = authUsers
    .filter((user) => ["teacher", "parent"].includes(roleById.get(user.id)))
    .map((user) => {
      const profile = profileById.get(user.id) || {};
      return {
        id: user.id,
        full_name: profile.full_name || user.user_metadata?.full_name || "",
        email: user.email || null,
        phone: user.phone || profile.phone || null,
        role: roleById.get(user.id),
        created_at: user.created_at || null,
        banned_until: user.banned_until || null,
      };
    })
    .sort((a, b) => String(b.created_at || "").localeCompare(String(a.created_at || "")));

  return json(req, { users });
});
