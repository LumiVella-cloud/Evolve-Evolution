-- V20D: run after V20C, staging first. No existing data changed.
begin;
create function public.evolve_wellness_allowed() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce(public.evolve_verified(),false) and
 coalesce((select accepted from public.evolve_privacy_events where user_id=auth.uid() and kind='legal' and version='2026-11-v20c-draft' order by id desc limit 1),false) and
 coalesce((select accepted from public.evolve_privacy_events where user_id=auth.uid() and kind='adult' and version='2026-11-v20c-draft' order by id desc limit 1),false) and
 coalesce((select accepted from public.evolve_privacy_events where user_id=auth.uid() and kind='wellness' and version='2026-11-v20c-draft' order by id desc limit 1),false);
$$;
revoke all on function public.evolve_wellness_allowed() from public,anon,authenticated;
grant execute on function public.evolve_wellness_allowed() to authenticated;
do $$
declare t text;
begin
 foreach t in array array['evolve_client_profiles','evolve_client_habits','evolve_client_planner','evolve_client_workouts','evolve_client_meals','evolve_client_measurements','evolve_client_lifestyle'] loop
 execute format('create policy wellness_consent_gate on public.%I as restrictive for all to authenticated using ((select public.evolve_wellness_allowed())) with check ((select public.evolve_wellness_allowed()))',t);
 end loop;
end $$;
commit;
-- Existing owner policies remain required. No grant changes. No data deletion.
-- Withdrawal blocks subsequent statements; in-flight requests and previously downloaded data cannot be recalled.
-- Rights requests remain accessible. Privileged service/owner roles bypass RLS and require operational controls.
-- Rollback only after approved alternative safeguards: drop the seven wellness_consent_gate policies, then drop function.
