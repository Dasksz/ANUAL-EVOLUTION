create table public.evolution_expense_snapshot (
  singleton boolean primary key default true check (singleton),
  synced_at timestamptz not null default now(),
  entries jsonb not null check (jsonb_typeof(entries) = 'array')
);
alter table public.evolution_expense_snapshot enable row level security;
revoke all on public.evolution_expense_snapshot from public, anon, authenticated;
grant select on public.evolution_expense_snapshot to authenticated;
create policy expense_snapshot_approved_admin on public.evolution_expense_snapshot
  for select to authenticated using ((select public.is_admin()) and (select public.is_approved()));
