-- Editable public Home Page content, managed by authenticated admins.
create table if not exists public.home_page_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text not null unique check (section_key in (
    'intro','vision','departments','curriculum','activities','why_us',
    'support_transport','admission','faq','contact'
  )),
  title_bn text not null,
  body_bn text not null default '',
  title_en text,
  body_en text,
  sort_order integer not null default 0,
  is_published boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
create index if not exists home_page_sections_public_order_idx
  on public.home_page_sections(is_published, sort_order);
alter table public.home_page_sections enable row level security;
drop policy if exists "home_page_sections_public_read" on public.home_page_sections;
create policy "home_page_sections_public_read" on public.home_page_sections
  for select to anon, authenticated using (is_published = true or public.sga_is_admin());
drop policy if exists "home_page_sections_admin_insert" on public.home_page_sections;
create policy "home_page_sections_admin_insert" on public.home_page_sections
  for insert to authenticated with check (public.sga_is_admin() and updated_by = (select auth.uid()));
drop policy if exists "home_page_sections_admin_update" on public.home_page_sections;
create policy "home_page_sections_admin_update" on public.home_page_sections
  for update to authenticated using (public.sga_is_admin())
  with check (public.sga_is_admin() and updated_by = (select auth.uid()));
drop policy if exists "home_page_sections_admin_delete" on public.home_page_sections;
create policy "home_page_sections_admin_delete" on public.home_page_sections
  for delete to authenticated using (public.sga_is_admin());
grant select on public.home_page_sections to anon, authenticated;
grant insert, update, delete on public.home_page_sections to authenticated;
