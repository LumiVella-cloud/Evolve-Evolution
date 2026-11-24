begin;
create table public.evolve_client_meals (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 day date not null,
 meal_type text not null check(meal_type in ('Breakfast','Lunch','Dinner','Snack')),
 meal text not null check(char_length(meal) between 1 and 500),
 ingredients text not null default '' check(char_length(ingredients)<=2000),
 prepared boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.evolve_client_meals enable row level security;
revoke all on public.evolve_client_meals from public,anon,authenticated;
grant select,insert,update,delete on public.evolve_client_meals to authenticated;
create policy "own meals read" on public.evolve_client_meals for select to authenticated using ((select auth.uid())=user_id);
create policy "own meals insert" on public.evolve_client_meals for insert to authenticated with check ((select auth.uid())=user_id);
create policy "own meals update" on public.evolve_client_meals for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "own meals delete" on public.evolve_client_meals for delete to authenticated using ((select auth.uid())=user_id);
create index evolve_meals_owner_day on public.evolve_client_meals(user_id,day);
commit;