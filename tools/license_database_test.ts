import { PGlite } from 'npm:@electric-sql/pglite@0.3.14';

function assert(value: unknown, message: string) {
  if (!value) throw new Error(message);
}
const db = new PGlite();
await db.exec(`create role anon; create role authenticated;
  create schema auth; create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql as $$
    select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
  insert into auth.users values ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');`);
await db.exec(await Deno.readTextFile(new URL('../supabase/migrations/202610110002_licenses_v2.sql', import.meta.url)));
const user1 = '00000000-0000-0000-0000-000000000001';
const user2 = '00000000-0000-0000-0000-000000000002';
const key = (letter: string) => 'SVP-' + Array(5).fill(letter.repeat(5)).join('-');
const redeem = async (letter: string) => (await db.query<any>('select * from public.redeem_product_key($1)', [key(letter)])).rows[0];
const entitlement = async () => (await db.query<any>('select * from public.get_my_entitlement()')).rows[0];
try {
  for (const letter of ['A', 'B', 'C', 'D', 'E']) {
    await db.query(`insert into public.gamerlocker_product_keys(key_hash,duration_days,is_lifetime)
      values(encode(sha256(convert_to($1,'UTF8')),'hex'),$2,$3)`,
      [key(letter), letter === 'C' ? null : 30, letter === 'C']);
  }
  assert(!(await redeem('A')).ok, 'Anonymous redemption accepted');
  await db.query(`select set_config('request.jwt.claim.sub',$1,false)`, [user1]);
  const first = await redeem('A');
  assert(first.ok && first.days_added === 30, 'First 30 days failed');
  const second = await redeem('B');
  assert(second.ok && new Date(second.new_pro_until).getTime() - new Date(first.new_pro_until).getTime() === 30 * 86400000, 'Second key did not stack exactly 30 days');
  assert(!(await redeem('B')).ok, 'Same key redeemed twice');
  assert((await entitlement()).pro_until.getTime() === new Date(second.new_pro_until).getTime(), 'Duplicate key changed expiration');
  const lifetime = await redeem('C');
  assert(lifetime.ok && lifetime.is_lifetime && lifetime.new_pro_until === null, 'Lifetime not granted');
  assert(!(await redeem('D')).ok, 'Lifetime consumed another key');
  await db.query(`select set_config('request.jwt.claim.sub',$1,false)`, [user2]);
  assert(!(await redeem('A')).ok, 'Consumed key reused by another account');
  assert((await redeem('D')).ok, 'Key rejected for lifetime account was consumed');
  await db.query(`update public.gamerlocker_licenses set pro_until=now()-interval '1 day' where user_id=$1`, [user2]);
  assert((await entitlement()).plan === 'free', 'Expired plan stays Pro');
  const renewed = await redeem('E');
  assert(new Date(renewed.new_pro_until).getTime() > Date.now() + 29 * 86400000, 'Expired account renewed from old date');
  await db.exec('set role authenticated');
  let blocked = false;
  try { await db.query('select * from public.gamerlocker_product_keys'); } catch { blocked = true; }
  assert(blocked, 'Client can read keys');
  assert((await entitlement()).plan === 'pro', 'Authenticated RPC denied');
  await db.exec('reset role; set role anon');
  blocked = false;
  try { await entitlement(); } catch { blocked = true; }
  assert(blocked, 'Anonymous RPC allowed');
  console.log('PASS: stacking, single-use, lifetime, renewal, and database permissions.');
} finally { await db.close(); }
