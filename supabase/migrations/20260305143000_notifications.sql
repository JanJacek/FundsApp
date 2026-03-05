-- In-app monthly notifications
-- Includes user opt-out setting stored in user_profiles.

alter table public.user_profiles
  add column if not exists monthly_notifications_enabled boolean not null default true;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz null,
  source text not null default 'monthly_job',
  cycle_month date not null,

  constraint notifications_cycle_month_is_month_end_chk check (
    cycle_month = ((date_trunc('month', cycle_month)::date + interval '1 month - 1 day')::date)
  )
);

create unique index if not exists uq_notifications_user_cycle_source
  on public.notifications (user_id, cycle_month, source);

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_read
  on public.notifications (user_id, read_at);

create or replace function public.notifications_restrict_update()
returns trigger
language plpgsql
as $$
begin
  if new.user_id <> old.user_id
     or new.title <> old.title
     or new.body <> old.body
     or new.source <> old.source
     or new.cycle_month <> old.cycle_month
     or new.created_at <> old.created_at then
    raise exception 'Only read_at can be updated by user';
  end if;

  if new.read_at is null then
    raise exception 'read_at cannot be cleared';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notifications_restrict_update on public.notifications;
create trigger trg_notifications_restrict_update
before update on public.notifications
for each row
execute function public.notifications_restrict_update();

alter table public.notifications enable row level security;
alter table public.notifications force row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications
  for select
  using (user_id = auth.uid());

drop policy if exists "notifications_update_read_own" on public.notifications;
create policy "notifications_update_read_own"
  on public.notifications
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- No INSERT policy for anon/authenticated users.
-- service_role bypasses RLS and can insert from Edge Function.

create or replace function public.create_monthly_notifications(
  p_cycle_month date default null,
  p_title text default 'Miesięczne przypomnienie',
  p_body text default 'Uzupełnij dane portfela za bieżący miesiąc.',
  p_source text default 'monthly_job'
)
returns integer
language sql
security definer
set search_path = public, auth
as $$
  with normalized as (
    select
      coalesce(
        p_cycle_month,
        (date_trunc('month', timezone('Europe/Warsaw', now())::date)::date + interval '1 month - 1 day')::date
      ) as cycle_month,
      coalesce(nullif(trim(p_title), ''), 'Miesięczne przypomnienie') as title,
      coalesce(nullif(trim(p_body), ''), 'Uzupełnij dane portfela za bieżący miesiąc.') as body,
      coalesce(nullif(trim(p_source), ''), 'monthly_job') as source
  ),
  ins as (
    insert into public.notifications (user_id, title, body, source, cycle_month)
    select
      u.id as user_id,
      n.title,
      n.body,
      n.source,
      (date_trunc('month', n.cycle_month)::date + interval '1 month - 1 day')::date as cycle_month
    from auth.users u
    cross join normalized n
    left join public.user_profiles up on up.owner_id = u.id
    where coalesce(up.monthly_notifications_enabled, true) = true
    on conflict (user_id, cycle_month, source) do nothing
    returning 1
  )
  select count(*)::int from ins;
$$;

revoke all on function public.create_monthly_notifications(date, text, text, text) from public;
revoke all on function public.create_monthly_notifications(date, text, text, text) from anon;
revoke all on function public.create_monthly_notifications(date, text, text, text) from authenticated;
grant execute on function public.create_monthly_notifications(date, text, text, text) to service_role;
