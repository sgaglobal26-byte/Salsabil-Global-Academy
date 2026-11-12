-- Salsabil Global Academy: PostgreSQL foundation
-- Apply only after connecting the institution's Supabase project.
-- No real student records or demo users are created by this migration.

create extension if not exists pgcrypto;

do $$ begin
  create type public.sga_role as enum ('admin', 'teacher', 'parent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.student_status as enum ('active', 'inactive', 'graduated', 'transferred');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.attendance_status as enum ('present', 'absent', 'late', 'excused');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  preferred_language text not null default 'bn' check (preferred_language in ('bn','en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.sga_role not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table if not exists public.academic_classes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order integer not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  name_bn text not null,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (name_bn)
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  student_code text not null unique,
  full_name text not null,
  date_of_birth date,
  gender text check (gender in ('male','female','other')),
  class_id uuid not null references public.academic_classes(id),
  section text,
  status public.student_status not null default 'active',
  admission_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, class_id)
);

create table if not exists public.student_guardians (
  student_id uuid not null references public.students(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  relationship text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (student_id, user_id)
);

create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_user_id uuid not null references auth.users(id) on delete cascade,
  class_id uuid not null references public.academic_classes(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (teacher_user_id, class_id, subject_id)
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null,
  class_id uuid not null references public.academic_classes(id),
  attendance_date date not null,
  status public.attendance_status not null,
  note text,
  marked_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (student_id, attendance_date),
  foreign key (student_id, class_id) references public.students(id, class_id) on delete cascade
);

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  class_id uuid not null references public.academic_classes(id),
  exam_date date,
  academic_year integer not null,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.exam_results (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  subject_id uuid not null references public.subjects(id),
  marks numeric(7,2) not null check (marks >= 0),
  max_marks numeric(7,2) not null check (max_marks > 0 and marks <= max_marks),
  grade text,
  created_at timestamptz not null default now(),
  unique (exam_id, student_id, subject_id)
);

create table if not exists public.fee_invoices (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  invoice_number text not null unique,
  description text not null,
  amount numeric(12,2) not null check (amount >= 0),
  due_date date,
  status text not null default 'unpaid' check (status in ('unpaid','partial','paid','void')),
  created_at timestamptz not null default now()
);

create table if not exists public.fee_payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.fee_invoices(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  paid_at timestamptz not null default now(),
  receipt_number text unique,
  recorded_by uuid not null references auth.users(id),
  payment_method text,
  note text
);

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  title_bn text not null,
  title_en text,
  body_bn text not null,
  body_en text,
  audience text not null default 'all' check (audience in ('all','parents','teachers','students')),
  class_id uuid references public.academic_classes(id) on delete set null,
  is_published boolean not null default false,
  published_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.admission_applications (
  id uuid primary key default gen_random_uuid(),
  application_number text not null unique,
  student_name text not null,
  date_of_birth date,
  applying_class_id uuid not null references public.academic_classes(id),
  guardian_name text not null,
  guardian_phone text not null,
  address text,
  previous_institution text,
  status text not null default 'pending' check (status in ('pending','under_review','approved','rejected')),
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists students_class_status_idx on public.students(class_id, status);
create index if not exists attendance_date_class_idx on public.attendance(attendance_date, class_id);
create index if not exists exam_results_student_idx on public.exam_results(student_id, exam_id);
create index if not exists fee_invoices_student_idx on public.fee_invoices(student_id, status);
create index if not exists notices_published_idx on public.notices(is_published, published_at desc);

-- Create a basic profile whenever Supabase Auth creates a user.
create or replace function public.sga_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

drop trigger if exists sga_on_auth_user_created on auth.users;
create trigger sga_on_auth_user_created
after insert on auth.users
for each row execute procedure public.sga_handle_new_user();

-- Security-definer helpers avoid recursive RLS evaluation on user_roles.
create or replace function public.sga_has_role(required_role public.sga_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = (select auth.uid()) and role = required_role
  );
$$;

create or replace function public.sga_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select public.sga_has_role('admin'::public.sga_role); $$;

create or replace function public.sga_is_teacher_for(class_to_check uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.teacher_assignments
    where teacher_user_id = (select auth.uid()) and class_id = class_to_check
  );
$$;

create or replace function public.sga_is_guardian_of(student_to_check uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.student_guardians
    where user_id = (select auth.uid()) and student_id = student_to_check
  );
$$;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.academic_classes enable row level security;
alter table public.subjects enable row level security;
alter table public.students enable row level security;
alter table public.student_guardians enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.attendance enable row level security;
alter table public.exams enable row level security;
alter table public.exam_results enable row level security;
alter table public.fee_invoices enable row level security;
alter table public.fee_payments enable row level security;
alter table public.notices enable row level security;
alter table public.admission_applications enable row level security;

-- Profiles: users may read/update only their own profile; admins manage all profiles.
drop policy if exists "profiles_read_self_or_admin" on public.profiles;
create policy "profiles_read_self_or_admin" on public.profiles
for select to authenticated using (id = (select auth.uid()) or public.sga_is_admin());
drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin" on public.profiles
for update to authenticated using (id = (select auth.uid()) or public.sga_is_admin())
with check (id = (select auth.uid()) or public.sga_is_admin());

-- Role assignments are not self-service. First admin is bootstrapped manually (see setup guide).
drop policy if exists "roles_read_self_or_admin" on public.user_roles;
create policy "roles_read_self_or_admin" on public.user_roles
for select to authenticated using (user_id = (select auth.uid()) or public.sga_is_admin());
drop policy if exists "roles_admin_manage" on public.user_roles;
create policy "roles_admin_manage" on public.user_roles
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "classes_read_authenticated" on public.academic_classes;
create policy "classes_read_authenticated" on public.academic_classes
for select to authenticated using (true);
drop policy if exists "classes_admin_manage" on public.academic_classes;
create policy "classes_admin_manage" on public.academic_classes
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "subjects_read_authenticated" on public.subjects;
create policy "subjects_read_authenticated" on public.subjects
for select to authenticated using (true);
drop policy if exists "subjects_admin_manage" on public.subjects;
create policy "subjects_admin_manage" on public.subjects
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "students_read_scoped" on public.students;
create policy "students_read_scoped" on public.students
for select to authenticated using (
  public.sga_is_admin()
  or public.sga_is_teacher_for(class_id)
  or public.sga_is_guardian_of(id)
);
drop policy if exists "students_admin_manage" on public.students;
create policy "students_admin_manage" on public.students
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "guardians_read_scoped" on public.student_guardians;
create policy "guardians_read_scoped" on public.student_guardians
for select to authenticated using (public.sga_is_admin() or user_id = (select auth.uid()));
drop policy if exists "guardians_admin_manage" on public.student_guardians;
create policy "guardians_admin_manage" on public.student_guardians
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "assignments_read_scoped" on public.teacher_assignments;
create policy "assignments_read_scoped" on public.teacher_assignments
for select to authenticated using (public.sga_is_admin() or teacher_user_id = (select auth.uid()));
drop policy if exists "assignments_admin_manage" on public.teacher_assignments;
create policy "assignments_admin_manage" on public.teacher_assignments
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "attendance_read_scoped" on public.attendance;
create policy "attendance_read_scoped" on public.attendance
for select to authenticated using (
  public.sga_is_admin()
  or public.sga_is_teacher_for(class_id)
  or public.sga_is_guardian_of(student_id)
);
drop policy if exists "attendance_teacher_write" on public.attendance;
create policy "attendance_teacher_write" on public.attendance
for insert to authenticated
with check (public.sga_is_admin() or (public.sga_is_teacher_for(class_id) and marked_by = (select auth.uid())));
drop policy if exists "attendance_teacher_update" on public.attendance;
create policy "attendance_teacher_update" on public.attendance
for update to authenticated
using (public.sga_is_admin() or (public.sga_is_teacher_for(class_id) and marked_by = (select auth.uid())))
with check (public.sga_is_admin() or (public.sga_is_teacher_for(class_id) and marked_by = (select auth.uid())));

drop policy if exists "exams_read_scoped" on public.exams;
create policy "exams_read_scoped" on public.exams
for select to authenticated using (
  public.sga_is_admin()
  or public.sga_is_teacher_for(class_id)
  or (is_published and exists (
    select 1 from public.students s where s.class_id = exams.class_id and public.sga_is_guardian_of(s.id)
  ))
);
drop policy if exists "exams_admin_manage" on public.exams;
create policy "exams_admin_manage" on public.exams
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "results_read_scoped" on public.exam_results;
create policy "results_read_scoped" on public.exam_results
for select to authenticated using (
  public.sga_is_admin()
  or exists (
    select 1 from public.exams e
    where e.id = exam_results.exam_id
      and (public.sga_is_teacher_for(e.class_id)
        or (e.is_published and public.sga_is_guardian_of(exam_results.student_id)))
  )
);
drop policy if exists "results_admin_manage" on public.exam_results;
create policy "results_admin_manage" on public.exam_results
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "invoices_read_scoped" on public.fee_invoices;
create policy "invoices_read_scoped" on public.fee_invoices
for select to authenticated using (public.sga_is_admin() or public.sga_is_guardian_of(student_id));
drop policy if exists "invoices_admin_manage" on public.fee_invoices;
create policy "invoices_admin_manage" on public.fee_invoices
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "payments_read_scoped" on public.fee_payments;
create policy "payments_read_scoped" on public.fee_payments
for select to authenticated using (
  public.sga_is_admin()
  or exists (
    select 1 from public.fee_invoices i
    where i.id = fee_payments.invoice_id and public.sga_is_guardian_of(i.student_id)
  )
);
drop policy if exists "payments_admin_manage" on public.fee_payments;
create policy "payments_admin_manage" on public.fee_payments
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

-- Published notices are public; only admins can create or edit them.
drop policy if exists "notices_read_published" on public.notices;
create policy "notices_read_published" on public.notices
for select to anon, authenticated using (
  public.sga_is_admin()
  or (
    is_published = true
    and (published_at is null or published_at <= now())
    and (
      (audience = 'all' and class_id is null)
      or (
        (select auth.uid()) is not null
        and (
          (audience = 'parents' and public.sga_has_role('parent'::public.sga_role))
          or (audience = 'teachers' and public.sga_has_role('teacher'::public.sga_role))
          or (audience = 'students' and public.sga_has_role('parent'::public.sga_role))
        )
        and (
          class_id is null
          or public.sga_is_teacher_for(class_id)
          or exists (
            select 1 from public.students s
            where s.class_id = notices.class_id and public.sga_is_guardian_of(s.id)
          )
        )
      )
    )
  )
);
drop policy if exists "notices_admin_manage" on public.notices;
create policy "notices_admin_manage" on public.notices
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

-- Applications contain personal data: no anonymous table insert policy is granted.
-- Accept applications only through a server-side endpoint with validation, rate limiting
-- and private document storage; admins review records through this protected table.
drop policy if exists "applications_admin_manage" on public.admission_applications;
create policy "applications_admin_manage" on public.admission_applications
for all to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

-- Seed only the institution's class names; no students, staff or login accounts.
insert into public.academic_classes (name, sort_order) values
  ('Play Group', 1), ('Nursery', 2), ('KG', 3),
  ('Class One', 4), ('Class Two', 5), ('Class Three', 6),
  ('Class Four', 7), ('Class Five', 8), ('Class Six', 9),
  ('Class Seven', 10), ('Class Eight', 11)
on conflict (name) do nothing;
