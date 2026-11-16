-- Leadership profiles and messages (publicly readable, admin-managed).
create table if not exists public.leadership_profiles (
 id uuid primary key default gen_random_uuid(),
 role_key text not null unique check (role_key in ('chairman','headmaster','director','teacher','administrator')),
 role_bn text not null,
 name_bn text not null,
 designation_bn text,
 message_bn text not null default '',
 photo_path text,
 sort_order integer not null default 0,
 is_published boolean not null default true,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
alter table public.leadership_profiles enable row level security;
drop policy if exists leadership_public_read on public.leadership_profiles;
create policy leadership_public_read on public.leadership_profiles for select to anon, authenticated using (is_published = true or public.sga_is_admin());
drop policy if exists leadership_admin_insert on public.leadership_profiles;
create policy leadership_admin_insert on public.leadership_profiles for insert to authenticated with check (public.sga_is_admin() and updated_by = (select auth.uid()));
drop policy if exists leadership_admin_update on public.leadership_profiles;
create policy leadership_admin_update on public.leadership_profiles for update to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin() and updated_by = (select auth.uid()));
drop policy if exists leadership_admin_delete on public.leadership_profiles;
create policy leadership_admin_delete on public.leadership_profiles for delete to authenticated using (public.sga_is_admin());
grant select,insert,update,delete on public.leadership_profiles to anon,authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('leadership-photos','leadership-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists leadership_photos_public_read on storage.objects;
create policy leadership_photos_public_read on storage.objects for select to anon,authenticated using (bucket_id='leadership-photos');
drop policy if exists leadership_photos_admin_insert on storage.objects;
create policy leadership_photos_admin_insert on storage.objects for insert to authenticated with check (bucket_id='leadership-photos' and public.sga_is_admin());
drop policy if exists leadership_photos_admin_update on storage.objects;
create policy leadership_photos_admin_update on storage.objects for update to authenticated using (bucket_id='leadership-photos' and public.sga_is_admin()) with check (bucket_id='leadership-photos' and public.sga_is_admin());
drop policy if exists leadership_photos_admin_delete on storage.objects;
create policy leadership_photos_admin_delete on storage.objects for delete to authenticated using (bucket_id='leadership-photos' and public.sga_is_admin());
