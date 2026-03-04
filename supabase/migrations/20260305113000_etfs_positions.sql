-- ETF positions per user.
-- Mirrors stock fields and security model.

create extension if not exists pgcrypto;

create table if not exists public.etfs_positions (
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

  constraint etfs_positions_name_not_blank_chk check (length(btrim(name)) > 0),
  constraint etfs_positions_current_price_non_negative_chk check (current_price >= 0),
  constraint etfs_positions_opening_price_non_negative_chk check (opening_price >= 0),
  constraint etfs_positions_closed_at_after_opened_at_chk check (
    closed_at is null or closed_at >= opened_at
  )
);

drop trigger if exists trg_etfs_positions_set_updated_at on public.etfs_positions;
create trigger trg_etfs_positions_set_updated_at
before update on public.etfs_positions
for each row
execute function public.set_updated_at();

create index if not exists idx_etfs_positions_owner_opened
  on public.etfs_positions (owner_id, opened_at desc);

create index if not exists idx_etfs_positions_owner_closed
  on public.etfs_positions (owner_id, closed_at desc nulls first);

alter table public.etfs_positions enable row level security;
alter table public.etfs_positions force row level security;

create policy "etfs_positions_select_own"
  on public.etfs_positions
  for select
  using (owner_id = auth.uid());

create policy "etfs_positions_insert_own"
  on public.etfs_positions
  for insert
  with check (owner_id = auth.uid());

create policy "etfs_positions_update_own"
  on public.etfs_positions
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "etfs_positions_delete_own"
  on public.etfs_positions
  for delete
  using (owner_id = auth.uid());
