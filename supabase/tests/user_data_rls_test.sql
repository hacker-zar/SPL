begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, is_anonymous)
values
  ('10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'rls-a@example.test', '', now(), now(), now(), true),
  ('10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'rls-b@example.test', '', now(), now(), now(), true);
insert into public.profiles (id, full_name) values
  ('10000000-0000-0000-0000-000000000001', 'A'),
  ('10000000-0000-0000-0000-000000000002', 'B');
insert into public.vehicle_profiles
  (id, user_id, vehicle_type, consumption_liters_per_100_km, capacity_tons)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'camion', 30, 28),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'camion', 30, 28);
insert into public.trips
  (id, user_id, origin_name, destination_name, distance_km, duration_minutes, route, trip, costs)
values
  ('rls-trip-a', '10000000-0000-0000-0000-000000000001', 'A', 'B', 10, 60, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb),
  ('rls-trip-b', '10000000-0000-0000-0000-000000000002', 'C', 'D', 10, 60, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.profiles), 1, 'anonymous user can read only its profile');
select is((select count(*)::integer from public.vehicle_profiles), 1, 'anonymous user can read only its vehicles');
select is((select count(*)::integer from public.trips), 1, 'anonymous user can read only its trips');
select is((select count(*)::integer from public.profiles where id = '10000000-0000-0000-0000-000000000002'), 0, 'other profile is hidden');
select is((select count(*)::integer from public.vehicle_profiles where user_id = '10000000-0000-0000-0000-000000000002'), 0, 'other vehicles are hidden');
select is((select count(*)::integer from public.trips where user_id = '10000000-0000-0000-0000-000000000002'), 0, 'other trips are hidden');
select is((with changed as (update public.profiles set full_name = 'stolen' where id = '10000000-0000-0000-0000-000000000002' returning 1) select count(*)::integer from changed), 0, 'cannot update another profile');
select throws_ok($$insert into public.profiles (id, full_name) values ('10000000-0000-0000-0000-000000000002', 'stolen')$$, '42501', null, 'cannot insert another profile');
select throws_ok($$insert into public.trips (id, user_id, origin_name, destination_name, distance_km, duration_minutes, route, trip, costs) values ('rls-trip-forged', '10000000-0000-0000-0000-000000000002', 'A', 'B', 10, 60, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb)$$, '42501', null, 'cannot insert a trip for another user');
select throws_ok($$update public.trips set user_id = '10000000-0000-0000-0000-000000000002' where id = 'rls-trip-a'$$, '42501', null, 'cannot transfer ownership with update');
select throws_ok($$update public.vehicle_profiles set user_id = '10000000-0000-0000-0000-000000000002' where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'cannot transfer vehicle ownership with update');
select is((with removed as (delete from public.profiles where id = '10000000-0000-0000-0000-000000000002' returning 1) select count(*)::integer from removed), 0, 'cannot delete another profile');
select is((with removed as (delete from public.vehicle_profiles where user_id = '10000000-0000-0000-0000-000000000002' returning 1) select count(*)::integer from removed), 0, 'cannot delete another user vehicle');
select is((with removed as (delete from public.trips where user_id = '10000000-0000-0000-0000-000000000002' returning 1) select count(*)::integer from removed), 0, 'cannot delete another user trip');

select * from finish();
rollback;
