-- Teacher attendance records used by the Admin > Attendance Reports page.
create table if not exists public.teacher_attendance (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  attendance_date date not null default current_date,
  status text not null check (status in ('present','absent','late','excused')),
  note text,
  marked_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (teacher_id, attendance_date)
);

create index if not exists teacher_attendance_date_idx
  on public.teacher_attendance(attendance_date desc);
create index if not exists teacher_attendance_teacher_idx
  on public.teacher_attendance(teacher_id, attendance_date desc);

alter table public.teacher_attendance enable row level security;

drop policy if exists teacher_attendance_admin_read on public.teacher_attendance;
create policy teacher_attendance_admin_read
  on public.teacher_attendance for select to authenticated
  using (public.sga_is_admin());

drop policy if exists teacher_attendance_admin_insert on public.teacher_attendance;
create policy teacher_attendance_admin_insert
  on public.teacher_attendance for insert to authenticated
  with check (public.sga_is_admin() and marked_by = (select auth.uid()));

drop policy if exists teacher_attendance_admin_update on public.teacher_attendance;
create policy teacher_attendance_admin_update
  on public.teacher_attendance for update to authenticated
  using (public.sga_is_admin())
  with check (public.sga_is_admin() and marked_by = (select auth.uid()));

drop policy if exists teacher_attendance_admin_delete on public.teacher_attendance;
create policy teacher_attendance_admin_delete
  on public.teacher_attendance for delete to authenticated
  using (public.sga_is_admin());

grant select, insert, update, delete on public.teacher_attendance to authenticated;
