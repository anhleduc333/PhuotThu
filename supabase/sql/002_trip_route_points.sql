create or replace function public.get_trip_route_points(
  p_trip_id uuid
)
returns table (
  trip_id uuid,
  start_lat double precision,
  start_lng double precision,
  destination_lat double precision,
  destination_lng double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    t.id as trip_id,

    case
      when t.start_location is null then null
      else st_y(t.start_location::geometry)
    end as start_lat,

    case
      when t.start_location is null then null
      else st_x(t.start_location::geometry)
    end as start_lng,

    case
      when t.destination_location is null then null
      else st_y(t.destination_location::geometry)
    end as destination_lat,

    case
      when t.destination_location is null then null
      else st_x(t.destination_location::geometry)
    end as destination_lng

  from public.trips t
  where t.id = p_trip_id;
$$;

revoke all
on function public.get_trip_route_points(uuid)
from public;

grant execute
on function public.get_trip_route_points(uuid)
to authenticated;