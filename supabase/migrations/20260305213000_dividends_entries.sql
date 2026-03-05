-- Dividends entries per user.

create extension if not exists pgcrypto;

create table if not exists public.dividends_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  currency text not null,
  value numeric(18,2) not null,
  paid_at date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint dividends_entries_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint dividends_entries_currency_allowed_chk check (currency in ('PLN', 'EUR', 'USD')),
  constraint dividends_entries_value_non_negative_chk check (value >= 0)
);

drop trigger if exists trg_dividends_entries_set_updated_at on public.dividends_entries;
create trigger trg_dividends_entries_set_updated_at
before update on public.dividends_entries
for each row
execute function public.set_updated_at();

create index if not exists idx_dividends_entries_owner_paid
  on public.dividends_entries (owner_id, paid_at desc);

create index if not exists idx_dividends_entries_owner_currency_paid
  on public.dividends_entries (owner_id, currency, paid_at desc);

alter table public.dividends_entries enable row level security;
alter table public.dividends_entries force row level security;

create policy "dividends_entries_select_own"
  on public.dividends_entries
  for select
  using (owner_id = auth.uid());

create policy "dividends_entries_insert_own"
  on public.dividends_entries
  for insert
  with check (owner_id = auth.uid());

create policy "dividends_entries_update_own"
  on public.dividends_entries
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "dividends_entries_delete_own"
  on public.dividends_entries
  for delete
  using (owner_id = auth.uid());
