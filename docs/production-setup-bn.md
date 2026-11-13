# সালসাবিল গ্লোবাল একাডেমি — Supabase ও Admin নিরাপত্তা সেটআপ

## বর্তমান প্রজেক্ট পর্যালোচনা
- GitHub repository: `sgaglobal26-byte/Salsabil-Global-Academy`
- Vercel project: `salsabil-global-academy`
- বর্তমান architecture: static HTML pages; repository-তে `package.json`/Next.js app নেই।
- Public site, Admin, Teacher ও Student/Guardian routes Vercel-এ HTTP 200 দিচ্ছে।
- Browser client-এ Supabase project reference এবং publishable key আছে। Publishable/anon key গোপন credential নয়; তবে সব table-এ RLS বাধ্যতামূলক। Service-role key কখনো browser code-এ রাখা যাবে না।
- Admin/Teacher/Parent sign-in বর্তমানে Supabase JS browser client দিয়ে হয়; এটি এখনো Next.js SSR/HttpOnly-cookie session নয়। Database RLS হলো আসল data boundary।
- Admin account তৈরি করার privileged কাজ Supabase Edge Function `admin-create-user`-এ করা হয়েছে; function JWT ও admin role যাচাই করে server-side service-role client ব্যবহার করে।
- Vercel project-এ বর্তমানে কোনো Environment Variable configured নেই। বর্তমান static client-এর public Supabase config HTML-এ আছে; ভবিষ্যৎ Vercel server-side API/SSR-এর জন্য server-only variables লাগবে।
- Supabase project ref source-এ `qzblmxcbgmdwkdmfsvuj` দেখা যাচ্ছে; Supabase Dashboard/CLI access ছাড়া database বা deployed function-এর অবস্থা নিশ্চিত করা যায়নি।

## Migration চালানোর ক্রম
Supabase SQL Editor-এ নিচের migration-গুলো ক্রমানুসারে চালান:
1. `supabase/migrations/202611120001_initial_school_management.sql`
2. `supabase/migrations/202611120002_student_guardian_contact.sql`
3. `supabase/migrations/202611130001_teacher_section_rls.sql`

তৃতীয় migration শিক্ষককে নির্দিষ্ট section-এ সীমাবদ্ধ করে। Teacher assignment-এর `section` ফাঁকা থাকলে সেই শিক্ষক পুরো class-এর দায়িত্বে থাকবেন; section দেওয়া থাকলে শুধু সেই section-এর student/attendance/result row দেখা যাবে। Migration প্রয়োগের আগে dev project-এ পরীক্ষা করুন।

## Edge Function deploy
Repository-তে function source: `supabase/functions/admin-create-user/index.ts`।
Supabase CLI ব্যবহার করে project link করার পর:
```bash
supabase link --project-ref qzblmxcbgmdwkdmfsvuj
supabase functions deploy admin-create-user
```
Supabase Edge Function environment-এ `SUPABASE_URL`, `SUPABASE_ANON_KEY` ও `SUPABASE_SERVICE_ROLE_KEY` উপস্থিত আছে কি না Dashboard থেকে নিশ্চিত করুন। Service-role key প্রয়োজন হলে Supabase secret হিসেবে সেট করুন; ChatGPT, GitHub, HTML বা Vercel public variable-এ paste করবেন না। `supabase/config.toml`-এ JWT verification চালু আছে।

## প্রথম Admin তৈরি
1. প্রতিষ্ঠানের অনুমোদিত Admin-এর Auth user Supabase Dashboard থেকে তৈরি করুন।
2. Auth user-এর UUID নিয়ে SQL Editor-এ চালান:
```sql
insert into public.user_roles (user_id, role)
values ('<ADMIN_AUTH_USER_UUID>', 'admin');
```
3. Admin login দিয়ে `user_roles` read এবং dashboard data access যাচাই করুন।
4. Teacher/Parent account কেবল Admin panel থেকে তৈরি করুন। Teacher-কে class/section এবং Parent-কে নির্দিষ্ট student-এর সঙ্গে যুক্ত করুন।

## নিরাপত্তা যাচাই — বাস্তব শিক্ষার্থীর তথ্য ছাড়া
- আলাদা synthetic Admin, Teacher ও Parent test account ব্যবহার করুন।
- Parent A যেন Parent B-এর student, attendance, result বা fee দেখতে না পারে।
- Section A-এর teacher যেন Section B-এর row পড়তে বা attendance লিখতে না পারে।
- Teacher যেন unassigned class-এর row পড়তে বা লিখতে না পারে।
- Anonymous user যেন student, role, fee, attendance বা admission application table পড়তে না পারে।
- Admin ছাড়া কেউ role assignment, admission review, fee বা student record পরিবর্তন করতে না পারে।
- Browser bundle/source-এ service-role key নেই নিশ্চিত করুন।
- Private Storage bucket, file type/size validation, backups, MFA ও audit log production launch-এর আগে configure করুন।

## এখনো বাকি / access blocker
- Supabase Dashboard/CLI project access এই development session-এ নেই; migration বাস্তব database-এ apply বা deployed function verify করা যায়নি।
- Supabase Edge Function deploy এবং service-role secret availability নিশ্চিত করতে হবে।
- First Admin Auth user ও `admin` role প্রতিষ্ঠানের অনুমোদিত ব্যক্তি নিজে তৈরি করবেন।
- পূর্ণ server-side session (Next.js SSR/HttpOnly cookie) এখনো নেই। বর্তমান static pages Supabase browser Auth + strict RLS ব্যবহার করে। এটিকে production SSR architecture-এ রূপান্তর আলাদা migration phase।
- Vercel environment variables এখনো শূন্য; SSR/API migration-এর আগে server-only Supabase URL/key configuration করতে হবে।

**বাস্তব student/guardian/teacher personal data দেবেন না যতক্ষণ migration, Edge Function, RLS isolation tests, private file storage এবং backup যাচাই সম্পন্ন না হয়।**
