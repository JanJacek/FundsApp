-- Per-user portfolio structure settings.
-- Defaults: cash 4.6%, stocks 10%, etfs 67.4%, bonds 18% (sum = 100%).

create table if not exists public.portfolio_settings (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  cash_pct numeric(5,2) not null default 4.60,
  stocks_pct numeric(5,2) not null default 10.00,
  etfs_pct numeric(5,2) not null default 67.40,
  bonds_pct numeric(5,2) not null default 18.00,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint portfolio_settings_cash_range_chk check (cash_pct >= 0 and cash_pct <= 100),
  constraint portfolio_settings_stocks_range_chk check (stocks_pct >= 0 and stocks_pct <= 100),
  constraint portfolio_settings_etfs_range_chk check (etfs_pct >= 0 and etfs_pct <= 100),
  constraint portfolio_settings_bonds_range_chk check (bonds_pct >= 0 and bonds_pct <= 100),
  constraint portfolio_settings_total_100_chk check (
    round(cash_pct + stocks_pct + etfs_pct + bonds_pct, 2) = 100.00
  )
);

drop trigger if exists trg_portfolio_settings_set_updated_at on public.portfolio_settings;
create trigger trg_portfolio_settings_set_updated_at
before update on public.portfolio_settings
for each row
execute function public.set_updated_at();

alter table public.portfolio_settings enable row level security;
alter table public.portfolio_settings force row level security;

create policy "portfolio_settings_select_own"
  on public.portfolio_settings
  for select
  using (owner_id = auth.uid());

create policy "portfolio_settings_insert_own"
  on public.portfolio_settings
  for insert
  with check (owner_id = auth.uid());

create policy "portfolio_settings_update_own"
  on public.portfolio_settings
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "portfolio_settings_delete_own"
  on public.portfolio_settings
  for delete
  using (owner_id = auth.uid());
