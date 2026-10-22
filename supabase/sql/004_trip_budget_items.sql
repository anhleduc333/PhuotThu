create table if not exists public.trip_budget_items (
  id uuid primary key default gen_random_uuid(),

  trip_id uuid not null
    references public.trips(id)
    on delete cascade,

  category text not null
    check (
      category in (
        'fuel',
        'food',
        'accommodation',
        'toll_ferry',
        'contingency',
        'other'
      )
    ),

  amount_vnd numeric(14, 2) not null default 0
    check (amount_vnd >= 0),

  source text not null default 'manual'
    check (
      source in (
        'system',
        'manual'
      )
    ),

  note text,

  is_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (trip_id, category)
);

create index if not exists
  idx_trip_budget_items_trip_id
on public.trip_budget_items(trip_id);

alter table public.trip_budget_items
enable row level security;


drop policy if exists
  "trip_budget_items_select"
on public.trip_budget_items;

create policy
  "trip_budget_items_select"
on public.trip_budget_items
for select
to authenticated
using (
  public.is_trip_member(trip_id)
);


drop policy if exists
  "trip_budget_items_insert"
on public.trip_budget_items;

create policy
  "trip_budget_items_insert"
on public.trip_budget_items
for insert
to authenticated
with check (
  public.is_trip_owner(trip_id)
);


drop policy if exists
  "trip_budget_items_update"
on public.trip_budget_items;

create policy
  "trip_budget_items_update"
on public.trip_budget_items
for update
to authenticated
using (
  public.is_trip_owner(trip_id)
)
with check (
  public.is_trip_owner(trip_id)
);


drop policy if exists
  "trip_budget_items_delete"
on public.trip_budget_items;

create policy
  "trip_budget_items_delete"
on public.trip_budget_items
for delete
to authenticated
using (
  public.is_trip_owner(trip_id)
);