import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "শুধু POST অনুরোধ গ্রহণযোগ্য।" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) return json({ error: "সার্ভারের Supabase service role configuration পাওয়া যায়নি।" }, 500);

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "Admin লগইন প্রয়োজন।" }, 401);

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData.user) return json({ error: "Admin session যাচাই করা যায়নি।" }, 401);

  const { data: adminRole, error: roleError } = await callerClient
    .from("user_roles")
    .select("role")
    .eq("user_id", callerData.user.id)
    .eq("role", "admin")
    .maybeSingle();
  if (roleError || !adminRole) return json({ error: "শুধু অনুমোদিত Admin অ্যাকাউন্ট আইডি তৈরি করতে পারবে।" }, 403);

  let input: Record<string, unknown>;
  try { input = await req.json(); } catch { return json({ error: "সঠিক তথ্য পাঠানো হয়নি।" }, 400); }

  const role = String(input.role || "");
  const fullName = String(input.full_name || "").trim();
  const email = String(input.email || "").trim().toLowerCase();
  const password = String(input.password || "");
  const phone = String(input.phone || "").trim() || null;
  const classId = String(input.class_id || "");
  const studentId = String(input.student_id || "");

  if (!["teacher", "parent"].includes(role)) return json({ error: "শুধু শিক্ষক বা অভিভাবক অ্যাকাউন্ট তৈরি করা যাবে।" }, 400);
  if (!fullName || fullName.length > 120) return json({ error: "নাম লিখুন (সর্বোচ্চ ১২০ অক্ষর)।" }, 400);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "সঠিক ইমেইল ঠিকানা লিখুন।" }, 400);
  if (password.length < 8 || password.length > 72) return json({ error: "পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।" }, 400);
  if (role === "teacher" && !classId) return json({ error: "শিক্ষকের দায়িত্বপ্রাপ্ত শ্রেণি নির্বাচন করুন।" }, 400);
  if (role === "parent" && !studentId) return json({ error: "যে শিক্ষার্থীর অভিভাবক, তাকে নির্বাচন করুন।" }, 400);

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (role === "teacher") {
    const { data: cls, error } = await adminClient.from("academic_classes").select("id").eq("id", classId).eq("is_active", true).maybeSingle();
    if (error || !cls) return json({ error: "নির্বাচিত শ্রেণি পাওয়া যায়নি।" }, 400);
  } else {
    const { data: student, error } = await adminClient.from("students").select("id").eq("id", studentId).maybeSingle();
    if (error || !student) return json({ error: "নির্বাচিত শিক্ষার্থী পাওয়া যায়নি।" }, 400);
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, phone: phone || "" },
  });
  if (createError || !created.user) {
    return json({ error: createError?.message || "নতুন Auth user তৈরি করা যায়নি।" }, 400);
  }

  const userId = created.user.id;
  const cleanup = async () => { await adminClient.auth.admin.deleteUser(userId); };

  const { error: roleInsertError } = await adminClient.from("user_roles").insert({ user_id: userId, role });
  if (roleInsertError) {
    await cleanup();
    return json({ error: "অ্যাকাউন্টের অনুমতি সংরক্ষণ হয়নি: " + roleInsertError.message }, 500);
  }

  if (phone) {
    const { error } = await adminClient.from("profiles").update({ full_name: fullName, phone }).eq("id", userId);
    if (error) {
      await cleanup();
      return json({ error: "প্রোফাইল সংরক্ষণ হয়নি: " + error.message }, 500);
    }
  }

  const linkResult = role === "teacher"
    ? await adminClient.from("teacher_assignments").insert({ teacher_user_id: userId, class_id: classId })
    : await adminClient.from("student_guardians").insert({ user_id: userId, student_id: studentId, relationship: "guardian", is_primary: true });

  if (linkResult.error) {
    await cleanup();
    return json({ error: "অ্যাকাউন্ট তৈরি হলেও শ্রেণি/শিক্ষার্থীর সঙ্গে যুক্ত করা যায়নি: " + linkResult.error.message }, 500);
  }

  return json({
    success: true,
    user_id: userId,
    email,
    role,
    message: "লগইন অ্যাকাউন্ট তৈরি ও সংযুক্ত হয়েছে।",
  });
});
