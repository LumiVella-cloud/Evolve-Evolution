-- V20C phase 1: additive privacy controls. Supersedes uninstalled V20B staged migration.
begin;
create table public.evolve_privacy_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('legal','adult','wellness')),
 version text not null,
 accepted boolean not null,
 recorded_at timestamptz not null default clock_timestamp()
);
create index evolve_privacy_events_lookup on public.evolve_privacy_events(user_id,kind,id desc);
create table public.evolve_privacy_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('access','correction','deletion','objection','other')),
 status text not null default 'received' check(status in ('received','reviewing','closed')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 reviewed_by uuid
);
create unique index evolve_privacy_one_open on public.evolve_privacy_requests(user_id,kind) where status <> 'closed';
alter table public.evolve_privacy_events enable row level security;
alter table public.evolve_privacy_requests enable row level security;
revoke all on public.evolve_privacy_events,public.evolve_privacy_requests from public,anon,authenticated;
grant select on public.evolve_privacy_events,public.evolve_privacy_requests to authenticated;
create policy privacy_events_own on public.evolve_privacy_events for select to authenticated using (user_id=auth.uid() and public.evolve_verified());
create policy privacy_requests_read on public.evolve_privacy_requests for select to authenticated using (public.evolve_verified() and (user_id=auth.uid() or public.evolve_is_admin()));
create function public.evolve_privacy_record(p_kind text,p_version text,p_accepted boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.evolve_verified() then raise exception 'Verified account required'; end if;
 if p_version is distinct from '2026-11-v20c-draft' or p_kind is null or p_kind not in ('legal','adult','wellness') or p_accepted is null or (p_kind <> 'wellness' and not p_accepted) then raise exception 'Invalid declaration'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,20));
 if (select e.accepted from public.evolve_privacy_events e where e.user_id=auth.uid() and e.kind=p_kind and e.version=p_version order by e.id desc limit 1) is distinct from p_accepted then
 insert into public.evolve_privacy_events(user_id,kind,version,accepted) values(auth.uid(),p_kind,p_version,p_accepted);
 end if;
end; $$;
create function public.evolve_privacy_request(p_kind text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.evolve_verified() then raise exception 'Verified account required'; end if;
 insert into public.evolve_privacy_requests(user_id,kind) values(auth.uid(),p_kind) on conflict (user_id,kind) where status <> 'closed' do nothing;
end; $$;
create function public.evolve_privacy_review(p_id uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.evolve_is_admin() then raise exception 'Administrator MFA required'; end if;
 if p_status is null or p_status not in ('reviewing','closed') then raise exception 'Invalid status'; end if;
 update public.evolve_privacy_requests set status=p_status,updated_at=now(),reviewed_by=auth.uid() where id=p_id and status <> 'closed';
 if not found then raise exception 'Open request not found'; end if;
end; $$;
revoke all on function public.evolve_privacy_record(text,text,boolean),public.evolve_privacy_request(text),public.evolve_privacy_review(uuid,text) from public,anon,authenticated;
grant execute on function public.evolve_privacy_record(text,text,boolean),public.evolve_privacy_request(text),public.evolve_privacy_review(uuid,text) to authenticated;
commit;
-- No automatic deletion, no consent backfill, no existing policy changes.
