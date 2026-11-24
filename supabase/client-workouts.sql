begin;
create table public.evolve_client_workouts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 day_number integer not null check(day_number between 1 and 30),
 exercise text not null check(char_length(exercise) between 1 and 100),
 sets integer not null check(sets between 1 and 100),
 reps integer not null check(reps between 1 and 1000),
 weight_kg numeric(7,2) check(weight_kg between 0 and 2000),
 completed_on date,
 created_at timestamptz not null default now()
);
alter table public.evolve_client_workouts enable row level security;
revoke all on public.evolve_client_workouts from public,anon,authenticated;
grant select,insert,update,delete on public.evolve_client_workouts to authenticated;
create policy "own workouts read" on public.evolve_client_workouts for select to authenticated using ((select auth.uid())=user_id);
create policy "own workouts insert" on public.evolve_client_workouts for insert to authenticated with check ((select auth.uid())=user_id);
create policy "own workouts update" on public.evolve_client_workouts for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "own workouts delete" on public.evolve_client_workouts for delete to authenticated using ((select auth.uid())=user_id);
create index evolve_workouts_owner_day on public.evolve_client_workouts(user_id,day_number);
commit;