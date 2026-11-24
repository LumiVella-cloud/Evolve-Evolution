begin;
create table public.evolve_admins(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.evolve_admins enable row level security;
revoke all on public.evolve_admins from public,anon,authenticated;
grant select on public.evolve_admins to authenticated;
create policy "own admin status" on public.evolve_admins for select to authenticated using(user_id=auth.uid());
create function public.evolve_is_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.evolve_admins where user_id=auth.uid()) $$;
revoke all on function public.evolve_is_admin() from public,anon,authenticated;
grant execute on function public.evolve_is_admin() to authenticated;
create function public.evolve_admin_users() returns table(id uuid,email text,trainer boolean) language plpgsql security definer set search_path='' as $$ begin
if not public.evolve_is_admin() then raise exception 'Admin required'; end if;
return query select u.id,u.email::text,exists(select 1 from public.evolve_staff_roles r where r.user_id=u.id and r.role='trainer') from auth.users u where u.email_confirmed_at is not null order by u.email;
end $$;
create function public.evolve_admin_trainer(p_user uuid,p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$ begin
if not public.evolve_is_admin() then raise exception 'Admin required'; end if;
if p_enabled then insert into public.evolve_staff_roles(user_id,role) select id,'trainer' from auth.users where id=p_user and email_confirmed_at is not null on conflict(user_id) do update set role='trainer';
else update public.evolve_trainer_assignments set active=false where trainer_id=p_user; delete from public.evolve_staff_roles where user_id=p_user and role='trainer' and not exists(select 1 from public.evolve_trainer_assignments where trainer_id=p_user); if exists(select 1 from public.evolve_staff_roles where user_id=p_user and role='trainer') then raise exception 'Deactivate assignments and preserve trainer role until archival support is available'; end if; end if;
end $$;
revoke all on function public.evolve_admin_users(),public.evolve_admin_trainer(uuid,boolean) from public,anon,authenticated;
grant execute on function public.evolve_admin_users(),public.evolve_admin_trainer(uuid,boolean) to authenticated;
grant select,insert,update on public.evolve_trainer_assignments,public.evolve_classes,public.evolve_member_content to authenticated;
create policy "admin assignments" on public.evolve_trainer_assignments for all to authenticated using(public.evolve_is_admin()) with check(public.evolve_is_admin());
create policy "admin classes" on public.evolve_classes for all to authenticated using(public.evolve_is_admin()) with check(public.evolve_is_admin());
create policy "admin content" on public.evolve_member_content for all to authenticated using(public.evolve_is_admin()) with check(public.evolve_is_admin());
create policy "admin booking read" on public.evolve_bookings for select to authenticated using(public.evolve_is_admin());
create policy "admin media upload" on storage.objects for insert to authenticated with check(bucket_id='evolve-member-media' and public.evolve_is_admin());
create policy "admin media read" on storage.objects for select to authenticated using(bucket_id='evolve-member-media' and public.evolve_is_admin());
create function public.evolve_admin_class_update(p_id uuid,p_capacity integer,p_active boolean) returns void language plpgsql security definer set search_path='' as $$ begin
if not public.evolve_is_admin() then raise exception 'Admin required'; end if;
perform 1 from public.evolve_classes where id=p_id for update;
if not found then raise exception 'Class not found'; end if;
if p_capacity<(select count(*) from public.evolve_bookings where class_id=p_id and cancelled_at is null) then raise exception 'Capacity below reservations'; end if;
update public.evolve_classes set capacity=p_capacity,active=p_active where id=p_id;
end $$;
revoke all on function public.evolve_admin_class_update(uuid,integer,boolean) from public,anon,authenticated;
grant execute on function public.evolve_admin_class_update(uuid,integer,boolean) to authenticated;
revoke update on public.evolve_classes from authenticated;
commit;