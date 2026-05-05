-- AToken Prediction Market
-- Initial core schema for Supabase project: tfxckvfrnkbcbswzdzmi
-- Date: 2026-05-05
-- Notes:
-- 1. This migration is intentionally conservative.
-- 2. End-user clients can read public market data and their own private data.
-- 3. Trading writes should go through trusted server code using the service role key.

create extension if not exists pgcrypto;

create type public.app_role as enum ('user', 'operator', 'admin');
create type public.market_source as enum ('polymarket');
create type public.market_status as enum ('draft', 'open', 'paused', 'closed', 'settled', 'cancelled');
create type public.outcome_status as enum ('active', 'paused', 'resolved', 'cancelled');
create type public.order_side as enum ('buy', 'sell');
create type public.order_type as enum ('limit', 'market');
create type public.order_status as enum (
  'created',
  'submission_pending',
  'submitted',
  'partially_filled',
  'filled',
  'cancel_pending',
  'cancelled',
  'failed_submission',
  'failed_cancel',
  'rejected',
  'expired'
);
create type public.trade_side as enum ('buy', 'sell');
create type public.settlement_status as enum ('pending', 'resolved', 'cancelled', 'disputed');
create type public.notification_type as enum ('order', 'trade', 'settlement', 'risk', 'system');
create type public.notification_status as enum ('unread', 'read', 'archived');
create type public.sync_job_type as enum (
  'market_sync',
  'orderbook_sync',
  'price_snapshot_sync',
  'order_reconcile',
  'trade_ingest',
  'settlement_sync'
);
create type public.sync_job_status as enum ('queued', 'running', 'succeeded', 'failed', 'dead_letter');
create type public.audit_actor_type as enum ('user', 'system', 'admin');

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('operator', 'admin')
  );
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  username text unique,
  display_name text,
  avatar_url text,
  timezone text,
  locale text,
  role public.app_role not null default 'user',
  wallet_address text,
  risk_level text not null default 'standard',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz
);

create table public.markets (
  id uuid primary key default gen_random_uuid(),
  source public.market_source not null default 'polymarket',
  polymarket_market_id text not null unique,
  polymarket_condition_id text,
  slug text not null unique,
  title text not null,
  subtitle text,
  description text,
  category text not null,
  tags text[] not null default '{}',
  status public.market_status not null default 'draft',
  rules_text text,
  resolution_source text,
  resolution_notes text,
  banner_image_url text,
  icon_image_url text,
  open_time timestamptz,
  close_time timestamptz,
  settled_at timestamptz,
  liquidity_score numeric(20, 8),
  volume_24h numeric(20, 8) not null default 0,
  volume_total numeric(20, 8) not null default 0,
  curated_rank integer not null default 1000,
  is_featured boolean not null default false,
  is_hidden boolean not null default false,
  raw_source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.market_outcomes (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  outcome_key text not null,
  outcome_label text not null,
  token_id text not null unique,
  status public.outcome_status not null default 'active',
  sort_order integer not null default 0,
  current_price numeric(10, 6),
  best_bid numeric(10, 6),
  best_ask numeric(10, 6),
  last_traded_price numeric(10, 6),
  last_price_at timestamptz,
  raw_source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (market_id, outcome_key)
);

create table public.market_price_snapshots (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  outcome_id uuid not null references public.market_outcomes(id) on delete cascade,
  snapshot_at timestamptz not null,
  last_price numeric(10, 6),
  best_bid numeric(10, 6),
  best_ask numeric(10, 6),
  mark_price numeric(10, 6),
  volume_delta numeric(20, 8) not null default 0,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique (outcome_id, snapshot_at)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  outcome_id uuid not null references public.market_outcomes(id) on delete restrict,
  side public.order_side not null,
  order_type public.order_type not null default 'limit',
  status public.order_status not null default 'created',
  limit_price numeric(10, 6),
  requested_size numeric(20, 8) not null,
  filled_size numeric(20, 8) not null default 0,
  average_fill_price numeric(10, 6),
  notional_requested numeric(20, 8),
  notional_filled numeric(20, 8) not null default 0,
  idempotency_key uuid not null,
  external_order_id text,
  external_client_order_id text,
  submission_error_code text,
  submission_error_message text,
  cancel_reason text,
  submitted_at timestamptz,
  last_synced_at timestamptz,
  raw_request_payload jsonb not null default '{}'::jsonb,
  raw_source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint orders_requested_size_positive check (requested_size > 0),
  constraint orders_limit_price_range check (limit_price is null or (limit_price >= 0 and limit_price <= 1)),
  unique (user_id, idempotency_key),
  unique (external_order_id)
);

create table public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null,
  previous_status public.order_status,
  next_status public.order_status,
  event_source text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.trades (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete set null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete restrict,
  outcome_id uuid not null references public.market_outcomes(id) on delete restrict,
  external_trade_id text not null unique,
  external_order_id text,
  side public.trade_side not null,
  fill_price numeric(10, 6) not null,
  fill_size numeric(20, 8) not null,
  fee_amount numeric(20, 8) not null default 0,
  fee_currency text,
  traded_at timestamptz not null,
  raw_source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.positions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete cascade,
  outcome_id uuid not null references public.market_outcomes(id) on delete cascade,
  net_shares numeric(20, 8) not null default 0,
  avg_entry_price numeric(10, 6),
  gross_cost numeric(20, 8) not null default 0,
  realized_pnl numeric(20, 8) not null default 0,
  unrealized_pnl numeric(20, 8) not null default 0,
  last_mark_price numeric(10, 6),
  last_reconciled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, market_id, outcome_id)
);

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  winning_outcome_id uuid references public.market_outcomes(id) on delete set null,
  status public.settlement_status not null default 'pending',
  resolved_at timestamptz,
  resolution_price numeric(10, 6),
  source_reference text,
  notes text,
  raw_source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (market_id)
);

