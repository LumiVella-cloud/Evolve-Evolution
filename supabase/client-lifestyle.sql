begin;
create table public.evolve_client_lifestyle (
 user_id uuid not null references auth.users(id) on delete cascade,
 day date not null,
 water_ml integer not null default 0 check(water_ml between 0 and 20000),
 water_goal_ml integer check(water_goal_ml between 1 and 20000),
 sleep_hours numeric(4,2) check(sleep_hours between 0 and 24),
 mood integer check(mood between 1 and 5),
 energy integer check(energy between 1 and 5),
 stress integer check(stress between 1 and 5),
 self_care boolean not null default false,
 notes text not null default '' check(char_length(notes)<=1000),
 primary key(user_id,day)
);
alter table public.evolve_client_lifestyle enable row level security;
revoke all on public.evolve_client_lifestyle from public,anon,authenticated;
grant select,insert,update,delete on public.evolve_client_lifestyle to authenticated;
create policy "own lifestyle select" on public.evolve_client_lifestyle for select to authenticated using ((select auth.uid())=user_id) ;
create policy "own lifestyle insert" on public.evolve_client_lifestyle for insert to authenticated  with check ((select auth.uid())=user_id);
create policy "own lifestyle update" on public.evolve_client_lifestyle for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "own lifestyle delete" on public.evolve_client_lifestyle for delete to authenticated using ((select auth.uid())=user_id) ;
commit;