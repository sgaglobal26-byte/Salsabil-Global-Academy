-- Additional student profile fields displayed on QR identity cards.
alter table public.students
  add column if not exists father_name text,
  add column if not exists student_phone text,
  add column if not exists blood_group text,
  add column if not exists address text;

alter table public.students
  drop constraint if exists students_blood_group_check;

alter table public.students
  add constraint students_blood_group_check
  check (blood_group is null or blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-','জানা নেই'));
