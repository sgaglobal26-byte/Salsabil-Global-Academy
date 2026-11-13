-- Section-scoped teacher assignments and RLS.
-- Run after 202611120001_initial_school_management.sql and 202611120002_student_guardian_contact.sql.

alter table public.teacher_assignments
  add column if not exists section text;

create index if not exists teacher_assignments_teacher_class_section_idx
  on public.teacher_assignments (teacher_user_id, class_id, section);

-- A teacher assigned to a named section may only read its students and records.
-- A NULL section intentionally means the teacher is assigned to the whole class.
create or replace function public.sga_is_teacher_for_student(student_to_check uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.students s
    join public.teacher_assignments ta on ta.class_id = s.class_id
    where s.id = student_to_check
      and ta.teacher_user_id = (select auth.uid())
      and (ta.section is null or ta.section = s.section)
  );
$$;

drop policy if exists "students_read_scoped" on public.students;
create policy "students_read_scoped" on public.students
for select to authenticated using (
  public.sga_is_admin()
  or public.sga_is_teacher_for_student(id)
  or public.sga_is_guardian_of(id)
);

drop policy if exists "attendance_read_scoped" on public.attendance;
create policy "attendance_read_scoped" on public.attendance
for select to authenticated using (
  public.sga_is_admin()
  or exists (
    select 1 from public.students s
    where s.id = attendance.student_id
      and public.sga_is_teacher_for_student(s.id)
  )
  or public.sga_is_guardian_of(student_id)
);

drop policy if exists "attendance_teacher_write" on public.attendance;
create policy "attendance_teacher_write" on public.attendance
for insert to authenticated
with check (
  public.sga_is_admin()
  or (
    public.sga_is_teacher_for_student(student_id)
    and marked_by = (select auth.uid())
  )
);

drop policy if exists "attendance_teacher_update" on public.attendance;
create policy "attendance_teacher_update" on public.attendance
for update to authenticated
using (
  public.sga_is_admin()
  or (
    public.sga_is_teacher_for_student(student_id)
    and marked_by = (select auth.uid())
  )
)
with check (
  public.sga_is_admin()
  or (
    public.sga_is_teacher_for_student(student_id)
    and marked_by = (select auth.uid())
  )
);

drop policy if exists "results_read_scoped" on public.exam_results;
create policy "results_read_scoped" on public.exam_results
for select to authenticated using (
  public.sga_is_admin()
  or exists (
    select 1
    from public.exams e
    join public.students s
      on s.id = exam_results.student_id
     and s.class_id = e.class_id
    where e.id = exam_results.exam_id
      and (
        public.sga_is_teacher_for_student(s.id)
        or (e.is_published and public.sga_is_guardian_of(s.id))
      )
  )
);

-- This helper is only needed by authenticated teacher-scoped RLS policies.
revoke all on function public.sga_is_teacher_for_student(uuid) from public;
revoke all on function public.sga_is_teacher_for_student(uuid) from anon;
grant execute on function public.sga_is_teacher_for_student(uuid) to authenticated;
