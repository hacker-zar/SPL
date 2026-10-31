-- Current schema for a new Supabase project. Existing projects should apply
-- the ordered files in supabase/migrations/ instead of rerunning this file.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vehicle_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_type text not null default 'camion',
  brand text,
  model text,
  year integer,
  fuel_type text,
  consumption_liters_per_100_km numeric(10, 2) not null check (consumption_liters_per_100_km > 0),
  maintenance_cost_per_km numeric(12, 4) not null default 0 check (maintenance_cost_per_km >= 0),
  tire_cost_per_km numeric(12, 4) not null default 0 check (tire_cost_per_km >= 0),
  other_operating_costs_per_km numeric(12, 4) not null default 0 check (other_operating_costs_per_km >= 0),
  daily_fixed_cost numeric(12, 2) not null default 0 check (daily_fixed_cost >= 0),
  capacity_tons numeric(10, 2) check (capacity_tons is null or capacity_tons > 0),
  plate text,
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists vehicle_profiles_user_primary_idx
  on public.vehicle_profiles (user_id, is_primary desc, created_at asc);
alter table public.vehicle_profiles add constraint vehicle_profiles_id_user_unique unique (id, user_id);

create table if not exists public.trips (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid,
  created_at timestamptz not null default now(),
  origin_name text not null,
  destination_name text not null,
  distance_km numeric(12, 2) not null check (distance_km >= 0),
  duration_minutes numeric(12, 2) not null check (duration_minutes >= 0),
  empty_return boolean not null default false,
  route jsonb not null,
  trip jsonb not null,
  costs jsonb not null,
  vehicle_profile_snapshot jsonb,
  calculation_status text,
  income numeric(14, 2) not null default 0,
  total_costs numeric(14, 2) not null default 0,
  net_profit numeric(14, 2) not null default 0,
  margin_percent numeric(8, 2) not null default 0,
  constraint trips_vehicle_owner_fkey foreign key (vehicle_id, user_id)
    references public.vehicle_profiles(id, user_id)
);
create index if not exists trips_user_created_at_idx
  on public.trips (user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists set_vehicle_profiles_updated_at on public.vehicle_profiles;
create trigger set_vehicle_profiles_updated_at before update on public.vehicle_profiles
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.vehicle_profiles enable row level security;
alter table public.trips enable row level security;
drop policy if exists "Users can read their profile" on public.profiles;
create policy "Users can read their profile" on public.profiles for select to authenticated using ((select auth.uid()) = id);
drop policy if exists "Users can insert their profile" on public.profiles;
create policy "Users can insert their profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
drop policy if exists "Users can delete their profile" on public.profiles;
create policy "Users can delete their profile" on public.profiles for delete to authenticated using ((select auth.uid()) = id);
drop policy if exists "Users can read their vehicle profile" on public.vehicle_profiles;
create policy "Users can read their vehicle profile" on public.vehicle_profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can insert their vehicle profile" on public.vehicle_profiles;
create policy "Users can insert their vehicle profile" on public.vehicle_profiles for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their vehicle profile" on public.vehicle_profiles;
create policy "Users can update their vehicle profile" on public.vehicle_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their vehicle profiles" on public.vehicle_profiles;
create policy "Users can delete their vehicle profiles" on public.vehicle_profiles for delete to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can read their trips" on public.trips;
create policy "Users can read their trips" on public.trips for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can insert their trips" on public.trips;
create policy "Users can insert their trips" on public.trips for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their trips" on public.trips;
create policy "Users can update their trips" on public.trips for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their trips" on public.trips;
create policy "Users can delete their trips" on public.trips for delete to authenticated using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.vehicle_profiles to authenticated;
grant select, insert, update, delete on public.trips to authenticated;
