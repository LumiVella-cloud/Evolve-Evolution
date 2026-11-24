begin;
create table public.evolve_staff_roles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('trainer','admin'))
);
create table public.evolve_trainer_assignments (
 trainer_id uuid not null references public.evolve_staff_roles(user_id) on delete cascade,
 client_id uuid not null references auth.users(id) on delete cascade,
 client_label text not null check(char_length(client_label) between 1 and 120),
 active boolean not null default true,
 primary key(trainer_id,client_id),
 check(trainer_id<>client_id)
);
create table public.evolve_assigned_programmes (
 id uuid primary key default gen_random_uuid(),
 trainer_id uuid not null,
 client_id uuid not null,
 title text not null check(char_length(title) between 1 and 150),
 instructions text not null check(char_length(instructions) between 1 and 6000),
 created_at timestamptz not null default now(),
 foreign key(trainer_id,client_id) references public.evolve_trainer_assignments(trainer_id,client_id) on delete cascade
);
alter table public.evolve_staff_roles enable row level security;
alter table public.evolve_trainer_assignments enable row level security;
alter table public.evolve_assigned_programmes enable row level security;
revoke all on public.evolve_staff_roles,public.evolve_trainer_assignments,public.evolve_assigned_programmes from public,anon,authenticated;
grant select on public.evolve_staff_roles,public.evolve_trainer_assignments to authenticated;
grant select,insert,update,delete on public.evolve_assigned_programmes to authenticated;
create policy "read own staff role" on public.evolve_staff_roles for select to authenticated using (user_id=(select auth.uid()));
create policy "read own active trainer assignments" on public.evolve_trainer_assignments for select to authenticated using (trainer_id=(select auth.uid()) and active and exists(select 1 from public.evolve_staff_roles r where r.user_id=(select auth.uid()) and r.role='trainer'));
create function public.evolve_can_train(p_trainer uuid,p_client uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select p_trainer=auth.uid() and exists(select 1 from public.evolve_trainer_assignments a where a.trainer_id=p_trainer and a.client_id=p_client and a.active)
$$;
revoke all on function public.evolve_can_train(uuid,uuid) from public,anon,authenticated;
grant execute on function public.evolve_can_train(uuid,uuid) to authenticated;
create policy "client or assigned trainer reads programme" on public.evolve_assigned_programmes for select to authenticated using (client_id=(select auth.uid()) or public.evolve_can_train(trainer_id,client_id));
create policy "assigned trainer creates programme" on public.evolve_assigned_programmes for insert to authenticated with check (public.evolve_can_train(trainer_id,client_id));
create policy "assigned trainer edits programme" on public.evolve_assigned_programmes for update to authenticated using (public.evolve_can_train(trainer_id,client_id)) with check (public.evolve_can_train(trainer_id,client_id));
create policy "assigned trainer removes programme" on public.evolve_assigned_programmes for delete to authenticated using (public.evolve_can_train(trainer_id,client_id));
commit;