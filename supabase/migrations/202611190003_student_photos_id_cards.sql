-- Student photo storage and profile field for printable QR identity cards.
alter table public.students
  add column if not exists photo_path text;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'student-photos',
  'student-photos',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists student_photos_public_read on storage.objects;
create policy student_photos_public_read
on storage.objects for select
to anon, authenticated
using (bucket_id = 'student-photos');

drop policy if exists student_photos_admin_insert on storage.objects;
create policy student_photos_admin_insert
on storage.objects for insert
to authenticated
with check (bucket_id = 'student-photos' and public.sga_is_admin());

drop policy if exists student_photos_admin_update on storage.objects;
create policy student_photos_admin_update
on storage.objects for update
to authenticated
using (bucket_id = 'student-photos' and public.sga_is_admin())
with check (bucket_id = 'student-photos' and public.sga_is_admin());

drop policy if exists student_photos_admin_delete on storage.objects;
create policy student_photos_admin_delete
on storage.objects for delete
to authenticated
using (bucket_id = 'student-photos' and public.sga_is_admin());
