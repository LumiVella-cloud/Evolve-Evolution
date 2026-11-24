begin;
create table public.evolve_access_codes(id uuid primary key default gen_random_uuid(),code text unique not null check(code ~ '^[A-Z0-9-]{8,80}$'),kind text not null check(kind in ('grant','discount','ambassador','sponsored','premium')),active boolean not null default true,expires_at timestamptz,max_uses integer not null check(max_uses between 1 and 100000),duration_days integer not null check(duration_days between 1 and 3650),discount_percent integer check(discount_percent between 1 and 100),check((kind='discount')=(discount_percent is not null)));
create table public.evolve_code_redemptions(code_id uuid references public.evolve_access_codes(id),user_id uuid references auth.users(id) on delete cascade,kind text not null,discount_percent integer,redeemed_at timestamptz not null default now(),valid_until timestamptz not null,primary key(code_id,user_id));
alter table public.evolve_access_codes enable row level security;
alter table public.evolve_code_redemptions enable row level security;
revoke all on public.evolve_access_codes,public.evolve_code_redemptions from public,anon,authenticated;
grant select,insert,update on public.evolve_access_codes to authenticated;
grant select on public.evolve_code_redemptions to authenticated;
create policy "admin codes" on public.evolve_access_codes for all to authenticated using(public.evolve_is_admin()) with check(public.evolve_is_admin());
create policy "own or admin redemptions" on public.evolve_code_redemptions for select to authenticated using(user_id=auth.uid() or public.evolve_is_admin());
create policy "verified account required" on public.evolve_access_codes as restrictive for all to authenticated using(public.evolve_verified()) with check(public.evolve_verified());
create policy "verified account required" on public.evolve_code_redemptions as restrictive for all to authenticated using(public.evolve_verified()) with check(public.evolve_verified());
create table public.evolve_code_attempts(user_id uuid primary key references auth.users(id) on delete cascade, window_start timestamptz not null, attempts integer not null);
alter table public.evolve_code_attempts enable row level security;
revoke all on public.evolve_code_attempts from public,anon,authenticated;
create function public.evolve_redeem_code(p_code text) returns text language plpgsql security definer set search_path='' as $$
declare c public.evolve_access_codes%rowtype; u uuid:=auth.uid(); n integer;
begin
if not public.evolve_verified() then raise exception 'Verified account required'; end if;
insert into public.evolve_code_attempts as a(user_id,window_start,attempts) values(u,now(),1)
on conflict(user_id) do update set attempts=case when a.window_start<=now()-interval '15 minutes' then 1 else least(a.attempts+1,11) end,window_start=case when a.window_start<=now()-interval '15 minutes' then now() else a.window_start end returning attempts into n;
if n>10 then return 'Rate limit exceeded'; end if;
if p_code is null or length(p_code)>80 then return 'Code unavailable'; end if;
select * into c from public.evolve_access_codes where code=upper(trim(p_code)) for update;
if not found or not c.active or (c.expires_at is not null and c.expires_at<=now()) then return 'Code unavailable'; end if;
if exists(select 1 from public.evolve_code_redemptions where code_id=c.id and user_id=u) then return 'Code unavailable'; end if;
if (select count(*) from public.evolve_code_redemptions where code_id=c.id)>=c.max_uses then return 'Code unavailable'; end if;
insert into public.evolve_code_redemptions(code_id,user_id,kind,discount_percent,valid_until) values(c.id,u,c.kind,c.discount_percent,now()+make_interval(days=>c.duration_days));
return c.kind;
end $$;
create function public.evolve_has_premium() returns boolean language sql stable security definer set search_path='' as $$ select public.evolve_verified() and exists(select 1 from public.evolve_code_redemptions where user_id=auth.uid() and kind in ('grant','ambassador','sponsored','premium') and valid_until>now()) $$;
revoke all on function public.evolve_redeem_code(text),public.evolve_has_premium() from public,anon,authenticated;
grant execute on function public.evolve_redeem_code(text),public.evolve_has_premium() to authenticated;
alter table public.evolve_member_content add column premium boolean not null default false;
-- Keep V13 published verified-member content policy unchanged.
commit;