-- Run in Supabase SQL Editor after reviewing. New isolated tables only.
begin;
create table public.evolve_client_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '' check (char_length(display_name)<=100),
 wellness_goal text not null default '' check (char_length(wellness_goal)<=500),
 updated_at timestamptz not null default now()
);
alter table public.evolve_client_profiles enable row level security;
revoke all on public.evolve_client_profiles from anon, authenticated;
grant select,insert,update on public.evolve_client_profiles to authenticated;
create policy "own profile read" on public.evolve_client_profiles for select to authenticated using ((select auth.uid())=user_id);
create policy "own profile insert" on public.evolve_client_profiles for insert to authenticated with check ((select auth.uid())=user_id);
create policy "own profile update" on public.evolve_client_profiles for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create table public.evolve_client_habits (
 user_id uuid not null references auth.users(id) on delete cascade,
 day date not null,
 movement boolean not null default false,
 hydration boolean not null default false,
 nourishment boolean not null default false,
 rest boolean not null default false,
 primary key(user_id,day)
);
alter table public.evolve_client_habits enable row level security;
revoke all on public.evolve_client_habits from anon, authenticated;
grant select,insert,update on public.evolve_client_habits to authenticated;
create policy "own habits read" on public.evolve_client_habits for select to authenticated using ((select auth.uid())=user_id);
create policy "own habits insert" on public.evolve_client_habits for insert to authenticated with check ((select auth.uid())=user_id);
create policy "own habits update" on public.evolve_client_habits for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
commit;
-- No trainer/admin privileges, payment or access-code changes in this migration.
