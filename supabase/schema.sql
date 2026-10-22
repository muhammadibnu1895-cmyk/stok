-- STOCKFLOW Stage 1. Run once in Supabase SQL Editor.
-- Never expose service_role keys in the frontend.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'petugas' check(role in ('admin','petugas')),
 created_at timestamptz not null default now()
);
create table if not exists public.categories (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 created_at timestamptz not null default now()
);
create table if not exists public.warehouses (
 id uuid primary key default gen_random_uuid(),
 code text not null unique,
 name text not null,
 address text,
 created_at timestamptz not null default now()
);
create table if not exists public.locations (
 id uuid primary key default gen_random_uuid(),
 warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 code text not null,
 name text not null,
 created_at timestamptz not null default now(),
 unique(warehouse_id,code),
 unique(id,warehouse_id)
);
create table if not exists public.products (
 id uuid primary key default gen_random_uuid(),
 sku text not null unique,
 barcode text unique,
 name text not null,
 category_id uuid references public.categories(id) on delete set null,
 unit text not null default 'PCS',
 cost_price numeric(18,2) not null default 0 check(cost_price>=0),
 min_stock numeric(18,3) not null default 0 check(min_stock>=0),
 is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.inventory_balances (
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete restrict,
 warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 location_id uuid not null,
 quantity numeric(18,3) not null default 0 check(quantity>=0),
 updated_at timestamptz not null default now(),
 unique(product_id,location_id),
 foreign key(location_id,warehouse_id) references public.locations(id,warehouse_id)
);
create table if not exists public.audit_logs (
 id bigint generated always as identity primary key,
 actor_id uuid references auth.users(id) on delete set null,
 table_name text not null,
 record_id text not null,
 action text not null,
 old_data jsonb,
 new_data jsonb,
 created_at timestamptz not null default now()
);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists inventory_warehouse_idx on public.inventory_balances(warehouse_id);
create index if not exists locations_warehouse_idx on public.locations(warehouse_id);
create index if not exists audit_logs_created_idx on public.audit_logs(created_at desc);

-- Create a petugas profile automatically. Admin promotion is manual and privileged.
create or replace function public.on_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),'petugas') on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists auth_user_created on auth.users;
create trigger auth_user_created after insert on auth.users for each row execute procedure public.on_new_user();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.warehouses enable row level security;
alter table public.locations enable row level security;
alter table public.products enable row level security;
alter table public.inventory_balances enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles read own or admin" on public.profiles for select to authenticated using(id=(select auth.uid()) or public.is_admin());
-- No direct profile UPDATE policy: prevents role self-escalation.
create policy "categories read" on public.categories for select to authenticated using(true);
create policy "categories admin insert" on public.categories for insert to authenticated with check(public.is_admin());
create policy "categories admin update" on public.categories for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "warehouses read" on public.warehouses for select to authenticated using(true);
create policy "warehouses admin insert" on public.warehouses for insert to authenticated with check(public.is_admin());
create policy "warehouses admin update" on public.warehouses for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "locations read" on public.locations for select to authenticated using(true);
create policy "locations admin insert" on public.locations for insert to authenticated with check(public.is_admin());
create policy "locations admin update" on public.locations for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "products read" on public.products for select to authenticated using(true);
create policy "products admin insert" on public.products for insert to authenticated with check(public.is_admin());
create policy "products admin update" on public.products for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "inventory read" on public.inventory_balances for select to authenticated using(true);
create policy "audit admin read" on public.audit_logs for select to authenticated using(public.is_admin());
-- No client-side inventory or audit INSERT/UPDATE/DELETE policies.

create or replace function public.audit_master_changes() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.audit_logs(actor_id,table_name,record_id,action,old_data,new_data)
 values((select auth.uid()),TG_TABLE_NAME,coalesce(new.id,old.id)::text,TG_OP,
 case when TG_OP='INSERT' then null else to_jsonb(old) end,
 case when TG_OP='DELETE' then null else to_jsonb(new) end);
 return coalesce(new,old);
end; $$;
do $$ declare t text; begin
 foreach t in array array['categories','products','warehouses','locations'] loop
  execute format('drop trigger if exists audit_%I on public.%I',t,t);
  execute format('create trigger audit_%I after insert or update or delete on public.%I for each row execute function public.audit_master_changes()',t,t);
 end loop;
end $$;

-- After creating a real user in Supabase Auth, promote ONE trusted user via SQL Editor:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='admin@yourcompany.com');
-- Future stages must implement stock mutation via server-side transactional RPC, not direct balance writes.
