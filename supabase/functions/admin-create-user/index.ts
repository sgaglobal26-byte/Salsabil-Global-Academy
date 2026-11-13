import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedOrigins = new Set([
  "https://salsabil-global-academy.vercel.app",
  "https://salsabil-global-academy-sgaglobal26-2083.vercel.app",
  "https://salsabil-global-academy-git-main-sgaglobal26-2083.vercel.app",
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

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  if (origin && !allowedOrigins.has(origin)) {
    return json(req, { error: "এই ওয়েবসাইট থেকে অনুরোধ গ্রহণ করা হচ্ছে না।" }, 403);
  }

  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "শুধু POST অনুরোধ গ্রহণযোগ্য।" }, 405);

  const contentLength = Number(req.headers.get("Content-Length") || "0");
  if (contentLength > 16_384) return json(req, { error: "অনুরোধের তথ্য নির্ধারিত সীমার বেশি।" }, 413);

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
  if (roleError || !adminRole) return json(req, { error: "শুধু অনুমোদিত Admin অ্যাকাউন্ট আইডি তৈরি করতে পারবে।" }, 403);

  let input: Record<string, unknown>;
  try { input = await req.json(); } catch { return json(req, { error: "সঠিক তথ্য পাঠানো হয়নি।" }, 400); }

  const role = String(input.role || "");
  const fullName = String(input.full_name || "").trim();
  const email = String(input.email || "").trim().toLowerCase();
  const password = String(input.password || "");
  const phone = String(input.phone || "").trim() || null;
  const classId = String(input.class_id || "");
  const section = String(input.section || "").trim() || null;
  const studentId = String(input.student_id || "");

  if (!["teacher", "parent"].includes(role)) return json(req, { error: "শুধু শিক্ষক বা অভিভাবক অ্যাকাউন্ট তৈরি করা যাবে।" }, 400);
  if (!fullName || fullName.length > 120) return json(req, { error: "নাম লিখুন (সর্বোচ্চ ১২০ অক্ষর)।" }, 400);
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json(req, { error: "সঠিক ইমেইল ঠিকানা লিখুন।" }, 400);
  if (password.length < 8 || password.length > 72) return json(req, { error: "পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।" }, 400);
  if (phone && phone.length > 32) return json(req, { error: "মোবাইল নম্বরের দৈর্ঘ্য সঠিক নয়।" }, 400);
  if (role === "teacher" && (!uuidPattern.test(classId) || (section && section.length > 80))) return json(req, { error: "শ্রেণি বা সেকশনের তথ্য সঠিক নয়।" }, 400);
  if (role === "parent" && !uuidPattern.test(studentId)) return json(req, { error: "শিক্ষার্থীর তথ্য সঠিক নয়।" }, 400);

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (role === "teacher") {
    const { data: cls, error } = await adminClient.from("academic_classes").select("id").eq("id", classId).eq("is_active", true).maybeSingle();
    if (error || !cls) return json(req, { error: "নির্বাচিত শ্রেণি পাওয়া যায়নি।" }, 400);
  } else {
    const { data: student, error } = await adminClient.from("students").select("id").eq("id", studentId).maybeSingle();
    if (error || !student) return json(req, { error: "নির্বাচিত শিক্ষার্থী পাওয়া যায়নি।" }, 400);
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, phone: phone || "" },
  });
  if (createError || !created.user) {
    return json(req, { error: createError?.message || "নতুন Auth user তৈরি করা যায়নি।" }, 400);
  }

  const userId = created.user.id;
  const cleanup = async () => { await adminClient.auth.admin.deleteUser(userId); };

  const { error: roleInsertError } = await adminClient.from("user_roles").insert({ user_id: userId, role });
  if (roleInsertError) {
    await cleanup();
    return json(req, { error: "অ্যাকাউন্টের অনুমতি সংরক্ষণ হয়নি: " + roleInsertError.message }, 500);
  }

  const { error: profileError } = await adminClient.from("profiles")
    .update({ full_name: fullName, phone })
    .eq("id", userId);
  if (profileError) {
    await cleanup();
    return json(req, { error: "প্রোফাইল সংরক্ষণ হয়নি: " + profileError.message }, 500);
  }

  const linkResult = role === "teacher"
    ? await adminClient.from("teacher_assignments").insert({ teacher_user_id: userId, class_id: classId, section })
    : await adminClient.from("student_guardians").insert({ user_id: userId, student_id: studentId, relationship: "guardian", is_primary: true });

  if (linkResult.error) {
    await cleanup();
    return json(req, { error: "অ্যাকাউন্ট তৈরি হলেও শ্রেণি/শিক্ষার্থীর সঙ্গে যুক্ত করা যায়নি: " + linkResult.error.message }, 500);
  }

  return json(req, {
    success: true,
    user_id: userId,
    email,
    role,
    message: "লগইন অ্যাকাউন্ট তৈরি ও সংযুক্ত হয়েছে।",
  });
});
