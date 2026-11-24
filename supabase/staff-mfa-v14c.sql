-- V14C: apply only after staff MFA enrollment and dashboard tests.
begin;
create or replace function public.evolve_has_admin_role() returns boolean
language sql stable security definer set search_path='' as $$
select public.evolve_verified() and exists(select 1 from public.evolve_admins where user_id=auth.uid())
$$;
revoke all on function public.evolve_has_admin_role() from public,anon;
grant execute on function public.evolve_has_admin_role() to authenticated;
create or replace function public.evolve_is_admin() returns boolean
language sql stable security definer set search_path='' as $$
select public.evolve_has_admin_role() and coalesce(auth.jwt()->>'aal','')='aal2'
$$;
create or replace function public.evolve_can_train(p_trainer uuid,p_client uuid) returns boolean
language sql stable security invoker set search_path='' as $$
select public.evolve_verified() and coalesce(auth.jwt()->>'aal','')='aal2' and p_trainer=auth.uid()
and exists(select 1 from public.evolve_staff_roles where user_id=p_trainer and role='trainer')
and exists(select 1 from public.evolve_trainer_assignments where trainer_id=p_trainer and client_id=p_client and active)
$$;
drop policy if exists "read own active trainer assignments" on public.evolve_trainer_assignments;
create policy "read own active trainer assignments" on public.evolve_trainer_assignments for select to authenticated using (
trainer_id=auth.uid() and active and coalesce(auth.jwt()->>'aal','')='aal2'
and exists(select 1 from public.evolve_staff_roles r where r.user_id=auth.uid() and r.role='trainer'));
commit;
