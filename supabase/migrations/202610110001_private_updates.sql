create table public.private_update_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  expires_at timestamptz
);
alter table public.private_update_access enable row level security;
revoke all on public.private_update_access from anon, authenticated;
grant select on public.private_update_access to authenticated;
create policy "Users read only their active invitation"
on public.private_update_access for select to authenticated
using (user_id = (select auth.uid()) and
       (expires_at is null or expires_at > now()));
