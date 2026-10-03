-- ============================================================
-- PhuotThu
-- Core Database Schema v1
-- DEV-05
-- ============================================================


-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

create schema if not exists extensions;

create extension if not exists postgis
with schema extensions;


-- ============================================================
-- 2. COMMON FUNCTIONS
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================
-- 3. PROFILES
-- One public profile for each Supabase Auth user
-- ============================================================

create table public.profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

  display_name text,
  avatar_url text,
  bio text,

  travel_style text,

  interests text[]
    not null
    default '{}',

  privacy_level text
    not null
    default 'friends'
    check (
      privacy_level in (
        'private',
        'friends',
        'followers',
        'public'
      )
    ),

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now()
);


-- Automatically create profile after Auth signup.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  insert into public.profiles (
    id,
    display_name,
    avatar_url
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;

end;
$$;


drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();


create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute procedure public.set_updated_at();


-- ============================================================
-- 4. VEHICLES
-- ============================================================

create table public.vehicles (
  id uuid primary key
    default gen_random_uuid(),

  user_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  name text
    not null,

  vehicle_type text
    not null
    check (
      vehicle_type in (
        'motorcycle',
        'car',
        'other'
      )
    ),

  brand text,
  model text,
  plate_number text,

  fuel_type text
    check (
      fuel_type is null
      or fuel_type in (
        'gasoline',
        'diesel',
        'electric',
        'hybrid',
        'other'
      )
    ),

  fuel_tank_capacity_l numeric(8,2)
    check (
      fuel_tank_capacity_l is null
      or fuel_tank_capacity_l >= 0
    ),

  consumption_l_per_100km numeric(8,2)
    check (
      consumption_l_per_100km is null
      or consumption_l_per_100km >= 0
    ),

  battery_capacity_kwh numeric(8,2)
    check (
      battery_capacity_kwh is null
      or battery_capacity_kwh >= 0
    ),

  is_default boolean
    not null
    default false,

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now()
);


create index vehicles_user_id_idx
on public.vehicles(user_id);


create unique index vehicles_one_default_per_user_idx
on public.vehicles(user_id)
where is_default = true;


create trigger vehicles_set_updated_at
before update on public.vehicles
for each row
execute procedure public.set_updated_at();


-- ============================================================
-- 5. TRIPS
-- ============================================================

create table public.trips (
  id uuid primary key
    default gen_random_uuid(),

  owner_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  vehicle_id uuid
    references public.vehicles(id)
    on delete set null,

  name text
    not null,

  description text,

  status text
    not null
    default 'draft'
    check (
      status in (
        'draft',
        'planned',
        'active',
        'completed',
        'cancelled'
      )
    ),

  planned_start_at timestamptz,
  planned_end_at timestamptz,

  start_name text,
  start_address text,
  start_place_id text,

  start_location extensions.geography(
    point,
    4326
  ),

  destination_name text,
  destination_address text,
  destination_place_id text,

  destination_location extensions.geography(
    point,
    4326
  ),

  route_distance_m numeric(12,2)
    check (
      route_distance_m is null
      or route_distance_m >= 0
    ),

  route_duration_s bigint
    check (
      route_duration_s is null
      or route_duration_s >= 0
    ),

  estimated_fuel_l numeric(10,2)
    check (
      estimated_fuel_l is null
      or estimated_fuel_l >= 0
    ),

  estimated_min_cost numeric(14,2)
    check (
      estimated_min_cost is null
      or estimated_min_cost >= 0
    ),

  budget_total numeric(14,2)
    check (
      budget_total is null
      or budget_total >= 0
    ),

  currency char(3)
    not null
    default 'VND',

  offline_ready boolean
    not null
    default false,

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now(),

  constraint trips_date_check
    check (
      planned_end_at is null
      or planned_start_at is null
      or planned_end_at >= planned_start_at
    )
);


create index trips_owner_id_idx
on public.trips(owner_id);

create index trips_status_idx
on public.trips(status);

create index trips_start_location_idx
on public.trips
using gist(start_location);

create index trips_destination_location_idx
on public.trips
using gist(destination_location);


create trigger trips_set_updated_at
before update on public.trips
for each row
execute procedure public.set_updated_at();


-- ============================================================
-- 6. TRIP MEMBERS
-- ============================================================

create table public.trip_members (
  trip_id uuid
    not null
    references public.trips(id)
    on delete cascade,

  user_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  role text
    not null
    default 'member'
    check (
      role in (
        'leader',
        'member'
      )
    ),

  membership_status text
    not null
    default 'invited'
    check (
      membership_status in (
        'invited',
        'accepted',
        'declined',
        'removed'
      )
    ),

  location_sharing_consent boolean
    not null
    default true,

  joined_at timestamptz,

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now(),

  primary key (
    trip_id,
    user_id
  )
);


create index trip_members_user_id_idx
on public.trip_members(user_id);

create index trip_members_trip_status_idx
on public.trip_members(
  trip_id,
  membership_status
);


create trigger trip_members_set_updated_at
before update on public.trip_members
for each row
execute procedure public.set_updated_at();


-- ============================================================
-- 7. AUTOMATICALLY ADD TRIP OWNER AS LEADER
-- ============================================================

create or replace function public.add_trip_owner_as_leader()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  insert into public.trip_members (
    trip_id,
    user_id,
    role,
    membership_status,
    joined_at
  )
  values (
    new.id,
    new.owner_id,
    'leader',
    'accepted',
    now()
  )
  on conflict (
    trip_id,
    user_id
  ) do nothing;

  return new;

end;
$$;


drop trigger if exists on_trip_created_add_owner
on public.trips;

create trigger on_trip_created_add_owner
after insert on public.trips
for each row
execute procedure public.add_trip_owner_as_leader();


-- ============================================================
-- 8. TRIP WAYPOINTS
-- ============================================================

create table public.trip_waypoints (
  id uuid primary key
    default gen_random_uuid(),

  trip_id uuid
    not null
    references public.trips(id)
    on delete cascade,

  created_by uuid
    references public.profiles(id)
    on delete set null,

  waypoint_type text
    not null
    default 'other'
    check (
      waypoint_type in (
        'start',
        'destination',
        'mandatory',
        'checkpoint',
        'rest',
        'food',
        'fuel',
        'scenic',
        'stay',
        'other'
      )
    ),

  source text
    not null
    default 'user'
    check (
      source in (
        'user',
        'google',
        'system'
      )
    ),

  sort_order integer
    not null
    default 0,

  name text
    not null,

  address text,

  place_id text,

  location extensions.geography(
    point,
    4326
  ),

  scheduled_at timestamptz,

  radius_m integer
    not null
    default 100
    check (
      radius_m >= 10
      and radius_m <= 5000
    ),

  is_required boolean
    not null
    default false,

  metadata jsonb
    not null
    default '{}'::jsonb,

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now()
);


create index trip_waypoints_trip_id_idx
on public.trip_waypoints(trip_id);

create index trip_waypoints_trip_sort_idx
on public.trip_waypoints(
  trip_id,
  sort_order
);

create index trip_waypoints_location_idx
on public.trip_waypoints
using gist(location);


create trigger trip_waypoints_set_updated_at
before update on public.trip_waypoints
for each row
execute procedure public.set_updated_at();


-- ============================================================
-- 9. CHECKPOINT ATTENDANCE
-- Manual confirmation, NOT GPS auto attendance
-- ============================================================

create table public.checkpoint_attendance (
  waypoint_id uuid
    not null
    references public.trip_waypoints(id)
    on delete cascade,

  user_id uuid
    not null
    references public.profiles(id)
    on delete cascade,

  status text
    not null
    default 'pending'
    check (
      status in (
        'pending',
        'confirmed'
      )
    ),

  arrived_at timestamptz,
  confirmed_at timestamptz,

  confirmation_location extensions.geography(
    point,
    4326
  ),

  created_at timestamptz
    not null
    default now(),

  updated_at timestamptz
    not null
    default now(),

  primary key (
    waypoint_id,
    user_id
  )
);


create index checkpoint_attendance_user_idx
on public.checkpoint_attendance(user_id);


create trigger checkpoint_attendance_set_updated_at
before update on public.checkpoint_attendance
for each row
execute procedure public.set_updated_at();


-- ============================================================
-- 10. SECURITY HELPER FUNCTIONS
-- ============================================================

create or replace function public.is_trip_owner(
  target_trip_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trips t
    where t.id = target_trip_id
      and t.owner_id = auth.uid()
  );
$$;


create or replace function public.is_trip_member(
  target_trip_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = target_trip_id
      and tm.user_id = auth.uid()
      and tm.membership_status = 'accepted'
  );
$$;


revoke all
on function public.is_trip_owner(uuid)
from public;

revoke all
on function public.is_trip_member(uuid)
from public;

grant execute
on function public.is_trip_owner(uuid)
to authenticated;

grant execute
on function public.is_trip_member(uuid)
to authenticated;


-- ============================================================
-- 11. ENABLE ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles
enable row level security;

alter table public.vehicles
enable row level security;

alter table public.trips
enable row level security;

alter table public.trip_members
enable row level security;

alter table public.trip_waypoints
enable row level security;

alter table public.checkpoint_attendance
enable row level security;


-- ============================================================
-- 12. EXPLICIT TABLE GRANTS
-- ============================================================

revoke all
on table public.profiles
from anon, authenticated;

revoke all
on table public.vehicles
from anon, authenticated;

revoke all
on table public.trips
from anon, authenticated;

revoke all
on table public.trip_members
from anon, authenticated;

revoke all
on table public.trip_waypoints
from anon, authenticated;

revoke all
on table public.checkpoint_attendance
from anon, authenticated;


grant select, update
on table public.profiles
to authenticated;

grant select, insert, update, delete
on table public.vehicles
to authenticated;

grant select, insert, update, delete
on table public.trips
to authenticated;

grant select, insert, update, delete
on table public.trip_members
to authenticated;

grant select, insert, update, delete
on table public.trip_waypoints
to authenticated;

grant select, insert, update, delete
on table public.checkpoint_attendance
to authenticated;


-- ============================================================
-- 13. PROFILES RLS
-- ============================================================

create policy "profiles_select_self_or_trip_members"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()

  or exists (
    select 1
    from public.trip_members tm
    where tm.user_id = profiles.id
      and tm.membership_status = 'accepted'
      and public.is_trip_member(tm.trip_id)
  )
);


