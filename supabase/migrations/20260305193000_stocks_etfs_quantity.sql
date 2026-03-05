-- Add quantity to stocks and ETFs, and align generated profit/loss to total position value.

alter table public.stocks_positions
  add column if not exists quantity int not null default 1;

alter table public.stocks_positions
  drop constraint if exists stocks_positions_quantity_positive_chk;

alter table public.stocks_positions
  add constraint stocks_positions_quantity_positive_chk check (quantity > 0);

alter table public.stocks_positions
  drop column if exists profit_loss;

alter table public.stocks_positions
  add column profit_loss numeric(18,2)
  generated always as ((current_price - opening_price) * quantity) stored;

alter table public.etfs_positions
  add column if not exists quantity int not null default 1;

alter table public.etfs_positions
  drop constraint if exists etfs_positions_quantity_positive_chk;

alter table public.etfs_positions
  add constraint etfs_positions_quantity_positive_chk check (quantity > 0);

alter table public.etfs_positions
  drop column if exists profit_loss;

alter table public.etfs_positions
  add column profit_loss numeric(18,2)
  generated always as ((current_price - opening_price) * quantity) stored;
