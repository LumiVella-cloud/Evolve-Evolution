begin;
create table public.evolve_client_measurements (
 user_id uuid not null references auth.users(id) on delete cascade,
 day date not null,
 weight numeric(6,2) check(weight>0 and weight<=500),
 waist numeric(6,2) check(waist>0 and waist<=350),
 hips numeric(6,2) check(hips>0 and hips<=350),
 chest numeric(6,2) check(chest>0 and chest<=350),
 thigh numeric(6,2) check(thigh>0 and thigh<=250),
 arm numeric(6,2) check(arm>0 and arm<=200),
 neck numeric(6,2) check(neck>0 and neck<=150),
 glutes numeric(6,2) check(glutes>0 and glutes<=350),
 notes text not null default '' check(char_length(notes)<=1000),
 primary key(user_id,day)
);
alter table public.evolve_client_measurements enable row level security;
revoke all on public.evolve_client_measurements from public,anon,authenticated;
grant select,insert,update,delete on public.evolve_client_measurements to authenticated;
create policy "own measurements select" on public.evolve_client_measurements for select to authenticated using ((select auth.uid())=user_id) ;
create policy "own measurements insert" on public.evolve_client_measurements for insert to authenticated  with check ((select auth.uid())=user_id);
create policy "own measurements update" on public.evolve_client_measurements for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "own measurements delete" on public.evolve_client_measurements for delete to authenticated using ((select auth.uid())=user_id) ;
commit;