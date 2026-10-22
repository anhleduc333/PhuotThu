create or replace function public.refresh_trip_estimated_min_cost(
  p_trip_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric(14, 2);
begin
  select coalesce(
    sum(amount_vnd) filter (where is_enabled = true),
    0
  )
  into v_total
  from public.trip_budget_items
  where trip_id = p_trip_id;

  update public.trips
  set estimated_min_cost = v_total
  where id = p_trip_id;
end;
$$;


create or replace function public.handle_trip_budget_items_total()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_trip_estimated_min_cost(
      old.trip_id
    );

    return old;
  end if;

  perform public.refresh_trip_estimated_min_cost(
    new.trip_id
  );

  if tg_op = 'UPDATE'
     and old.trip_id is distinct from new.trip_id then
    perform public.refresh_trip_estimated_min_cost(
      old.trip_id
    );
  end if;

  return new;
end;
$$;


drop trigger if exists
  trg_trip_budget_items_total
on public.trip_budget_items;


create trigger trg_trip_budget_items_total
after insert or update or delete
on public.trip_budget_items
for each row
execute function
  public.handle_trip_budget_items_total();