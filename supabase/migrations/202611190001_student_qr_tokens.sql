-- Unique, non-guessable token used by each student's QR identity card.
alter table public.students
  add column if not exists qr_token uuid;

update public.students
set qr_token = gen_random_uuid()
where qr_token is null;

alter table public.students
  alter column qr_token set default gen_random_uuid(),
  alter column qr_token set not null;

create unique index if not exists students_qr_token_uidx
  on public.students (qr_token);
