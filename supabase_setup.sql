-- Gestor de Plantel — Futebol de 7
-- Executar uma vez no Supabase: SQL Editor > New query > Run

create table if not exists public.plantel_state (
  plantel_id text primary key,
  payload jsonb not null default '{}'::jsonb,
  updated_at_ms bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.plantel_state enable row level security;

grant select, insert, update on table public.plantel_state to anon, authenticated;

drop policy if exists plantel_state_select on public.plantel_state;
create policy plantel_state_select
on public.plantel_state
for select
to anon, authenticated
using (plantel_id = '019fb865-7007-7bb3-9f93-68f50bf7daa6');

drop policy if exists plantel_state_insert on public.plantel_state;
create policy plantel_state_insert
on public.plantel_state
for insert
to anon, authenticated
with check (plantel_id = '019fb865-7007-7bb3-9f93-68f50bf7daa6');

drop policy if exists plantel_state_update on public.plantel_state;
create policy plantel_state_update
on public.plantel_state
for update
to anon, authenticated
using (plantel_id = '019fb865-7007-7bb3-9f93-68f50bf7daa6')
with check (plantel_id = '019fb865-7007-7bb3-9f93-68f50bf7daa6');

insert into public.plantel_state (
  plantel_id,
  payload,
  updated_at_ms
)
values (
  '019fb865-7007-7bb3-9f93-68f50bf7daa6',
  '{"players":[],"updatedAt":0,"tactics":[],"activeTacticId":"","schemaVersion":2}'::jsonb,
  0
)
on conflict (plantel_id) do nothing;
