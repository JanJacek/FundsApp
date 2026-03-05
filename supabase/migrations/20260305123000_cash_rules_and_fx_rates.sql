-- Cash panel rules update:
-- 1) only PLN/EUR/USD currencies
-- 2) as_of_date always forced to month-end
-- 3) add monthly FX rates table for month-end conversions

create or replace function public.cash_balances_apply_defaults_and_validate()
returns trigger
language plpgsql
as $$
declare
  month_end date;
begin
  new.period_month := date_trunc('month', new.period_month)::date;
  new.currency := upper(new.currency);

  if new.currency not in ('PLN', 'EUR', 'USD') then
    raise exception 'currency (%) must be one of: PLN, EUR, USD', new.currency;
  end if;

  month_end := (new.period_month + interval '1 month - 1 day')::date;

  -- Always keep snapshot date on the last day of selected month.
  new.as_of_date := month_end;

  return new;
end;
$$;

update public.cash_balances
set
  currency = upper(currency),
  period_month = date_trunc('month', period_month)::date,
  as_of_date = (date_trunc('month', period_month)::date + interval '1 month - 1 day')::date;

alter table public.cash_balances
  drop constraint if exists cash_balances_currency_iso3_chk;

alter table public.cash_balances
  add constraint cash_balances_currency_allowed_chk
  check (currency in ('PLN', 'EUR', 'USD'));

-- Global FX rates (to PLN) for specific dates.
create table if not exists public.fx_rates (
  id uuid primary key default gen_random_uuid(),
  rate_date date not null,
  currency text not null,
  rate_to_pln numeric(18,6) not null,
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint fx_rates_currency_iso3_chk check (currency ~ '^[A-Z]{3}$'),
  constraint fx_rates_rate_positive_chk check (rate_to_pln > 0),
  constraint fx_rates_date_currency_uniq unique (rate_date, currency)
);

drop trigger if exists trg_fx_rates_set_updated_at on public.fx_rates;
create trigger trg_fx_rates_set_updated_at
before update on public.fx_rates
for each row
execute function public.set_updated_at();

create index if not exists idx_fx_rates_currency_date
  on public.fx_rates (currency, rate_date desc);

alter table public.fx_rates enable row level security;
alter table public.fx_rates force row level security;

drop policy if exists "fx_rates_select_authenticated" on public.fx_rates;
create policy "fx_rates_select_authenticated"
  on public.fx_rates
  for select
  using (auth.role() = 'authenticated');
