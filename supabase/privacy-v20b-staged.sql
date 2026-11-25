-- V20B additive migration. Review on staging first. No existing rows backfilled.
begin;
create table public.evolve_legal_acknowledgements (
 user_id uuid not null references auth.users(id) on delete cascade,
 notice_version text not null check (notice_version = '2026-11-v20b-draft'),
 acknowledged_at timestamptz not null default now(),
 primary key (user_id, notice_version)
);
alter table public.evolve_legal_acknowledgements enable row level security;
revoke all on public.evolve_legal_acknowledgements from public, anon, authenticated;
grant select on public.evolve_legal_acknowledgements to authenticated;
create policy "own legal acknowledgement" on public.evolve_legal_acknowledgements for select to authenticated using (user_id = auth.uid() and public.evolve_verified());
create function public.evolve_acknowledge_legal(p_version text)
returns void language plpgsql security definer set search_path to '' as $$
begin
 if not public.evolve_verified() then raise exception 'Verified account required'; end if;
 if p_version is distinct from '2026-11-v20b-draft' then raise exception 'Unsupported notice version'; end if;
 insert into public.evolve_legal_acknowledgements(user_id,notice_version)
 values(auth.uid(),p_version) on conflict do nothing;
end;
$$;
revoke all on function public.evolve_acknowledge_legal(text) from public, anon, authenticated;
grant execute on function public.evolve_acknowledge_legal(text) to authenticated;
commit;
-- This records a verified user's explicit acknowledgement of the existing draft only.
-- Not health consent, not marketing consent, not proof of reading.
-- Frontend integration intentionally deferred until notice approval/versioning.
