create extension if not exists postgis;
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  full_name text not null,
  phone text unique,
  role text not null check (role in ('customer', 'driver', 'admin')) default 'customer',
  avatar_url text,
  stripe_customer_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete cascade,
  make text not null,
  model text not null,
  color text not null,
  plate_number text unique not null,
  year integer check (year >= 2005),
  vehicle_class text not null check (vehicle_class in ('standard','comfort','premium','van')) default 'standard',
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade unique,
  display_name text not null,
  active_vehicle_id uuid references public.vehicles(id) on delete set null,
  is_online boolean not null default false,
  is_busy boolean not null default false,
  verification_status text not null check (verification_status in ('pending','approved','suspended')) default 'pending',
  current_location geography(Point, 4326),
  heading numeric(5,2) default 0.0,
  last_location_update timestamptz,
  rating numeric(3,2) check (rating >= 1.0 and rating <= 5.0) default 5.0,
  stripe_connect_account_id text,
  shift_started_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete restrict,
  driver_id uuid references public.drivers(id) on delete restrict,
  pickup_address text not null,
  pickup_latitude double precision not null,
  pickup_longitude double precision not null,
  dropoff_address text not null,
  dropoff_latitude double precision not null,
  dropoff_longitude double precision not null,
  pickup_location geography(Point, 4326) generated always as (
    st_setsrid(st_makepoint(pickup_longitude, pickup_latitude), 4326)::geography
  ) stored,
  dropoff_location geography(Point, 4326) generated always as (
    st_setsrid(st_makepoint(dropoff_longitude, dropoff_latitude), 4326)::geography
  ) stored,
  vehicle_class text not null check (vehicle_class in ('standard','comfort','premium','van')),
  status text not null check (status in (
    'searching','accepted','driverArriving','arrived','inProgress','completed','cancelled','paymentFailed'
  )) default 'searching',
  estimated_price numeric(10,2),
  final_price numeric(10,2),
  distance_km numeric(10,2),
  duration_minutes integer,
  payment_status text not null check (payment_status in ('pending','authorized','captured','failed','refunded')) default 'pending',
  stripe_payment_intent_id text,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_drivers_current_location
  on public.drivers using gist(current_location);

create index if not exists idx_rides_pickup_location
  on public.rides using gist(pickup_location);

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.drivers enable row level security;
alter table public.rides enable row level security;

create policy "profiles_read_own"
on public.profiles for select
using (id = auth.uid());

create policy "rides_customer_read_own"
on public.rides for select
using (customer_id = auth.uid());

create policy "rides_customer_create_own"
on public.rides for insert
with check (customer_id = auth.uid());

create policy "drivers_read_approved_public"
on public.drivers for select
using (verification_status = 'approved');

create or replace view public.drivers_public_view as
select
  d.id,
  d.display_name,
  d.heading,
  d.rating,
  d.is_busy,
  d.is_online,
  v.vehicle_class,
  concat(v.make, ' ', v.model) as vehicle_name,
  v.plate_number,
  st_y(d.current_location::geometry) as latitude,
  st_x(d.current_location::geometry) as longitude
from public.drivers d
left join public.vehicles v on v.id = d.active_vehicle_id
where d.is_online = true
  and d.verification_status = 'approved';
