-- Bond positions per user.
-- Keeps lifecycle and valuation for wallet calculations.

create extension if not exists pgcrypto;

create or replace function public.bonds_positions_apply_defaults_and_validate()
returns trigger
language plpgsql
as $$
begin
  new.currency := upper(new.currency);

  if new.term_months is null or new.term_months <= 0 then
    raise exception 'term_months must be > 0';
  end if;

  -- Maturity date derived from purchase date + term in months.
  new.maturity_date := (new.purchase_date + make_interval(months => new.term_months))::date;
  return new;
end;
$$;

create table if not exists public.bonds_positions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  currency text not null default 'PLN',
  purchase_date date not null,
  term_months int not null,
  maturity_date date not null,
  opening_value numeric(18,2) not null,
  current_value numeric(18,2) not null,
  profit_loss numeric(18,2) generated always as (current_value - opening_value) stored,
  interest_rate_pct numeric(6,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint bonds_positions_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint bonds_positions_currency_iso3_chk check (currency ~ '^[A-Z]{3}$'),
  constraint bonds_positions_term_positive_chk check (term_months > 0),
  constraint bonds_positions_opening_non_negative_chk check (opening_value >= 0),
  constraint bonds_positions_current_non_negative_chk check (current_value >= 0),
  constraint bonds_positions_interest_non_negative_chk check (interest_rate_pct >= 0),
  constraint bonds_positions_maturity_after_purchase_chk check (maturity_date >= purchase_date)
);

drop trigger if exists trg_bonds_positions_apply_defaults on public.bonds_positions;
create trigger trg_bonds_positions_apply_defaults
before insert or update on public.bonds_positions
for each row
execute function public.bonds_positions_apply_defaults_and_validate();

drop trigger if exists trg_bonds_positions_set_updated_at on public.bonds_positions;
create trigger trg_bonds_positions_set_updated_at
before update on public.bonds_positions
for each row
execute function public.set_updated_at();

create index if not exists idx_bonds_positions_owner_purchase
  on public.bonds_positions (owner_id, purchase_date desc);

create index if not exists idx_bonds_positions_owner_maturity
  on public.bonds_positions (owner_id, maturity_date desc);

create index if not exists idx_bonds_positions_owner_currency
  on public.bonds_positions (owner_id, currency);

alter table public.bonds_positions enable row level security;
alter table public.bonds_positions force row level security;

create policy "bonds_positions_select_own"
  on public.bonds_positions
  for select
  using (owner_id = auth.uid());

create policy "bonds_positions_insert_own"
  on public.bonds_positions
  for insert
  with check (owner_id = auth.uid());

create policy "bonds_positions_update_own"
  on public.bonds_positions
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "bonds_positions_delete_own"
  on public.bonds_positions
  for delete
  using (owner_id = auth.uid());
