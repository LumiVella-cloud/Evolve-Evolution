-- Apply after V12. Transactional; preserves existing rows and prices.
begin;
create or replace function public.evolve_is_admin() returns boolean language sql stable security definer set search_path='' as $$ select public.evolve_verified() and exists(select 1 from public.evolve_admins where user_id=auth.uid()) $$;
create or replace function public.evolve_can_train(p_trainer uuid,p_client uuid) returns boolean language sql stable security invoker set search_path='' as $$ select public.evolve_verified() and p_trainer=auth.uid() and exists(select 1 from public.evolve_staff_roles where user_id=p_trainer and role='trainer') and exists(select 1 from public.evolve_trainer_assignments where trainer_id=p_trainer and client_id=p_client and active) $$;
-- Restrictive policy adds verification without widening any existing owner/admin policy.
do $$ declare t text; begin
foreach t in array array['evolve_client_profiles','evolve_client_habits','evolve_client_planner','evolve_client_workouts','evolve_client_meals','evolve_client_measurements','evolve_client_lifestyle','evolve_classes','evolve_bookings','evolve_member_content','evolve_content_progress','evolve_staff_roles','evolve_trainer_assignments','evolve_assigned_programmes','evolve_admins','evolve_contacts','evolve_consent_history','evolve_private_sessions','evolve_access_codes','evolve_code_redemptions'] loop
if to_regclass('public.'||t) is not null then
execute format('alter table public.%I enable row level security',t);
execute format('revoke all on public.%I from public,anon',t);
execute format('drop policy if exists "verified account required" on public.%I',t);
execute format('create policy "verified account required" on public.%I as restrictive for all to authenticated using ((select public.evolve_verified())) with check ((select public.evolve_verified()))',t);
end if; end loop; end $$;
drop policy if exists "published entitled content" on public.evolve_member_content;
drop policy if exists "published member content" on public.evolve_member_content;
create policy "published member content" on public.evolve_member_content for select to authenticated using(published and public.evolve_verified());
update storage.buckets set public=false where id='evolve-member-media';
drop policy if exists "published member media read" on storage.objects;
create policy "published member media read" on storage.objects for select to authenticated using(bucket_id='evolve-member-media' and public.evolve_verified() and exists(select 1 from public.evolve_member_content c where c.object_path=name and c.published));
drop policy if exists "verified evolve media" on storage.objects;
create policy "verified evolve media" on storage.objects as restrictive for all to authenticated using(bucket_id<>'evolve-member-media' or public.evolve_verified()) with check(bucket_id<>'evolve-member-media' or public.evolve_verified());
revoke all on function public.evolve_record_consent() from public,anon,authenticated;
create or replace function public.evolve_class_schedule() returns table(id uuid,title text,instructor text,starts_at timestamptz,duration_minutes integer,capacity integer,spaces bigint,booked boolean) language sql security definer set search_path='' as $$ select c.id,c.title,c.instructor,c.starts_at,c.duration_minutes,c.capacity,greatest(0,c.capacity-count(b.user_id) filter(where b.cancelled_at is null)),coalesce(bool_or(b.user_id=auth.uid() and b.cancelled_at is null),false) from public.evolve_classes c left join public.evolve_bookings b on b.class_id=c.id where public.evolve_verified() and c.active and c.starts_at>now() group by c.id order by c.starts_at limit 200 $$;
create or replace function public.evolve_book_class(p_class uuid) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c public.evolve_classes%rowtype;
begin
if not public.evolve_verified() then raise exception 'Verified account required'; end if;
select * into c from public.evolve_classes where id=p_class for update;
if not found or not c.active or c.starts_at<=now() then raise exception 'Class unavailable'; end if;
if exists(select 1 from public.evolve_bookings where class_id=p_class and user_id=u and cancelled_at is null) then return; end if;
if (select count(*) from public.evolve_bookings where class_id=p_class and cancelled_at is null)>=c.capacity then raise exception 'Class is full'; end if;
if exists(select 1 from public.evolve_bookings where class_id=p_class and user_id=u and payment_status='paid') then raise exception 'Contact administrator to reconcile your previous payment before rebooking'; end if;
insert into public.evolve_bookings(class_id,user_id) values(p_class,u) on conflict(class_id,user_id) do update set cancelled_at=null,booked_at=now(),payment_status='unpaid';
end $$;
create or replace function public.evolve_cancel_class(p_class uuid) returns void language plpgsql security definer set search_path='' as $$ begin
if not public.evolve_verified() then raise exception 'Verified account required'; end if;
perform 1 from public.evolve_classes where id=p_class and starts_at>now() for update;
if not found then raise exception 'Class has already started or is unavailable'; end if;
update public.evolve_bookings set cancelled_at=now() where class_id=p_class and user_id=auth.uid() and cancelled_at is null;
end $$;
-- Payment changes are logged, not actual money movements.
create table if not exists public.evolve_payment_audit(id bigint generated always as identity primary key,source_table text not null,record_key jsonb not null,old_status text not null,new_status text not null,actor uuid,changed_at timestamptz not null default now());
alter table public.evolve_payment_audit enable row level security;
revoke all on public.evolve_payment_audit from public,anon,authenticated;
grant select on public.evolve_payment_audit to authenticated;
drop policy if exists "admin payment audit" on public.evolve_payment_audit;
create policy "admin payment audit" on public.evolve_payment_audit for select to authenticated using(public.evolve_is_admin());
create or replace function public.evolve_log_payment() returns trigger language plpgsql security definer set search_path='' as $$ begin
if old.payment_status is distinct from new.payment_status then
insert into public.evolve_payment_audit(source_table,record_key,old_status,new_status,actor) values(tg_table_name,case when tg_table_name='evolve_bookings' then jsonb_build_object('class_id',to_jsonb(new)->'class_id','user_id',to_jsonb(new)->'user_id') else jsonb_build_object('id',to_jsonb(new)->'id') end,old.payment_status,new.payment_status,auth.uid());
end if;return new;end $$;
revoke all on function public.evolve_log_payment() from public,anon,authenticated;
drop trigger if exists evolve_payment_log on public.evolve_bookings;
create trigger evolve_payment_log after update of payment_status on public.evolve_bookings for each row execute function public.evolve_log_payment();
drop trigger if exists evolve_payment_log on public.evolve_private_sessions;
create trigger evolve_payment_log after update of payment_status on public.evolve_private_sessions for each row execute function public.evolve_log_payment();
commit;