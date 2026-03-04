-- Cash balances panel data for authenticated users.
-- One record per (owner, month, currency).

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.cash_balances_apply_defaults_and_validate()
returns trigger
language plpgsql
as $$
declare
  month_start date;
  month_end date;
begin
  -- Normalize month to first day and normalize currency format.
  new.period_month := date_trunc('month', new.period_month)::date;
  new.currency := upper(new.currency);

  month_start := new.period_month;
  month_end := (new.period_month + interval '1 month - 1 day')::date;

  -- If not provided, store snapshot as the last day of the period month.
  if new.as_of_date is null then
    new.as_of_date := month_end;
  end if;

  -- as_of_date must belong to the same month as period_month.
  if date_trunc('month', new.as_of_date)::date <> month_start then
    raise exception 'as_of_date (%) must be in the same month as period_month (%)',
      new.as_of_date,
      new.period_month;
  end if;

  return new;
end;
$$;

create table if not exists public.cash_balances (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  period_month date not null,
  as_of_date date,
  currency text not null,
  amount numeric(18,2) not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint cash_balances_currency_iso3_chk check (currency ~ '^[A-Z]{3}$'),
  constraint cash_balances_amount_non_negative_chk check (amount >= 0),
  constraint cash_balances_period_is_month_start_chk check (
    period_month = date_trunc('month', period_month)::date
  ),
  constraint cash_balances_as_of_same_month_chk check (
    date_trunc('month', as_of_date)::date = period_month
  ),
  constraint cash_balances_owner_period_currency_uniq unique (owner_id, period_month, currency)
);

create trigger trg_cash_balances_apply_defaults
before insert or update on public.cash_balances
for each row
execute function public.cash_balances_apply_defaults_and_validate();

create trigger trg_cash_balances_set_updated_at
before update on public.cash_balances
for each row
execute function public.set_updated_at();

create index if not exists idx_cash_balances_owner_period
  on public.cash_balances (owner_id, period_month desc);

create index if not exists idx_cash_balances_owner_currency_period
  on public.cash_balances (owner_id, currency, period_month desc);

alter table public.cash_balances enable row level security;
alter table public.cash_balances force row level security;

create policy "cash_balances_select_own"
  on public.cash_balances
  for select
  using (owner_id = auth.uid());

create policy "cash_balances_insert_own"
  on public.cash_balances
  for insert
  with check (owner_id = auth.uid());

create policy "cash_balances_update_own"
  on public.cash_balances
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "cash_balances_delete_own"
  on public.cash_balances
  for delete
  using (owner_id = auth.uid());

create or replace function public.get_cash_balance_series(
  p_currency text,
  p_months int default 12
)
returns table (
  period_month date,
  as_of_date date,
  currency text,
  amount numeric(18,2),
  updated_at timestamptz
)
language sql
security invoker
set search_path = public
as $$
  select
    cb.period_month,
    cb.as_of_date,
    cb.currency,
    cb.amount,
    cb.updated_at
  from public.cash_balances cb
  where cb.owner_id = auth.uid()
    and cb.currency = upper(p_currency)
    and cb.period_month >= (date_trunc('month', current_date)::date - ((greatest(p_months, 1) - 1) * interval '1 month'))::date
  order by cb.period_month asc;
$$;
