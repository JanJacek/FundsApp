-- Add currency to stocks and ETFs for FX conversion.

alter table public.stocks_positions
  add column if not exists currency text not null default 'PLN';

update public.stocks_positions
set currency = upper(currency);

alter table public.stocks_positions
  drop constraint if exists stocks_positions_currency_allowed_chk;

alter table public.stocks_positions
  add constraint stocks_positions_currency_allowed_chk
  check (currency in ('PLN', 'EUR', 'USD'));

create index if not exists idx_stocks_positions_owner_currency
  on public.stocks_positions (owner_id, currency);

alter table public.etfs_positions
  add column if not exists currency text not null default 'PLN';

update public.etfs_positions
set currency = upper(currency);

alter table public.etfs_positions
  drop constraint if exists etfs_positions_currency_allowed_chk;

alter table public.etfs_positions
  add constraint etfs_positions_currency_allowed_chk
  check (currency in ('PLN', 'EUR', 'USD'));

create index if not exists idx_etfs_positions_owner_currency
  on public.etfs_positions (owner_id, currency);
