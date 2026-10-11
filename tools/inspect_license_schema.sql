-- Read-only. Run in Supabase SQL Editor and share the results (no secrets).
select n.nspname as schema_name, p.proname,
       pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('redeem_product_key', 'get_my_entitlement');

select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;

select c.relname as table_name, con.conname,
       pg_get_constraintdef(con.oid) as definition
from pg_constraint con join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
order by c.relname, con.conname;
