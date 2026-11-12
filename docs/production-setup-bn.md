# Salsabil Global Academy — Production backend setup (বাংলা)

## বর্তমান অবস্থা
- Public website: static `index.html`; admin preview: static `admin.html`.
- Admin preview-এর student/teacher/notice data শুধু browser Local Storage-এ থাকে।
- এই migration এখনো কোনো database-এ চালানো হয়নি। Login, live database, file storage বা role assignment সক্রিয় নয়।
- বাস্তব শিক্ষার্থীর ব্যক্তিগত তথ্য production backend যাচাই শেষ না হওয়া পর্যন্ত demo panel-এ দেবেন না।

## প্রস্তাবিত architecture
- PostgreSQL database + Supabase Auth; role: `admin`, `teacher`, `parent`.
- Row Level Security (RLS) দিয়ে প্রতিটি query-তে access সীমাবদ্ধ।
- Next.js App Router server-side routes/actions দিয়ে sensitive কাজ; client-এ কখনো service-role key নয়।
- Student documents/photos-এর জন্য private Storage bucket এবং আলাদা storage policies।
- Production ও Preview-এর credentials আলাদা রাখুন।

## Setup steps
1. Supabase-এ নতুন project তৈরি/নির্বাচন করুন (region/data residency ও backup plan যাচাই করে)।
2. Supabase SQL Editor বা Supabase CLI দিয়ে `supabase/migrations/202611120001_initial_school_management.sql` চালান।
3. Supabase Auth-এ Email provider চালু করুন; public sign-up বন্ধ রাখুন অথবা invite-only flow ব্যবহার করুন।
4. প্রতিষ্ঠানের অনুমোদিত প্রথম admin-এর Auth user dashboard থেকে তৈরি করুন। তারপর SQL Editor-এ তার Auth UUID বসিয়ে নিচের query চালান:
   ```sql
   insert into public.user_roles (user_id, role)
   values ('<ADMIN_AUTH_USER_UUID>', 'admin');
   ```
   UUID কোনো public client code-এ রাখবেন না। Admin user-এর email/password এই repository-তে commit করবেন না।
5. Teacher/parent accounts শুধু admin invitation workflow দিয়ে তৈরি করুন। Parent account-কে শুধু তার সন্তানের row-তে `student_guardians` mapping দিন। Teacher-কে অনুমোদিত class-এ `teacher_assignments` দিন।
6. Vercel project-এ environment variables যোগ করুন (Production/Preview আলাদা):
   - `NEXT_PUBLIC_SUPABASE_URL` — Supabase project URL.
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` — publishable/anon key; RLS বাধ্যতামূলক।
   - `SUPABASE_SERVICE_ROLE_KEY` — **শুধু server-side**, প্রয়োজন ছাড়া ব্যবহার করবেন না; কখনো `NEXT_PUBLIC_` prefix নয়।
   - `DATABASE_URL` — optional direct Postgres connection string, migration tooling-এর জন্য; server-side secret.
7. এই repository এখনো static HTML; environment variables যোগ করলেই login চালু হবে না। Next.js app structure, Supabase SSR auth client, protected server routes, session refresh/proxy এবং admin/teacher/parent UI integration তৈরি ও পরীক্ষা করতে হবে।
8. Admission form-এর personal data anon insert policy দিয়ে সরাসরি table-এ দেবেন না। Server endpoint-এ validation, spam/rate limit, file size/type checks এবং private storage policy তৈরি করুন।
9. Backup/PITR, retention, audit logging, MFA for admins, password reset, session expiry, privacy notice এবং incident recovery যাচাই করুন।

## RLS access outline
- Admin: all management tables.
- Teacher: assigned classes only; attendance entry; assigned class exam/marks workflow needs a later explicit write policy before enabling marks entry.
- Parent: linked child profile, attendance, published results and invoices/payments only.
- Public: published notices only. Admission submissions are intentionally not public at the database table layer.

## Before production launch
- [ ] Supabase project connected and migration applied successfully.
- [ ] First admin invited and role assigned manually; no default password in code.
- [ ] Test admin/teacher/parent with separate test accounts and synthetic records.
- [ ] Verify parent A cannot read parent B's children or fee/result rows.
- [ ] Verify teacher cannot access unassigned classes.
- [ ] Verify anon cannot read student/finance/application tables.
- [ ] Add secure server-side admission endpoint and private Storage policies.
- [ ] Integrate Next.js SSR auth and role guards; remove Local Storage demo writes from production admin.
- [ ] Configure Vercel env vars and redeploy; confirm routes and logs.
- [ ] Enable backups and admin MFA.

## Important
This migration is a foundation, not a complete SIS. Apply it first in a disposable development Supabase project and review RLS policies with a qualified developer before real student data or financial records are entered.
