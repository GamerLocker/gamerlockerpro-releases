-- Switches the app RPCs to a new license ledger. Old tables remain for audit,
-- but their entitlements and keys are not imported. Apply once in SQL Editor.
begin;

create table public.gamerlocker_licenses (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pro_until timestamptz,
  is_lifetime boolean not null default false,
  check (not is_lifetime or pro_until is null)
);
create table public.gamerlocker_product_keys (
  key_hash text primary key check (key_hash ~ '^[0-9a-f]{64}$'),
  duration_days integer,
  is_lifetime boolean not null default false,
  disabled boolean not null default false,
  redeem_before timestamptz,
  label text,
  redeemed_by uuid references auth.users(id),
  redeemed_at timestamptz,
  check ((is_lifetime and duration_days is null) or
         (not is_lifetime and duration_days is not null and duration_days between 1 and 36500)),
  check ((redeemed_by is null) = (redeemed_at is null))
);
alter table public.gamerlocker_licenses enable row level security;
alter table public.gamerlocker_product_keys enable row level security;
revoke all on public.gamerlocker_licenses, public.gamerlocker_product_keys from anon, authenticated;

-- No CASCADE: fail atomically if an unexpected database dependency exists.
drop function if exists public.redeem_product_key(text);
drop function if exists public.get_my_entitlement();

create function public.get_my_entitlement()
returns table(plan text, pro_until timestamptz, is_lifetime boolean)
language sql stable security definer set search_path = pg_catalog
as $$
  select case when coalesce(l.is_lifetime, false) or l.pro_until > now()
              then 'pro' else 'free' end,
         l.pro_until, coalesce(l.is_lifetime, false)
  from (select auth.uid() as user_id) u
  left join public.gamerlocker_licenses l on l.user_id = u.user_id
  where u.user_id is not null;
$$;

create function public.redeem_product_key(p_key text)
returns table(ok boolean, code text, message text, days_added integer,
              new_pro_until timestamptz, is_lifetime boolean)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_user uuid := auth.uid();
  v_key text := upper(regexp_replace(coalesce(p_key, ''), '\s', '', 'g'));
  v_license public.gamerlocker_licenses%rowtype;
  v_product public.gamerlocker_product_keys%rowtype;
  v_now timestamptz;
begin
  if v_user is null then
    return query select false, 'not_authenticated', 'Entre na sua conta.', 0, null::timestamptz, false;
    return;
  end if;
  if v_key !~ '^SVP-[A-HJ-NP-Z2-9]{5}(-[A-HJ-NP-Z2-9]{5}){4}$' then
    return query select false, 'invalid_format', 'Formato de chave invalido.', 0, null::timestamptz, false;
    return;
  end if;

  -- Lock account first, then key: two keys on one account cannot lose days;
  -- two accounts racing for one key cannot both consume it.
  insert into public.gamerlocker_licenses(user_id) values(v_user) on conflict do nothing;
  select l.* into v_license from public.gamerlocker_licenses l
    where l.user_id = v_user for update;
  select k.* into v_product from public.gamerlocker_product_keys k
    where k.key_hash = encode(sha256(convert_to(v_key, 'UTF8')), 'hex') for update;
  v_now := clock_timestamp();

  if not found or v_product.disabled or
      (v_product.redeem_before is not null and v_product.redeem_before <= v_now) then
    return query select false, 'invalid_key', 'Chave invalida ou expirada.', 0, v_license.pro_until, v_license.is_lifetime;
    return;
  end if;
  if v_product.redeemed_at is not null then
    return query select false, 'already_used', 'Esta chave ja foi utilizada.', 0, v_license.pro_until, v_license.is_lifetime;
    return;
  end if;
  if v_license.is_lifetime then
    return query select false, 'already_lifetime', 'Sua conta ja possui PRO vitalicio. A chave nao foi consumida.', 0, null::timestamptz, true;
    return;
  end if;

  if v_product.is_lifetime then
    update public.gamerlocker_licenses l set is_lifetime = true, pro_until = null
      where l.user_id = v_user;
  else
    update public.gamerlocker_licenses l
      set pro_until = greatest(coalesce(l.pro_until, v_now), v_now) + v_product.duration_days * interval '24 hours'
      where l.user_id = v_user;
  end if;
  update public.gamerlocker_product_keys k set redeemed_by = v_user, redeemed_at = v_now
    where k.key_hash = v_product.key_hash;
  select l.* into v_license from public.gamerlocker_licenses l where l.user_id = v_user;
  return query select true, 'activated', 'Chave ativada.',
    case when v_product.is_lifetime then 0 else v_product.duration_days end,
    v_license.pro_until, v_license.is_lifetime;
end;
$$;

revoke all on function public.get_my_entitlement() from public, anon;
revoke all on function public.redeem_product_key(text) from public, anon;
grant execute on function public.get_my_entitlement() to authenticated;
grant execute on function public.redeem_product_key(text) to authenticated;
notify pgrst, 'reload schema';
commit;