create table public.watchlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, market_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type public.notification_type not null,
  status public.notification_status not null default 'unread',
  title text not null,
  body text,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.sync_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type public.sync_job_type not null,
  status public.sync_job_status not null default 'queued',
  target_key text,
  run_key text,
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  next_retry_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  error_code text,
  error_message text,
  payload jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.system_configs (
  id uuid primary key default gen_random_uuid(),
  config_key text not null unique,
  config_value jsonb not null default '{}'::jsonb,
  description text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_type public.audit_actor_type not null,
  actor_user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  request_id text,
  ip_address inet,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_markets_status_rank on public.markets (status, curated_rank, close_time);
create index idx_markets_category_status on public.markets (category, status);
create index idx_market_outcomes_market_id on public.market_outcomes (market_id, sort_order);
create index idx_market_price_snapshots_market_time on public.market_price_snapshots (market_id, snapshot_at desc);
create index idx_orders_user_created_at on public.orders (user_id, created_at desc);
create index idx_orders_market_status on public.orders (market_id, status);
create index idx_orders_external_order_id on public.orders (external_order_id) where external_order_id is not null;
create index idx_order_events_order_created_at on public.order_events (order_id, created_at desc);
create index idx_trades_user_traded_at on public.trades (user_id, traded_at desc);
create index idx_trades_market_traded_at on public.trades (market_id, traded_at desc);
create index idx_positions_user_market on public.positions (user_id, market_id);
create index idx_notifications_user_status_created_at on public.notifications (user_id, status, created_at desc);
create index idx_sync_jobs_status_next_retry on public.sync_jobs (status, next_retry_at);
create index idx_audit_logs_target on public.audit_logs (target_type, target_id, created_at desc);

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute procedure public.touch_updated_at();

create trigger trg_markets_updated_at
before update on public.markets
for each row execute procedure public.touch_updated_at();

create trigger trg_market_outcomes_updated_at
before update on public.market_outcomes
for each row execute procedure public.touch_updated_at();

create trigger trg_orders_updated_at
before update on public.orders
for each row execute procedure public.touch_updated_at();

create trigger trg_positions_updated_at
before update on public.positions
for each row execute procedure public.touch_updated_at();

create trigger trg_settlements_updated_at
before update on public.settlements
for each row execute procedure public.touch_updated_at();

create trigger trg_sync_jobs_updated_at
before update on public.sync_jobs
for each row execute procedure public.touch_updated_at();

create trigger trg_system_configs_updated_at
before update on public.system_configs
for each row execute procedure public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    email,
    username,
    display_name
  )
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'username',
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'full_name')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.markets enable row level security;
alter table public.market_outcomes enable row level security;
alter table public.market_price_snapshots enable row level security;
alter table public.orders enable row level security;
alter table public.order_events enable row level security;
alter table public.trades enable row level security;
alter table public.positions enable row level security;
alter table public.settlements enable row level security;
alter table public.watchlists enable row level security;
alter table public.notifications enable row level security;
alter table public.sync_jobs enable row level security;
alter table public.system_configs enable row level security;
alter table public.audit_logs enable row level security;

