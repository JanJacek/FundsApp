-- Simplify bonds_positions to only OTS and TOS logic.
-- Keeps data in-place and normalizes legacy rows.

create extension if not exists pgcrypto;

alter table public.bonds_positions
  add column if not exists bond_type text,
  add column if not exists quantity int,
  add column if not exists nominal_per_bond numeric(18,2) default 100,
  add column if not exists interest_rate numeric(10,6) default 0;

-- Migrate legacy data if table had older shape.
update public.bonds_positions
set bond_type = case
  when coalesce(term_months, 0) <= 3 then 'OTS'
  else 'TOS'
end
where bond_type is null;

update public.bonds_positions
set quantity = greatest(1, round(coalesce(opening_value, 100) / 100)::int)
where quantity is null;

update public.bonds_positions
set nominal_per_bond = 100
where nominal_per_bond is null;

update public.bonds_positions
set interest_rate = coalesce(interest_rate_pct, 0) / 100.0
where interest_rate is null;

create or replace function public.bonds_positions_apply_defaults_and_validate()
returns trigger
language plpgsql
as $$
begin
  new.bond_type := upper(new.bond_type);

  if new.bond_type not in ('OTS', 'TOS') then
    raise exception 'bond_type must be OTS or TOS';
  end if;

  if new.quantity is null or new.quantity <= 0 then
    raise exception 'quantity must be > 0';
  end if;

  if new.nominal_per_bond is null then
    new.nominal_per_bond := 100;
  end if;

  if new.nominal_per_bond <= 0 then
    raise exception 'nominal_per_bond must be > 0';
  end if;

  if new.interest_rate is null then
    new.interest_rate := 0;
  end if;

  if new.interest_rate < 0 then
    raise exception 'interest_rate must be >= 0';
  end if;

  if new.bond_type = 'OTS' then
    new.maturity_date := (new.purchase_date + interval '3 months')::date;
  else
    new.maturity_date := (new.purchase_date + interval '3 years')::date;
  end if;

  return new;
end;
$$;

update public.bonds_positions
set maturity_date = case
  when upper(bond_type) = 'OTS' then (purchase_date + interval '3 months')::date
  else (purchase_date + interval '3 years')::date
end;

alter table public.bonds_positions
  alter column bond_type set not null,
  alter column quantity set not null,
  alter column nominal_per_bond set not null,
  alter column nominal_per_bond set default 100,
  alter column interest_rate set not null,
  alter column interest_rate set default 0;

alter table public.bonds_positions
  drop constraint if exists bonds_positions_name_not_blank_chk,
  drop constraint if exists bonds_positions_currency_iso3_chk,
  drop constraint if exists bonds_positions_term_positive_chk,
  drop constraint if exists bonds_positions_opening_non_negative_chk,
  drop constraint if exists bonds_positions_current_non_negative_chk,
  drop constraint if exists bonds_positions_interest_non_negative_chk,
  drop constraint if exists bonds_positions_maturity_after_purchase_chk;

alter table public.bonds_positions
  add constraint bonds_positions_bond_type_chk check (bond_type in ('OTS', 'TOS')),
  add constraint bonds_positions_quantity_positive_chk check (quantity > 0),
  add constraint bonds_positions_nominal_positive_chk check (nominal_per_bond > 0),
  add constraint bonds_positions_interest_non_negative_chk check (interest_rate >= 0),
  add constraint bonds_positions_maturity_by_type_chk check (
    (bond_type = 'OTS' and maturity_date = (purchase_date + interval '3 months')::date)
    or
    (bond_type = 'TOS' and maturity_date = (purchase_date + interval '3 years')::date)
  );

alter table public.bonds_positions
  drop column if exists profit_loss;

alter table public.bonds_positions
  drop column if exists name,
  drop column if exists currency,
  drop column if exists term_months,
  drop column if exists opening_value,
  drop column if exists current_value,
  drop column if exists interest_rate_pct;

drop index if exists idx_bonds_positions_owner_currency;
create index if not exists idx_bonds_positions_owner_type
  on public.bonds_positions (owner_id, bond_type);

drop trigger if exists trg_bonds_positions_apply_defaults on public.bonds_positions;
create trigger trg_bonds_positions_apply_defaults
before insert or update on public.bonds_positions
for each row
execute function public.bonds_positions_apply_defaults_and_validate();
