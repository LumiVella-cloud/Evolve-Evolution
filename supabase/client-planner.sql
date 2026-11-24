begin;
create table public.evolve_client_planner (
 user_id uuid not null references auth.users(id) on delete cascade,
 day date not null,
 intention text not null default '' check(char_length(intention)<=500),
 movement_plan text not null default '' check(char_length(movement_plan)<=500),
 meal_plan text not null default '' check(char_length(meal_plan)<=1000),
 reflection text not null default '' check(char_length(reflection)<=2000),
 primary key(user_id,day)
);
alter table public.evolve_client_planner enable row level security;
revoke all on public.evolve_client_planner from public,anon,authenticated;
grant select,insert,update on public.evolve_client_planner to authenticated;
create policy "own planner read" on public.evolve_client_planner for select to authenticated using ((select auth.uid())=user_id);
create policy "own planner insert" on public.evolve_client_planner for insert to authenticated with check ((select auth.uid())=user_id);
create policy "own planner update" on public.evolve_client_planner for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
commit;
