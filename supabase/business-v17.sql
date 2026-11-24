begin;
-- Owner-only cancellation; payment status is deliberately untouched.
create or replace function public.evolve_cancel_private(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.evolve_verified() then raise exception 'Verified account required'; end if;
 update public.evolve_private_sessions set status='cancelled'
 where id=p_id and user_id=auth.uid() and status in ('requested','confirmed') and requested_at>now();
 if not found then raise exception 'Session unavailable for cancellation'; end if;
end $$;
revoke all on function public.evolve_cancel_private(uuid) from public,anon;
grant execute on function public.evolve_cancel_private(uuid) to authenticated;
-- Serialize confirmations for the same requested start time. No duration is assumed.
create or replace function public.evolve_private_slot_guard()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='confirmed' and (tg_op='INSERT' or old.status is distinct from new.status or old.requested_at is distinct from new.requested_at) then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.requested_at::text,1701));
  if exists(select 1 from public.evolve_private_sessions p where p.id<>new.id and p.status='confirmed' and p.requested_at=new.requested_at) then
   raise exception 'Another private session is confirmed at this start time';
  end if;
 end if;
 return new;
end $$;
revoke all on function public.evolve_private_slot_guard() from public,anon,authenticated;
drop trigger if exists evolve_private_slot_guard on public.evolve_private_sessions;
create trigger evolve_private_slot_guard before insert or update of status,requested_at on public.evolve_private_sessions for each row execute function public.evolve_private_slot_guard();
-- A unique index also protects against concurrent confirmations and timezone formatting differences.
create unique index if not exists evolve_private_confirmed_start_unique on public.evolve_private_sessions(requested_at) where status='confirmed';
commit;