-- Supabase schema for the independent driver MVP.
-- Apply with the Supabase SQL editor or convert to a migration with the CLI.

create table if not exists public.vehicle_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  consumption_liters_per_100_km numeric(10, 2) not null check (consumption_liters_per_100_km > 0),
  maintenance_cost_per_km numeric(12, 2) not null default 0 check (maintenance_cost_per_km >= 0),
  capacity_tons numeric(10, 2) not null check (capacity_tons > 0),
  plate text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trips (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  origin_name text not null,
  destination_name text not null,
  distance_km numeric(12, 2) not null check (distance_km >= 0),
  duration_minutes numeric(12, 2) not null check (duration_minutes >= 0),
  empty_return boolean not null default false,
  route jsonb not null,
  trip jsonb not null,
  costs jsonb not null,
  income numeric(14, 2) not null default 0,
  total_costs numeric(14, 2) not null default 0,
  net_profit numeric(14, 2) not null default 0,
  margin_percent numeric(8, 2) not null default 0
);

create index if not exists trips_user_created_at_idx
  on public.trips (user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_vehicle_profiles_updated_at on public.vehicle_profiles;
create trigger set_vehicle_profiles_updated_at
before update on public.vehicle_profiles
for each row
execute function public.set_updated_at();

alter table public.vehicle_profiles enable row level security;
alter table public.trips enable row level security;

drop policy if exists "Users can read their vehicle profile" on public.vehicle_profiles;
create policy "Users can read their vehicle profile"
on public.vehicle_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their vehicle profile" on public.vehicle_profiles;
create policy "Users can insert their vehicle profile"
on public.vehicle_profiles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their vehicle profile" on public.vehicle_profiles;
create policy "Users can update their vehicle profile"
on public.vehicle_profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can read their trips" on public.trips;
create policy "Users can read their trips"
on public.trips
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their trips" on public.trips;
create policy "Users can insert their trips"
on public.trips
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their trips" on public.trips;
create policy "Users can update their trips"
on public.trips
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their trips" on public.trips;
create policy "Users can delete their trips"
on public.trips
for delete
to authenticated
using ((select auth.uid()) = user_id);

grant select, insert, update on table public.vehicle_profiles to authenticated;
grant select, insert, update, delete on table public.trips to authenticated;

-- Private bucket reserved for future receipts, waybills, and exported reports.
insert into storage.buckets (id, name, public)
values ('trip_attachments', 'trip_attachments', false)
on conflict (id) do nothing;
