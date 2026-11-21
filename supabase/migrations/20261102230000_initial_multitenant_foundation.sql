create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to authenticated;

create type public.membership_role as enum (
  'owner',
  'manager',
  'receptionist',
  'professional',
  'finance'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tenants (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.membership_role not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, user_id)
);

create index memberships_user_id_idx on public.memberships (user_id);

create table public.clients (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 160),
  phone text,
  email text,
  birth_date date,
  notes text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index clients_tenant_created_at_idx
  on public.clients (tenant_id, created_at desc);
create index clients_tenant_name_idx
  on public.clients (tenant_id, name);

create function app_private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function app_private.set_updated_at();

create trigger tenants_set_updated_at
before update on public.tenants
for each row execute function app_private.set_updated_at();

create trigger clients_set_updated_at
before update on public.clients
for each row execute function app_private.set_updated_at();

create function app_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function app_private.handle_new_user();

create function app_private.is_tenant_member(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = _tenant_id
      and m.user_id = (select auth.uid())
  );
$$;

create function app_private.has_tenant_role(
  _tenant_id uuid,
  _roles public.membership_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = _tenant_id
      and m.user_id = (select auth.uid())
      and m.role = any (_roles)
  );
$$;

revoke all on function app_private.is_tenant_member(uuid) from public, anon;
revoke all on function app_private.has_tenant_role(uuid, public.membership_role[]) from public, anon;
grant execute on function app_private.is_tenant_member(uuid) to authenticated;
grant execute on function app_private.has_tenant_role(uuid, public.membership_role[]) to authenticated;

create function public.create_tenant(_name text, _slug text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_tenant_id uuid;
  current_user_id uuid := auth.uid();
  clean_name text := btrim(_name);
  clean_slug text := lower(btrim(_slug));
begin
  if current_user_id is null then
    raise exception 'Authentication is required to create a tenant'
      using errcode = '28000';
  end if;

  if clean_name is null or char_length(clean_name) not between 2 and 120 then
    raise exception 'Tenant name must contain between 2 and 120 characters'
      using errcode = '22023';
  end if;

  if clean_slug is null
    or char_length(clean_slug) not between 3 and 60
    or clean_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
  then
    raise exception 'Tenant slug must be 3-60 lowercase letters, numbers, or hyphens'
      using errcode = '22023';
  end if;

  insert into public.tenants (name, slug)
  values (clean_name, clean_slug)
  returning id into new_tenant_id;

  insert into public.memberships (tenant_id, user_id, role)
  values (new_tenant_id, current_user_id, 'owner');

  return new_tenant_id;
end;
$$;

revoke all on function public.create_tenant(text, text) from public, anon;
grant execute on function public.create_tenant(text, text) to authenticated;

alter table public.profiles enable row level security;
alter table public.tenants enable row level security;
alter table public.memberships enable row level security;
alter table public.clients enable row level security;

create policy "Users can read their own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Members can read their tenants"
on public.tenants for select
to authenticated
using ((select app_private.is_tenant_member(id)));

create policy "Owners can update their tenants"
on public.tenants for update
to authenticated
using (
  (select app_private.has_tenant_role(id, array['owner']::public.membership_role[]))
)
with check (
  (select app_private.has_tenant_role(id, array['owner']::public.membership_role[]))
);

create policy "Members can read tenant memberships"
on public.memberships for select
to authenticated
using ((select app_private.is_tenant_member(tenant_id)));

create policy "Members can read tenant clients"
on public.clients for select
to authenticated
using ((select app_private.is_tenant_member(tenant_id)));

create policy "Operators can create tenant clients"
on public.clients for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and (select app_private.has_tenant_role(
    tenant_id,
    array['owner', 'manager', 'receptionist']::public.membership_role[]
  ))
);

create policy "Operators can update tenant clients"
on public.clients for update
to authenticated
using (
  (select app_private.has_tenant_role(
    tenant_id,
    array['owner', 'manager', 'receptionist']::public.membership_role[]
  ))
)
with check (
  (select app_private.has_tenant_role(
    tenant_id,
    array['owner', 'manager', 'receptionist']::public.membership_role[]
  ))
);

create policy "Managers can delete tenant clients"
on public.clients for delete
to authenticated
using (
  (select app_private.has_tenant_role(
    tenant_id,
    array['owner', 'manager']::public.membership_role[]
  ))
);

grant select, update on public.profiles to authenticated;
grant select, update on public.tenants to authenticated;
grant select on public.memberships to authenticated;
grant select, insert, update, delete on public.clients to authenticated;
grant usage on type public.membership_role to authenticated;
