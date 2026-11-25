-- Run on staging first. Synthetic auth rows; no emails sent by this script.
-- Rollback removes rows; identity sequence gaps may remain. Custom auth triggers may have external effects.
begin;
set local statement_timeout='30s';
insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role)
values ('f20d0000-0000-4000-8000-000000000001','v20d-'||gen_random_uuid()||'@example.invalid',now(),'{}','{}','authenticated','authenticated'),
('f20d0000-0000-4000-8000-000000000002','v20d-'||gen_random_uuid()||'@example.invalid',now(),'{}','{}','authenticated','authenticated');
set local role authenticated;
select set_config('request.jwt.claim.sub','f20d0000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f20d0000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
do $$
declare v text:='2026-11-v20c-draft'; n integer; rid uuid;
begin
 if not public.evolve_verified() then raise exception 'Synthetic account not verified'; end if;
 if public.evolve_wellness_allowed() then raise exception 'Missing declarations bypass'; end if;
 begin
 insert into public.evolve_client_profiles(user_id,display_name,wellness_goal) values(auth.uid(),'Synthetic test','Synthetic goal');
 raise exception 'Unexpected insert success';
 exception when insufficient_privilege then null; end;
 perform public.evolve_privacy_record('legal',v,true);
 if public.evolve_wellness_allowed() then raise exception 'Legal alone bypass'; end if;
 perform public.evolve_privacy_record('adult',v,true);
 if public.evolve_wellness_allowed() then raise exception 'Missing wellness bypass'; end if;
 perform public.evolve_privacy_record('wellness',v,true);
 if not public.evolve_wellness_allowed() then raise exception 'Consent failed'; end if;
 insert into public.evolve_client_profiles(user_id,display_name,wellness_goal) values(auth.uid(),'Synthetic test','Synthetic goal');
 if not exists(select 1 from public.evolve_client_profiles where user_id=auth.uid()) then raise exception 'Own read failed'; end if;
 insert into public.evolve_client_habits(user_id,day,movement) values(auth.uid(),current_date,true);
 insert into public.evolve_client_planner(user_id,day,intention) values(auth.uid(),current_date,'Synthetic');
 insert into public.evolve_client_workouts(user_id,day_number,exercise,sets,reps) values(auth.uid(),1,'Synthetic',1,1);
 insert into public.evolve_client_meals(user_id,day,meal_type,meal) values(auth.uid(),current_date,'Breakfast','Synthetic');
 insert into public.evolve_client_measurements(user_id,day,weight) values(auth.uid(),current_date,70);
 insert into public.evolve_client_lifestyle(user_id,day,water_ml) values(auth.uid(),current_date,100);
 if not exists(select 1 from public.evolve_client_habits where user_id=auth.uid()) then raise exception 'habits: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_planner where user_id=auth.uid()) then raise exception 'planner: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_workouts where user_id=auth.uid()) then raise exception 'workouts: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_meals where user_id=auth.uid()) then raise exception 'meals: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_measurements where user_id=auth.uid()) then raise exception 'measurements: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_lifestyle where user_id=auth.uid()) then raise exception 'lifestyle: own read failed'; end if;
 perform public.evolve_privacy_record('wellness',v,false);
 if exists(select 1 from public.evolve_client_habits where user_id=auth.uid()) then raise exception 'habits: withdrawal leak'; end if;
 if exists(select 1 from public.evolve_client_planner where user_id=auth.uid()) then raise exception 'planner: withdrawal leak'; end if;
 if exists(select 1 from public.evolve_client_workouts where user_id=auth.uid()) then raise exception 'workouts: withdrawal leak'; end if;
 if exists(select 1 from public.evolve_client_meals where user_id=auth.uid()) then raise exception 'meals: withdrawal leak'; end if;
 if exists(select 1 from public.evolve_client_measurements where user_id=auth.uid()) then raise exception 'measurements: withdrawal leak'; end if;
 if exists(select 1 from public.evolve_client_lifestyle where user_id=auth.uid()) then raise exception 'lifestyle: withdrawal leak'; end if;
 if public.evolve_wellness_allowed() or exists(select 1 from public.evolve_client_profiles where user_id=auth.uid()) then raise exception 'Withdrawal read bypass'; end if;
 update public.evolve_client_profiles set display_name='Unexpected' where user_id=auth.uid();
 get diagnostics n=row_count; if n<>0 then raise exception 'Withdrawal update bypass'; end if;
 begin
 delete from public.evolve_client_profiles where user_id=auth.uid();
 get diagnostics n=row_count; if n<>0 then raise exception 'Withdrawal delete bypass'; end if;
 exception when insufficient_privilege then null; end;
 perform public.evolve_privacy_request('deletion');
 perform public.evolve_privacy_request('deletion');
 select count(*) into n from public.evolve_privacy_requests where user_id=auth.uid() and kind='deletion';
 if n<>1 then raise exception 'Duplicate or missing request'; end if;
 select id into rid from public.evolve_privacy_requests where user_id=auth.uid() and kind='deletion';
 begin
 perform public.evolve_privacy_review(rid,'closed');
 raise exception 'Unexpected review success';
 exception when raise_exception then if sqlerrm <> 'Administrator MFA required' then raise; end if; end;
 perform public.evolve_privacy_record('wellness',v,true);
 if not exists(select 1 from public.evolve_client_habits where user_id=auth.uid()) then raise exception 'habits: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_planner where user_id=auth.uid()) then raise exception 'planner: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_workouts where user_id=auth.uid()) then raise exception 'workouts: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_meals where user_id=auth.uid()) then raise exception 'meals: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_measurements where user_id=auth.uid()) then raise exception 'measurements: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_lifestyle where user_id=auth.uid()) then raise exception 'lifestyle: own read failed'; end if;
 if not exists(select 1 from public.evolve_client_profiles where user_id=auth.uid() and display_name='Synthetic test') then raise exception 'Preservation failed'; end if;
end $$;
select set_config('request.jwt.claim.sub','f20d0000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"f20d0000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
do $$ begin
 perform public.evolve_privacy_record('legal','2026-11-v20c-draft',true);
 perform public.evolve_privacy_record('adult','2026-11-v20c-draft',true);
 perform public.evolve_privacy_record('wellness','2026-11-v20c-draft',true);
 if not public.evolve_wellness_allowed() then raise exception 'Second account consent failed'; end if;
 if exists(select 1 from public.evolve_client_profiles where user_id='f20d0000-0000-4000-8000-000000000001') or exists(select 1 from public.evolve_privacy_requests where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'Cross account leak'; end if;
 if exists(select 1 from public.evolve_client_habits where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'habits: cross-account leak'; end if;
 if exists(select 1 from public.evolve_client_planner where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'planner: cross-account leak'; end if;
 if exists(select 1 from public.evolve_client_workouts where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'workouts: cross-account leak'; end if;
 if exists(select 1 from public.evolve_client_meals where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'meals: cross-account leak'; end if;
 if exists(select 1 from public.evolve_client_measurements where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'measurements: cross-account leak'; end if;
 if exists(select 1 from public.evolve_client_lifestyle where user_id='f20d0000-0000-4000-8000-000000000001') then raise exception 'lifestyle: cross-account leak'; end if;
end $$;
select 'PASS: seven populated wellness tables: consent reads, withdrawal, preservation and cross-account isolation; profile write restrictions and privacy requests' as verification;
rollback;
