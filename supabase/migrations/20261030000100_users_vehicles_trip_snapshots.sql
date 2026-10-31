-- Expand the existing owner-scoped schema without deleting current rows.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.vehicle_profiles add column if not exists id uuid;
update public.vehicle_profiles set id = gen_random_uuid() where id is null;
alter table public.vehicle_profiles alter column id set default gen_random_uuid();
alter table public.vehicle_profiles alter column id set not null;
do $$
declare existing_pk text;
begin
  select conname into existing_pk
  from pg_constraint
  where conrelid = 'public.vehicle_profiles'::regclass and contype = 'p';
  if existing_pk is not null then
    execute format('alter table public.vehicle_profiles drop constraint %I', existing_pk);
  end if;
  alter table public.vehicle_profiles add constraint vehicle_profiles_pkey primary key (id);
end $$;

alter table public.vehicle_profiles
  alter column capacity_tons drop not null,
  alter column capacity_tons drop default;
alter table public.vehicle_profiles
  drop constraint if exists vehicle_profiles_capacity_tons_check;
alter table public.vehicle_profiles
  add column if not exists vehicle_type text not null default 'camion',
  add column if not exists brand text,
  add column if not exists model text,
  add column if not exists year integer,
  add column if not exists fuel_type text,
  add column if not exists tire_cost_per_km numeric(12, 4) not null default 0 check (tire_cost_per_km >= 0),
  add column if not exists other_operating_costs_per_km numeric(12, 4) not null default 0 check (other_operating_costs_per_km >= 0),
  add column if not exists is_primary boolean not null default true;
update public.vehicle_profiles set vehicle_type = 'camion' where vehicle_type is null;
create index if not exists vehicle_profiles_user_primary_idx
  on public.vehicle_profiles (user_id, is_primary desc, created_at asc);
alter table public.vehicle_profiles
  add constraint vehicle_profiles_id_user_unique unique (id, user_id);

alter table public.trips
  add column if not exists vehicle_id uuid,
  add column if not exists vehicle_profile_snapshot jsonb,
  add column if not exists calculation_status text;
alter table public.trips
  add constraint trips_vehicle_owner_fkey
  foreign key (vehicle_id, user_id)
  references public.vehicle_profiles(id, user_id);

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
create policy "Users can read their profile" on public.profiles
for select to authenticated using ((select auth.uid()) = id);
drop policy if exists "Users can insert their profile" on public.profiles;
create policy "Users can insert their profile" on public.profiles
for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile" on public.profiles
for update to authenticated using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);
drop policy if exists "Users can delete their profile" on public.profiles;
create policy "Users can delete their profile" on public.profiles
for delete to authenticated using ((select auth.uid()) = id);

drop policy if exists "Users can read their vehicle profile" on public.vehicle_profiles;
create policy "Users can read their vehicle profile" on public.vehicle_profiles
for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can insert their vehicle profile" on public.vehicle_profiles;
create policy "Users can insert their vehicle profile" on public.vehicle_profiles
for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their vehicle profile" on public.vehicle_profiles;
create policy "Users can update their vehicle profile" on public.vehicle_profiles
for update to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their vehicle profiles" on public.vehicle_profiles;
create policy "Users can delete their vehicle profiles" on public.vehicle_profiles
for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can read their trips" on public.trips;
create policy "Users can read their trips" on public.trips
for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can insert their trips" on public.trips;
create policy "Users can insert their trips" on public.trips
for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their trips" on public.trips;
create policy "Users can update their trips" on public.trips
for update to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their trips" on public.trips;
create policy "Users can delete their trips" on public.trips
for delete to authenticated using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.vehicle_profiles to authenticated;
grant select, insert, update, delete on public.trips to authenticated;
