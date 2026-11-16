-- Separate expense ledger; student fee collections remain the source of income.
create table if not exists public.expense_entries (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null default current_date,
  category text not null check (category in (
    'salary','education','utility','rent','transport','maintenance','food','office','other'
  )),
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  voucher_number text,
  payment_method text not null default 'cash' check (payment_method in ('cash','bank','mobile_banking')),
  notes text,
  recorded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists expense_entries_date_idx on public.expense_entries(expense_date desc);
create index if not exists expense_entries_category_idx on public.expense_entries(category);
alter table public.expense_entries enable row level security;
drop policy if exists expense_entries_admin_read on public.expense_entries;
create policy expense_entries_admin_read on public.expense_entries
  for select to authenticated using (public.sga_is_admin());
drop policy if exists expense_entries_admin_insert on public.expense_entries;
create policy expense_entries_admin_insert on public.expense_entries
  for insert to authenticated with check (public.sga_is_admin() and recorded_by = (select auth.uid()));
drop policy if exists expense_entries_admin_update on public.expense_entries;
create policy expense_entries_admin_update on public.expense_entries
  for update to authenticated using (public.sga_is_admin())
  with check (public.sga_is_admin() and recorded_by = (select auth.uid()));
drop policy if exists expense_entries_admin_delete on public.expense_entries;
create policy expense_entries_admin_delete on public.expense_entries
  for delete to authenticated using (public.sga_is_admin());
grant select,insert,update,delete on public.expense_entries to authenticated;
