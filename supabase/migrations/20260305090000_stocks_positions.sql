-- Stock positions per user.
-- Stores instrument pricing and lifecycle dates.

create extension if not exists pgcrypto;

create table if not exists public.stocks_positions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  current_price numeric(18,2) not null,
  opening_price numeric(18,2) not null,
  profit_loss numeric(18,2) generated always as (current_price - opening_price) stored,
  opened_at date not null,
  closed_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint stocks_positions_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint stocks_positions_current_price_non_negative_chk check (current_price >= 0),
  constraint stocks_positions_opening_price_non_negative_chk check (opening_price >= 0),
  constraint stocks_positions_closed_at_after_opened_at_chk check (
    closed_at is null or closed_at >= opened_at
  )
);

drop trigger if exists trg_stocks_positions_set_updated_at on public.stocks_positions;
create trigger trg_stocks_positions_set_updated_at
before update on public.stocks_positions
for each row
execute function public.set_updated_at();

create index if not exists idx_stocks_positions_owner_opened
  on public.stocks_positions (owner_id, opened_at desc);

create index if not exists idx_stocks_positions_owner_closed
  on public.stocks_positions (owner_id, closed_at desc nulls first);

alter table public.stocks_positions enable row level security;
alter table public.stocks_positions force row level security;

create policy "stocks_positions_select_own"
  on public.stocks_positions
  for select
  using (owner_id = auth.uid());

create policy "stocks_positions_insert_own"
  on public.stocks_positions
  for insert
  with check (owner_id = auth.uid());

create policy "stocks_positions_update_own"
  on public.stocks_positions
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "stocks_positions_delete_own"
  on public.stocks_positions
  for delete
  using (owner_id = auth.uid());