create policy "profiles_update_self"
on public.profiles
for update
to authenticated
using (
  id = auth.uid()
)
with check (
  id = auth.uid()
);


-- ============================================================
-- 14. VEHICLES RLS
-- ============================================================

create policy "vehicles_select_own"
on public.vehicles
for select
to authenticated
using (
  user_id = auth.uid()
);


create policy "vehicles_insert_own"
on public.vehicles
for insert
to authenticated
with check (
  user_id = auth.uid()
);


create policy "vehicles_update_own"
on public.vehicles
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


create policy "vehicles_delete_own"
on public.vehicles
for delete
to authenticated
using (
  user_id = auth.uid()
);


-- ============================================================
-- 15. TRIPS RLS
-- ============================================================

create policy "trips_select_members"
on public.trips
for select
to authenticated
using (
  owner_id = auth.uid()
  or public.is_trip_member(id)
);


create policy "trips_insert_owner"
on public.trips
for insert
to authenticated
with check (
  owner_id = auth.uid()
);


create policy "trips_update_owner"
on public.trips
for update
to authenticated
using (
  owner_id = auth.uid()
)
with check (
  owner_id = auth.uid()
);


create policy "trips_delete_owner"
on public.trips
for delete
to authenticated
using (
  owner_id = auth.uid()
);


