-- Track money actually received from shareholders, separately from student fee collections.
create table if not exists public.shareholder_income_entries (
  id uuid primary key default gen_random_uuid(),
  shareholder_name text not null,
  amount numeric(12,2) not null check (amount > 0),
  received_on date not null default (now() at time zone 'Asia/Dhaka')::date,
  payment_method text not null default 'cash'
    check (payment_method in ('cash','bank','mobile_banking')),
  receipt_number text,
  notes text,
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.shareholder_income_entries enable row level security;

drop policy if exists "sga_admin_select_shareholder_income" on public.shareholder_income_entries;
create policy "sga_admin_select_shareholder_income"
  on public.shareholder_income_entries for select
  to authenticated using (public.sga_is_admin());

drop policy if exists "sga_admin_insert_shareholder_income" on public.shareholder_income_entries;
create policy "sga_admin_insert_shareholder_income"
  on public.shareholder_income_entries for insert
  to authenticated with check (public.sga_is_admin());

drop policy if exists "sga_admin_update_shareholder_income" on public.shareholder_income_entries;
create policy "sga_admin_update_shareholder_income"
  on public.shareholder_income_entries for update
  to authenticated using (public.sga_is_admin()) with check (public.sga_is_admin());

drop policy if exists "sga_admin_delete_shareholder_income" on public.shareholder_income_entries;
create policy "sga_admin_delete_shareholder_income"
  on public.shareholder_income_entries for delete
  to authenticated using (public.sga_is_admin());

grant select, insert, update, delete on public.shareholder_income_entries to authenticated;
