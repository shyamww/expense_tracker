create table if not exists public.expense_tracker_stores (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.expense_tracker_stores enable row level security;

grant select, insert, update, delete on public.expense_tracker_stores to authenticated;

drop policy if exists "Users can read their own expense store"
  on public.expense_tracker_stores;
drop policy if exists "Users can create their own expense store"
  on public.expense_tracker_stores;
drop policy if exists "Users can update their own expense store"
  on public.expense_tracker_stores;
drop policy if exists "Users can delete their own expense store"
  on public.expense_tracker_stores;

create policy "Users can read their own expense store"
  on public.expense_tracker_stores
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their own expense store"
  on public.expense_tracker_stores
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own expense store"
  on public.expense_tracker_stores
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own expense store"
  on public.expense_tracker_stores
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
