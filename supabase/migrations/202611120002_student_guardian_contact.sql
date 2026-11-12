-- Add guardian contact fields used by the student management screen.
-- Safe to run more than once.
alter table public.students
  add column if not exists guardian_name text,
  add column if not exists guardian_phone text;

comment on column public.students.guardian_name is 'Primary guardian name recorded by school administration';
comment on column public.students.guardian_phone is 'Primary guardian contact phone recorded by school administration';
