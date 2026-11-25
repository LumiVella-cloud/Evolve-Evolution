-- V20 read-only launch audit. Run in Supabase SQL editor as project owner.
-- No personal records, credentials, or mutations. Results require review.
begin transaction read only;
select c.relname as table_name,c.relrowsecurity as rls_enabled,
has_table_privilege('anon',c.oid,'SELECT') as anon_read,
has_table_privilege('anon',c.oid,'INSERT') as anon_insert,
has_table_privilege('anon',c.oid,'UPDATE') as anon_update,
has_table_privilege('anon',c.oid,'DELETE') as anon_delete,
has_any_column_privilege('anon',c.oid,'SELECT') as anon_column_read,
has_any_column_privilege('anon',c.oid,'INSERT') as anon_column_insert,
has_any_column_privilege('anon',c.oid,'UPDATE') as anon_column_update
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in ('r','p') and c.relname like 'evolve_%' order by 1;
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check from pg_policies
where (schemaname='public' and tablename like 'evolve_%') or (schemaname='storage' and tablename='objects') order by 1,2,3;
select p.proname,pg_get_function_identity_arguments(p.oid) as arguments,p.prosecdef,p.proconfig,
has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'evolve_%' order by 1,2;
select table_name,column_name,grantee,privilege_type from information_schema.column_privileges
where table_schema='public' and table_name in ('evolve_bookings','evolve_private_sessions') and grantee in ('anon','authenticated','PUBLIC') order by 1,2,3,4;
select id,public,file_size_limit,allowed_mime_types from storage.buckets where id='evolve-member-media';
rollback;
