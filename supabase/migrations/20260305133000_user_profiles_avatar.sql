-- User profile data (avatar initials)

create table if not exists public.user_profiles (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  avatar_initials text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_profiles_avatar_initials_chk check (
    avatar_initials is null or avatar_initials ~ '^[A-Z]{1,2}$'
  )
);

drop trigger if exists trg_user_profiles_set_updated_at on public.user_profiles;
create trigger trg_user_profiles_set_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

alter table public.user_profiles enable row level security;
alter table public.user_profiles force row level security;

create policy "user_profiles_select_own"
  on public.user_profiles
  for select
  using (owner_id = auth.uid());

create policy "user_profiles_insert_own"
  on public.user_profiles
  for insert
  with check (owner_id = auth.uid());

create policy "user_profiles_update_own"
  on public.user_profiles
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "user_profiles_delete_own"
  on public.user_profiles
  for delete
  using (owner_id = auth.uid());
