-- Read-only audit: expect RLS enabled on both tables, three owner-only policies each,
-- no anonymous grants, and authenticated SELECT/INSERT/UPDATE only.
select relname, relrowsecurity from pg_class join pg_namespace n on n.oid=relnamespace where n.nspname='public' and relname in ('evolve_client_profiles','evolve_client_habits');
select tablename,policyname,roles,cmd,qual,with_check from pg_policies where schemaname='public' and tablename in ('evolve_client_profiles','evolve_client_habits') order by tablename,cmd;
select table_name,grantee,privilege_type from information_schema.role_table_grants where table_schema='public' and table_name in ('evolve_client_profiles','evolve_client_habits') and grantee in ('anon','authenticated','PUBLIC') order by table_name,grantee,privilege_type;
