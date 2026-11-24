begin;
create table public.evolve_classes (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(title) between 1 and 120),
 instructor text not null default '',
 starts_at timestamptz not null,
 duration_minutes integer not null check(duration_minutes between 5 and 480),
 capacity integer not null check(capacity between 1 and 500),
 active boolean not null default true
);
create table public.evolve_bookings (
 class_id uuid not null references public.evolve_classes(id),
 user_id uuid not null references auth.users(id) on delete cascade,
 booked_at timestamptz not null default now(),
 cancelled_at timestamptz,
 primary key(class_id,user_id)
);
alter table public.evolve_classes enable row level security;
alter table public.evolve_bookings enable row level security;
revoke all on public.evolve_classes,public.evolve_bookings from public,anon,authenticated;
grant select on public.evolve_classes,public.evolve_bookings to authenticated;
create policy "members read classes" on public.evolve_classes for select to authenticated using (true);
create policy "own bookings read" on public.evolve_bookings for select to authenticated using (user_id=(select auth.uid()));
create function public.evolve_class_schedule() returns table(id uuid,title text,instructor text,starts_at timestamptz,duration_minutes integer,capacity integer,spaces bigint,booked boolean)
language sql security definer set search_path='' as $$
 select c.id,c.title,c.instructor,c.starts_at,c.duration_minutes,c.capacity,
 greatest(0,c.capacity-count(b.user_id) filter(where b.cancelled_at is null)),
 coalesce(bool_or(b.user_id=auth.uid() and b.cancelled_at is null),false)
 from public.evolve_classes c left join public.evolve_bookings b on b.class_id=c.id
 where auth.uid() is not null and c.active and c.starts_at>now()
 group by c.id order by c.starts_at limit 200
$$;
create function public.evolve_book_class(p_class uuid) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c public.evolve_classes%rowtype;
begin
 if u is null then raise exception 'Sign in required'; end if;
 select * into c from public.evolve_classes where id=p_class for update;
 if not found or not c.active or c.starts_at<=now() then raise exception 'Class unavailable'; end if;
 if exists(select 1 from public.evolve_bookings where class_id=p_class and user_id=u and cancelled_at is null) then return; end if;
 if (select count(*) from public.evolve_bookings where class_id=p_class and cancelled_at is null)>=c.capacity then raise exception 'Class is full'; end if;
 insert into public.evolve_bookings(class_id,user_id) values(p_class,u)
 on conflict(class_id,user_id) do update set cancelled_at=null,booked_at=now();
end $$;
create function public.evolve_cancel_class(p_class uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 perform 1 from public.evolve_classes where id=p_class and starts_at>now() for update;
 if not found then raise exception 'Class has already started or is unavailable'; end if;
 update public.evolve_bookings set cancelled_at=now() where class_id=p_class and user_id=auth.uid() and cancelled_at is null;
end $$;
revoke all on function public.evolve_class_schedule(),public.evolve_book_class(uuid),public.evolve_cancel_class(uuid) from public,anon,authenticated;
grant execute on function public.evolve_class_schedule(),public.evolve_book_class(uuid),public.evolve_cancel_class(uuid) to authenticated;
commit;