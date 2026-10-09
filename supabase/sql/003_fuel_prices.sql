create table if not exists public.fuel_prices (
  id uuid primary key default gen_random_uuid(),

  fuel_type text not null
    check (
      fuel_type in (
        'gasoline',
        'diesel',
        'hybrid',
        'other'
      )
    ),

  unit_price_vnd_per_l numeric(14, 2) not null
    check (unit_price_vnd_per_l >= 0),

  source_note text,

  effective_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_fuel_prices_type_effective
on public.fuel_prices (
  fuel_type,
  effective_at desc
);

alter table public.fuel_prices
enable row level security;

drop policy if exists
  "fuel_prices_select_authenticated"
on public.fuel_prices;

create policy
  "fuel_prices_select_authenticated"
on public.fuel_prices
for select
to authenticated
using (true);