begin transaction read only;
select jsonb_build_object(
 'triggers', (select coalesce(jsonb_agg(jsonb_build_object('table',c.relname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid))), '[]'::jsonb) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname like 'evolve_%' and not t.tgisinternal),
 'private_indexes',(select coalesce(jsonb_agg(jsonb_build_object('name',indexname,'definition',indexdef)), '[]'::jsonb) from pg_indexes where schemaname='public' and tablename='evolve_private_sessions'),
 'booking_constraints',(select coalesce(jsonb_agg(jsonb_build_object('table',c.relname,'definition',pg_get_constraintdef(k.oid))), '[]'::jsonb) from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('evolve_bookings','evolve_private_sessions') and k.contype='c')
) as security_verification;
rollback;