-- ============================================================
-- 16. TRIP MEMBERS RLS
-- ============================================================

create policy "trip_members_select_trip_members"
on public.trip_members
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_trip_member(trip_id)
  or public.is_trip_owner(trip_id)
);


create policy "trip_members_insert_owner"
on public.trip_members
for insert
to authenticated
with check (
  public.is_trip_owner(trip_id)
);


create policy "trip_members_update_owner_or_self"
on public.trip_members
for update
to authenticated
using (
  user_id = auth.uid()
  or public.is_trip_owner(trip_id)
)
with check (
  user_id = auth.uid()
  or public.is_trip_owner(trip_id)
);


create policy "trip_members_delete_owner_or_self"
on public.trip_members
for delete
to authenticated
using (
  user_id = auth.uid()
  or public.is_trip_owner(trip_id)
);


-- ============================================================
-- 17. TRIP WAYPOINTS RLS
-- Leader controls itinerary in v1
-- ============================================================

create policy "trip_waypoints_select_members"
on public.trip_waypoints
for select
to authenticated
using (
  public.is_trip_member(trip_id)
  or public.is_trip_owner(trip_id)
);


create policy "trip_waypoints_insert_owner"
on public.trip_waypoints
for insert
to authenticated
with check (
  public.is_trip_owner(trip_id)
);


create policy "trip_waypoints_update_owner"
on public.trip_waypoints
for update
to authenticated
using (
  public.is_trip_owner(trip_id)
)
with check (
  public.is_trip_owner(trip_id)
);


create policy "trip_waypoints_delete_owner"
on public.trip_waypoints
for delete
to authenticated
using (
  public.is_trip_owner(trip_id)
);


-- ============================================================
-- 18. CHECKPOINT ATTENDANCE RLS
-- User confirms ONLY their own attendance.
-- ============================================================

create policy "attendance_select_trip_members"
on public.checkpoint_attendance
for select
to authenticated
using (
  exists (
    select 1
    from public.trip_waypoints w
    where w.id = checkpoint_attendance.waypoint_id
      and (
        public.is_trip_member(w.trip_id)
        or public.is_trip_owner(w.trip_id)
      )
  )
);


create policy "attendance_insert_self"
on public.checkpoint_attendance
for insert
to authenticated
with check (
  user_id = auth.uid()

  and exists (
    select 1
    from public.trip_waypoints w
    where w.id = checkpoint_attendance.waypoint_id
      and public.is_trip_member(w.trip_id)
  )
);


create policy "attendance_update_self"
on public.checkpoint_attendance
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


create policy "attendance_delete_self"
on public.checkpoint_attendance
for delete
to authenticated
using (
  user_id = auth.uid()
);