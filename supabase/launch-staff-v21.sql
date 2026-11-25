-- Staging first. Synthetic identities; rollback all rows. No real member data changed.
begin;
set local statement_timeout='30s';
insert into auth.users(id,email,email_confirmed_at,aud,role,raw_app_meta_data,raw_user_meta_data)
select id,'v21-'||gen_random_uuid()||'@example.invalid',now(),'authenticated','authenticated','{}','{}'
from unnest(array['f2100000-0000-4000-8000-000000000001','f2100000-0000-4000-8000-000000000002','f2100000-0000-4000-8000-000000000003','f2100000-0000-4000-8000-000000000004']::uuid[]) id;
insert into public.evolve_staff_roles(user_id,role) values('f2100000-0000-4000-8000-000000000001','trainer');
insert into public.evolve_admins(user_id) values('f2100000-0000-4000-8000-000000000004');
insert into public.evolve_trainer_assignments(trainer_id,client_id,client_label,active) values('f2100000-0000-4000-8000-000000000001','f2100000-0000-4000-8000-000000000002','Synthetic active',true),('f2100000-0000-4000-8000-000000000001','f2100000-0000-4000-8000-000000000003','Synthetic inactive',false);
insert into public.evolve_assigned_programmes(trainer_id,client_id,title,instructions) values('f2100000-0000-4000-8000-000000000001','f2100000-0000-4000-8000-000000000002','Synthetic active','Test'),('f2100000-0000-4000-8000-000000000001','f2100000-0000-4000-8000-000000000003','Synthetic inactive','Test');
set local role authenticated;
select set_config('request.jwt.claim.sub','f2100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f2100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
do $$ begin
 if public.evolve_can_train(auth.uid(),'f2100000-0000-4000-8000-000000000002') or exists(select 1 from public.evolve_assigned_programmes where trainer_id=auth.uid()) then raise exception 'Trainer AAL1 bypass'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"f2100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
do $$ begin
 if not public.evolve_can_train(auth.uid(),'f2100000-0000-4000-8000-000000000002') or not exists(select 1 from public.evolve_assigned_programmes where trainer_id=auth.uid() and client_id='f2100000-0000-4000-8000-000000000002') then raise exception 'Active trainer access missing'; end if;
 if public.evolve_can_train(auth.uid(),'f2100000-0000-4000-8000-000000000003') or exists(select 1 from public.evolve_assigned_programmes where trainer_id=auth.uid() and client_id='f2100000-0000-4000-8000-000000000003') then raise exception 'Inactive assignment leak'; end if;
end $$;
select set_config('request.jwt.claim.sub','f2100000-0000-4000-8000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"f2100000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
do $$ begin if public.evolve_is_admin() then raise exception 'Admin AAL1 bypass'; end if; end $$;
select set_config('request.jwt.claims','{"sub":"f2100000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);
do $$ begin if not public.evolve_is_admin() then raise exception 'Admin AAL2 missing'; end if; end $$;
select 'PASS: populated trainer active/inactive assignment isolation and staff MFA claims' as verification;
rollback;
