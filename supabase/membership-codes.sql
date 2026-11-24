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
create function public.evolve_redeem_code(p_code text) returns text language plpgsql security definer set search_path='' as $$
declare c public.evolve_access_codes%rowtype; u uuid:=auth.uid();
begin
if u is null or not exists(select 1 from auth.users where id=u and email_confirmed_at is not null) then raise exception 'Verified account required'; end if;
select * into c from public.evolve_access_codes where code=upper(trim(p_code)) for update;
if not found or not c.active or (c.expires_at is not null and c.expires_at<=now()) then raise exception 'Code unavailable'; end if;
if exists(select 1 from public.evolve_code_redemptions where code_id=c.id and user_id=u) then raise exception 'Code already redeemed'; end if;
if (select count(*) from public.evolve_code_redemptions where code_id=c.id)>=c.max_uses then raise exception 'Code unavailable'; end if;
insert into public.evolve_code_redemptions(code_id,user_id,kind,discount_percent,valid_until) values(c.id,u,c.kind,c.discount_percent,now()+make_interval(days=>c.duration_days));
return c.kind;
end $$;
create function public.evolve_has_premium() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.evolve_code_redemptions where user_id=auth.uid() and kind in ('grant','ambassador','sponsored','premium') and valid_until>now()) $$;
revoke all on function public.evolve_redeem_code(text),public.evolve_has_premium() from public,anon,authenticated;
grant execute on function public.evolve_redeem_code(text),public.evolve_has_premium() to authenticated;
alter table public.evolve_member_content add column premium boolean not null default false;
drop policy "published member content" on public.evolve_member_content;
create policy "published entitled content" on public.evolve_member_content for select to authenticated using(published and (not premium or public.evolve_has_premium()));
commit;