begin;
insert into storage.buckets(id,name,public) values ('evolve-member-media','evolve-member-media',false);
create table public.evolve_member_content (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(title) between 1 and 150),
 category text not null check(category in ('Fitness','Nutrition & Cooking','Mindset & Wellness','Podcasts')),
 description text not null default '',
 media_type text not null check(media_type in ('video','audio','pdf')),
 object_path text not null unique,
 published boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.evolve_content_progress (
 user_id uuid not null references auth.users(id) on delete cascade,
 content_id uuid not null references public.evolve_member_content(id) on delete cascade,
 favourite boolean not null default false,
 completed boolean not null default false,
 primary key(user_id,content_id)
);
alter table public.evolve_member_content enable row level security;
alter table public.evolve_content_progress enable row level security;
revoke all on public.evolve_member_content,public.evolve_content_progress from public,anon,authenticated;
grant select on public.evolve_member_content to authenticated;
grant select,insert,update on public.evolve_content_progress to authenticated;
create policy "published member content" on public.evolve_member_content for select to authenticated using (published);
create policy "own content progress read" on public.evolve_content_progress for select to authenticated using (user_id=(select auth.uid()));
create policy "own content progress insert" on public.evolve_content_progress for insert to authenticated with check (user_id=(select auth.uid()) and exists(select 1 from public.evolve_member_content c where c.id=content_id and c.published));
create policy "own content progress update" on public.evolve_content_progress for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()) and exists(select 1 from public.evolve_member_content c where c.id=content_id and c.published));
create policy "published member media read" on storage.objects for select to authenticated using (bucket_id='evolve-member-media' and exists(select 1 from public.evolve_member_content c where c.object_path=name and c.published));
commit;