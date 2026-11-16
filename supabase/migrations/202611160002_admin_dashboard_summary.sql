-- Admin-only dashboard summary. Keeps financial aggregates on the database
-- and uses Bangladesh local month/day boundaries.
create or replace function public.sga_admin_dashboard_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_month_start timestamptz :=
    date_trunc('month', now() at time zone 'Asia/Dhaka') at time zone 'Asia/Dhaka';
  v_next_month_start timestamptz :=
    (date_trunc('month', now() at time zone 'Asia/Dhaka') + interval '1 month') at time zone 'Asia/Dhaka';
begin
  if not public.sga_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'total_students',
      (select count(*) from public.students),
    'total_teachers',
      (select count(distinct user_id)
       from public.user_roles
       where role = 'teacher'::public.sga_role),
    'total_classes',
      (select count(*) from public.academic_classes where is_active = true),
    'pending_admissions',
      (select count(*) from public.admission_applications where status = 'pending'),
    'today_attendance',
      (select count(*) from public.attendance where attendance_date = v_today),
    'monthly_collection',
      (select coalesce(sum(amount), 0)
       from public.fee_payments
       where paid_at >= v_month_start and paid_at < v_next_month_start),
    'outstanding_fees',
      (select coalesce(sum(greatest(i.amount - coalesce(p.paid_amount, 0), 0)), 0)
       from public.fee_invoices i
       left join (
         select invoice_id, sum(amount) as paid_amount
         from public.fee_payments
         group by invoice_id
       ) p on p.invoice_id = i.id
       where i.status <> 'void'),
    'upcoming_exams',
      (select count(*) from public.exams where exam_date >= v_today)
  );
end;
$$;

revoke all on function public.sga_admin_dashboard_summary() from public;
revoke all on function public.sga_admin_dashboard_summary() from anon;
grant execute on function public.sga_admin_dashboard_summary() to authenticated;

comment on function public.sga_admin_dashboard_summary() is
  'Returns aggregate school dashboard metrics only to authenticated SGA administrators; date boundaries use Asia/Dhaka.';
