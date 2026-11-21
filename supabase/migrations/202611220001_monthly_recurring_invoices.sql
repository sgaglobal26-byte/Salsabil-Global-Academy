-- Monthly recurring invoices for Salsabil Global Academy.
-- Run this file once in Supabase SQL Editor after reviewing it.

alter table public.fee_invoices
  add column if not exists recurring_series_id uuid,
  add column if not exists billing_month date;

create unique index if not exists fee_invoices_recurring_month_unique
  on public.fee_invoices (recurring_series_id, billing_month)
  where recurring_series_id is not null;

create or replace function public.sga_mark_invoice_recurring(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invoice public.fee_invoices%rowtype;
begin
  if not public.sga_is_admin() then
    raise exception 'Admin permission required';
  end if;

  select * into v_invoice
  from public.fee_invoices
  where id = p_invoice_id
  for update;

  if not found then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.status = 'void' then
    raise exception 'Void invoice cannot be recurring';
  end if;

  update public.fee_invoices
  set recurring_series_id = id,
      billing_month = date_trunc('month', coalesce(due_date, created_at::date))::date
  where id = p_invoice_id
    and recurring_series_id is null;
end;
$$;

revoke all on function public.sga_mark_invoice_recurring(uuid) from public, anon;
grant execute on function public.sga_mark_invoice_recurring(uuid) to authenticated;

create or replace function public.sga_generate_monthly_invoices()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_month date;
  v_count integer := 0;
  v_template record;
  v_due_date date;
  v_invoice_number text;
begin
  -- The cron job runs daily near Bangladesh midnight; do work only on day 1.
  if extract(day from v_today) <> 1 then
    return 0;
  end if;

  v_month := date_trunc('month', v_today)::date;

  for v_template in
    select distinct on (i.recurring_series_id)
      i.recurring_series_id,
      i.student_id,
      i.description,
      i.amount,
      i.due_date,
      s.student_code
    from public.fee_invoices i
    join public.students s on s.id = i.student_id
    where i.recurring_series_id is not null
      and i.status <> 'void'
      and s.status = 'active'
    order by i.recurring_series_id, i.billing_month desc nulls last, i.created_at desc
  loop
    if v_template.due_date is null then
      v_due_date := null;
    else
      v_due_date := make_date(
        extract(year from v_month)::integer,
        extract(month from v_month)::integer,
        least(
          extract(day from v_template.due_date)::integer,
          extract(day from (v_month + interval '1 month - 1 day'))::integer
        )
      );
    end if;

    v_invoice_number :=
      'M' || to_char(v_month, 'YYYYMM') || '-' ||
      regexp_replace(v_template.student_code, '[^A-Za-z0-9]', '', 'g') || '-' ||
      substr(v_template.recurring_series_id::text, 1, 6);

    insert into public.fee_invoices (
      student_id, invoice_number, description, amount, due_date, status,
      recurring_series_id, billing_month
    )
    values (
      v_template.student_id, v_invoice_number, v_template.description,
      v_template.amount, v_due_date, 'unpaid',
      v_template.recurring_series_id, v_month
    )
    on conflict (recurring_series_id, billing_month)
      where recurring_series_id is not null
      do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.sga_generate_monthly_invoices() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'sga-monthly-invoice-generation';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  -- 18:05 UTC is 00:05 Bangladesh time on the following date.
  -- Runs on UTC dates 28-31; the function acts only on Bangladesh day 1.
  perform cron.schedule(
    'sga-monthly-invoice-generation',
    '5 18 28-31 * *',
    'select public.sga_generate_monthly_invoices();'
  );
end;
$$;