create policy "public can read markets"
on public.markets
for select
using (not is_hidden);

create policy "public can read market outcomes"
on public.market_outcomes
for select
using (
  exists (
    select 1
    from public.markets m
    where m.id = market_outcomes.market_id
      and not m.is_hidden
  )
);

create policy "public can read market snapshots"
on public.market_price_snapshots
for select
using (
  exists (
    select 1
    from public.markets m
    where m.id = market_price_snapshots.market_id
      and not m.is_hidden
  )
);

create policy "public can read settlements"
on public.settlements
for select
using (
  exists (
    select 1
    from public.markets m
    where m.id = settlements.market_id
      and not m.is_hidden
  )
);

create policy "users can read own profile"
on public.profiles
for select
using (auth.uid() = id or public.is_admin());

create policy "users can insert own profile"
on public.profiles
for insert
with check (auth.uid() = id or public.is_admin());

create policy "users can update own profile"
on public.profiles
for update
using (auth.uid() = id or public.is_admin())
with check (auth.uid() = id or public.is_admin());

create policy "users can read own orders"
on public.orders
for select
using (auth.uid() = user_id or public.is_admin());

create policy "users can read own order events"
on public.order_events
for select
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_events.order_id
      and (o.user_id = auth.uid() or public.is_admin())
  )
);

create policy "users can read own trades"
on public.trades
for select
using (auth.uid() = user_id or public.is_admin());

create policy "users can read own positions"
on public.positions
for select
using (auth.uid() = user_id or public.is_admin());

create policy "users can read own notifications"
on public.notifications
for select
using (auth.uid() = user_id or public.is_admin());

create policy "users can update own notifications"
on public.notifications
for update
using (auth.uid() = user_id or public.is_admin())
with check (auth.uid() = user_id or public.is_admin());

create policy "users can read own watchlists"
on public.watchlists
for select
using (auth.uid() = user_id or public.is_admin());

create policy "users can insert own watchlists"
on public.watchlists
for insert
with check (auth.uid() = user_id or public.is_admin());

create policy "users can delete own watchlists"
on public.watchlists
for delete
using (auth.uid() = user_id or public.is_admin());

create policy "admins can read sync jobs"
on public.sync_jobs
for select
using (public.is_admin());

create policy "admins can read system configs"
on public.system_configs
for select
using (public.is_admin());

create policy "admins can update system configs"
on public.system_configs
for update
using (public.is_admin())
with check (public.is_admin());

create policy "admins can insert system configs"
on public.system_configs
for insert
with check (public.is_admin());

create policy "admins can read audit logs"
on public.audit_logs
for select
using (public.is_admin());

comment on table public.markets is 'AToken mirror of external market metadata plus local curation fields.';
comment on table public.orders is 'Local order state machine. End-user order creation should happen through trusted server APIs.';
comment on table public.trades is 'Executed fills, usually ingested from Polymarket and linked back to local orders when possible.';
comment on table public.positions is 'User positions derived from trades and settlement state, rebuildable if needed.';
comment on table public.sync_jobs is 'Operational async job control table for retries and reconciliation.';
