create extension if not exists btree_gist with schema extensions;

create type public.appointment_status as enum (
  'pending',
  'confirmed',
  'in_service',
  'completed',
  'cancelled',
  'no_show'
);

create type public.financial_direction as enum ('income', 'expense');
create type public.financial_status as enum ('pending', 'paid', 'cancelled');
create type public.payment_method as enum (
  'cash',
  'pix',
  'debit_card',
  'credit_card',
  'bank_transfer',
  'other'
);
create type public.commission_status as enum ('pending', 'partial', 'paid');
create type public.inventory_movement_type as enum (
  'purchase',
  'sale',
  'consumption',
  'return',
  'adjustment_in',
  'adjustment_out'
);

create table public.permissions (
  permission_key text primary key
    check (permission_key ~ '^[a-z_]+(\.[a-z_]+)+$'),
  description text not null
);

create table public.role_permissions (
  role public.membership_role not null,
  permission_key text not null references public.permissions (permission_key) on delete cascade,
  primary key (role, permission_key)
);

insert into public.permissions (permission_key, description)
values
  ('tenant.read', 'Consultar dados do estabelecimento'),
  ('tenant.manage', 'Alterar dados do estabelecimento e unidades'),
  ('members.read', 'Consultar membros do estabelecimento'),
  ('members.manage', 'Gerenciar membros e papéis'),
  ('clients.read', 'Consultar clientes'),
  ('clients.manage', 'Criar e alterar clientes'),
  ('clients.delete', 'Excluir clientes'),
  ('professionals.read', 'Consultar profissionais'),
  ('professionals.manage', 'Gerenciar profissionais'),
  ('services.read', 'Consultar serviços'),
  ('services.manage', 'Gerenciar serviços e categorias'),
  ('appointments.read', 'Consultar a agenda do estabelecimento'),
  ('appointments.own', 'Consultar e atualizar agendamentos próprios'),
  ('appointments.manage', 'Gerenciar a agenda do estabelecimento'),
  ('appointments.delete', 'Excluir agendamentos'),
  ('finance.read', 'Consultar dados financeiros'),
  ('finance.manage', 'Gerenciar lançamentos e sessões de caixa'),
  ('commissions.read', 'Consultar comissões do estabelecimento'),
  ('commissions.read_own', 'Consultar comissões próprias'),
  ('commissions.manage', 'Gerenciar e pagar comissões'),
  ('inventory.read', 'Consultar produtos e estoque'),
  ('inventory.manage', 'Gerenciar produtos e movimentações de estoque'),
  ('settings.read', 'Consultar configurações'),
  ('settings.manage', 'Gerenciar configurações'),
  ('reports.read', 'Consultar relatórios'),
  ('audit.read', 'Consultar trilha de auditoria');

insert into public.role_permissions (role, permission_key)
select 'owner'::public.membership_role, permission_key
from public.permissions;

insert into public.role_permissions (role, permission_key)
values
  ('manager', 'tenant.read'),
  ('manager', 'members.read'),
  ('manager', 'clients.read'),
  ('manager', 'clients.manage'),
  ('manager', 'clients.delete'),
  ('manager', 'professionals.read'),
  ('manager', 'professionals.manage'),
  ('manager', 'services.read'),
  ('manager', 'services.manage'),
  ('manager', 'appointments.read'),
  ('manager', 'appointments.manage'),
  ('manager', 'appointments.delete'),
  ('manager', 'finance.read'),
  ('manager', 'finance.manage'),
  ('manager', 'commissions.read'),
  ('manager', 'commissions.manage'),
  ('manager', 'inventory.read'),
  ('manager', 'inventory.manage'),
  ('manager', 'settings.read'),
  ('manager', 'settings.manage'),
  ('manager', 'reports.read'),
  ('manager', 'audit.read'),
  ('receptionist', 'tenant.read'),
  ('receptionist', 'clients.read'),
  ('receptionist', 'clients.manage'),
  ('receptionist', 'professionals.read'),
  ('receptionist', 'services.read'),
  ('receptionist', 'appointments.read'),
  ('receptionist', 'appointments.manage'),
  ('receptionist', 'settings.read'),
  ('professional', 'tenant.read'),
  ('professional', 'services.read'),
  ('professional', 'appointments.own'),
  ('professional', 'commissions.read_own'),
  ('finance', 'tenant.read'),
  ('finance', 'professionals.read'),
  ('finance', 'services.read'),
  ('finance', 'appointments.read'),
  ('finance', 'finance.read'),
  ('finance', 'finance.manage'),
  ('finance', 'commissions.read'),
  ('finance', 'commissions.manage'),
  ('finance', 'reports.read');

create table public.tenant_units (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 120),
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  tax_id text,
  phone text,
  email text,
  postal_code text,
  street text,
  street_number text,
  address_complement text,
  neighborhood text,
  city text,
  state text,
  timezone text not null default 'America/Sao_Paulo',
  is_primary boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, slug),
  check (timezone <> '')
);

create unique index tenant_units_one_primary_idx
  on public.tenant_units (tenant_id)
  where is_primary;

create table public.tenant_settings (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  settings jsonb not null default '{}'::jsonb
    check (jsonb_typeof(settings) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.unit_business_hours (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  unit_id uuid not null,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, unit_id, weekday),
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete cascade,
  check (opens_at < closes_at)
);

create table public.service_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, name)
);

create table public.professionals (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  name text not null check (char_length(btrim(name)) between 1 and 160),
  email text,
  phone text,
  specialties text[] not null default '{}',
  commission_type text not null default 'none'
    check (commission_type in ('none', 'percentage', 'fixed_per_service')),
  commission_value numeric(12, 2) not null default 0
    check (commission_value >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, user_id),
  check (commission_type <> 'percentage' or commission_value <= 100)
);

create index professionals_tenant_name_idx
  on public.professionals (tenant_id, name);

create table public.services (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  category_id uuid,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  description text,
  price numeric(12, 2) not null check (price >= 0),
  duration_minutes smallint not null check (duration_minutes between 5 and 1440),
  commission_type text
    check (commission_type is null or commission_type in ('percentage', 'fixed_per_service')),
  commission_value numeric(12, 2)
    check (commission_value is null or commission_value >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, category_id)
    references public.service_categories (tenant_id, id) on delete restrict,
  check (
    commission_type is distinct from 'percentage'
    or commission_value is null
    or commission_value <= 100
  )
);

create index services_tenant_active_name_idx
  on public.services (tenant_id, is_active, name);

create table public.professional_services (
  tenant_id uuid not null,
  professional_id uuid not null,
  service_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (tenant_id, professional_id, service_id),
  foreign key (tenant_id, professional_id)
    references public.professionals (tenant_id, id) on delete cascade,
  foreign key (tenant_id, service_id)
    references public.services (tenant_id, id) on delete cascade
);

create table public.professional_working_hours (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  unit_id uuid not null,
  professional_id uuid not null,
  weekday smallint not null check (weekday between 0 and 6),
  starts_at time not null,
  ends_at time not null,
  break_starts_at time,
  break_ends_at time,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, unit_id, professional_id, weekday),
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete cascade,
  foreign key (tenant_id, professional_id)
    references public.professionals (tenant_id, id) on delete cascade,
  check (starts_at < ends_at),
  check (
    (break_starts_at is null and break_ends_at is null)
    or (
      break_starts_at is not null
      and break_ends_at is not null
      and starts_at <= break_starts_at
      and break_starts_at < break_ends_at
      and break_ends_at <= ends_at
    )
  )
);

create table public.professional_time_off (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  professional_id uuid not null,
  unit_id uuid,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, professional_id)
    references public.professionals (tenant_id, id) on delete cascade,
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete cascade,
  check (starts_at < ends_at)
);

alter table public.clients
  add constraint clients_tenant_id_id_key unique (tenant_id, id);

create table public.appointments (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  unit_id uuid not null,
  client_id uuid not null,
  professional_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.appointment_status not null default 'pending',
  notes text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete restrict,
  foreign key (tenant_id, client_id)
    references public.clients (tenant_id, id) on delete restrict,
  foreign key (tenant_id, professional_id)
    references public.professionals (tenant_id, id) on delete restrict,
  check (starts_at < ends_at),
  exclude using gist (
    tenant_id extensions.gist_uuid_ops with =,
    professional_id extensions.gist_uuid_ops with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (status in ('pending', 'confirmed', 'in_service')),
  exclude using gist (
    tenant_id extensions.gist_uuid_ops with =,
    client_id extensions.gist_uuid_ops with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (status in ('pending', 'confirmed', 'in_service'))
);

create index appointments_tenant_starts_at_idx
  on public.appointments (tenant_id, starts_at);
create index appointments_professional_starts_at_idx
  on public.appointments (tenant_id, professional_id, starts_at);
create index appointments_client_starts_at_idx
  on public.appointments (tenant_id, client_id, starts_at desc);

create table public.appointment_items (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  appointment_id uuid not null,
  service_id uuid not null,
  quantity smallint not null default 1 check (quantity between 1 and 99),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  duration_minutes smallint not null check (duration_minutes between 5 and 1440),
  service_name text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, appointment_id, service_id),
  foreign key (tenant_id, appointment_id)
    references public.appointments (tenant_id, id) on delete cascade,
  foreign key (tenant_id, service_id)
    references public.services (tenant_id, id) on delete restrict
);

create table public.appointment_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  appointment_id uuid not null,
  old_status public.appointment_status,
  new_status public.appointment_status not null,
  changed_by uuid references public.profiles (id) on delete set null,
  changed_at timestamptz not null default now(),
  foreign key (tenant_id, appointment_id)
    references public.appointments (tenant_id, id) on delete cascade
);

create index appointment_status_history_appointment_idx
  on public.appointment_status_history (tenant_id, appointment_id, changed_at desc);

create table public.cash_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  unit_id uuid not null,
  opened_by uuid not null references public.profiles (id) on delete restrict,
  closed_by uuid references public.profiles (id) on delete restrict,
  opening_amount numeric(12, 2) not null default 0 check (opening_amount >= 0),
  closing_amount numeric(12, 2) check (closing_amount is null or closing_amount >= 0),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, id, unit_id),
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete restrict,
  check (
    (closed_at is null and closed_by is null and closing_amount is null)
    or (closed_at is not null and closed_by is not null and closing_amount is not null)
  )
);

create unique index cash_sessions_one_open_per_unit_idx
  on public.cash_sessions (tenant_id, unit_id)
  where closed_at is null;

create table public.financial_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  unit_id uuid,
  cash_session_id uuid,
  client_id uuid,
  appointment_id uuid,
  direction public.financial_direction not null,
  status public.financial_status not null default 'pending',
  category text not null check (char_length(btrim(category)) between 1 and 80),
  description text not null check (char_length(btrim(description)) between 1 and 240),
  amount numeric(12, 2) not null check (amount > 0),
  due_on date,
  paid_at timestamptz,
  payment_method public.payment_method,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete restrict,
  foreign key (tenant_id, client_id)
    references public.clients (tenant_id, id) on delete restrict,
  foreign key (tenant_id, appointment_id)
    references public.appointments (tenant_id, id) on delete restrict,
  foreign key (tenant_id, cash_session_id, unit_id)
    references public.cash_sessions (tenant_id, id, unit_id) on delete restrict,
  check (
    (status = 'paid' and paid_at is not null and payment_method is not null)
    or status <> 'paid'
  ),
  check (status <> 'cancelled' or paid_at is null),
  check (cash_session_id is null or unit_id is not null)
);

create index financial_transactions_tenant_status_due_idx
  on public.financial_transactions (tenant_id, status, due_on);
create index financial_transactions_tenant_paid_idx
  on public.financial_transactions (tenant_id, paid_at desc)
  where status = 'paid';

create table public.commissions (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  appointment_id uuid not null,
  appointment_item_id uuid not null,
  professional_id uuid not null,
  amount numeric(12, 2) not null check (amount >= 0),
  paid_amount numeric(12, 2) not null default 0 check (paid_amount >= 0),
  status public.commission_status not null default 'pending',
  accrued_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, appointment_item_id),
  foreign key (tenant_id, appointment_id)
    references public.appointments (tenant_id, id) on delete restrict,
  foreign key (tenant_id, appointment_item_id)
    references public.appointment_items (tenant_id, id) on delete restrict,
  foreign key (tenant_id, professional_id)
    references public.professionals (tenant_id, id) on delete restrict,
  check (paid_amount <= amount),
  check (
    (status = 'pending' and paid_amount = 0)
    or (status = 'partial' and paid_amount > 0 and paid_amount < amount)
    or (status = 'paid' and paid_amount = amount)
  )
);

create index commissions_tenant_status_idx
  on public.commissions (tenant_id, status, accrued_at desc);
create index commissions_professional_idx
  on public.commissions (tenant_id, professional_id, accrued_at desc);

create table public.commission_payments (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  commission_id uuid not null,
  amount numeric(12, 2) not null check (amount > 0),
  payment_method public.payment_method not null,
  paid_at timestamptz not null default now(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (tenant_id, commission_id)
    references public.commissions (tenant_id, id) on delete restrict
);

create table public.product_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, name)
);

create table public.products (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  category_id uuid,
  sku text,
  name text not null check (char_length(btrim(name)) between 1 and 160),
  description text,
  unit_of_measure text not null default 'unit'
    check (unit_of_measure in ('unit', 'ml', 'g', 'kg', 'l', 'package')),
  cost_price numeric(12, 2) not null default 0 check (cost_price >= 0),
  sale_price numeric(12, 2) not null default 0 check (sale_price >= 0),
  minimum_stock numeric(12, 3) not null default 0 check (minimum_stock >= 0),
  stock_quantity numeric(12, 3) not null default 0 check (stock_quantity >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, sku),
  foreign key (tenant_id, category_id)
    references public.product_categories (tenant_id, id) on delete restrict
);

create index products_tenant_name_idx on public.products (tenant_id, name);
create index products_low_stock_idx
  on public.products (tenant_id, stock_quantity, minimum_stock)
  where is_active;

create table public.inventory_movements (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  unit_id uuid,
  product_id uuid not null,
  movement_type public.inventory_movement_type not null,
  quantity numeric(12, 3) not null check (quantity > 0),
  unit_cost numeric(12, 2) check (unit_cost is null or unit_cost >= 0),
  reference text,
  notes text,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (tenant_id, unit_id)
    references public.tenant_units (tenant_id, id) on delete restrict,
  foreign key (tenant_id, product_id)
    references public.products (tenant_id, id) on delete restrict
);

create index inventory_movements_product_idx
  on public.inventory_movements (tenant_id, product_id, created_at desc);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  tenant_id uuid not null,
  table_name text not null,
  record_id uuid not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  changed_fields text[] not null default '{}',
  actor_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index audit_logs_tenant_created_idx
  on public.audit_logs (tenant_id, created_at desc);
create index audit_logs_record_idx
  on public.audit_logs (tenant_id, table_name, record_id, created_at desc);

create function app_private.has_tenant_permission(
  _tenant_id uuid,
  _permission_key text
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
    join public.role_permissions rp on rp.role = m.role
    where m.tenant_id = _tenant_id
      and m.user_id = (select auth.uid())
      and rp.permission_key = _permission_key
  );
$$;

create function app_private.is_assigned_professional(
  _tenant_id uuid,
  _professional_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.professionals p
    join public.memberships m
      on m.tenant_id = p.tenant_id
     and m.user_id = p.user_id
    where p.tenant_id = _tenant_id
      and p.id = _professional_id
      and p.user_id = (select auth.uid())
      and m.role = 'professional'
  );
$$;

create function app_private.can_read_client(
  _tenant_id uuid,
  _client_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.has_tenant_permission(_tenant_id, 'clients.read')
    or exists (
      select 1
      from public.appointments a
      where a.tenant_id = _tenant_id
        and a.client_id = _client_id
        and app_private.is_assigned_professional(
          a.tenant_id,
          a.professional_id
        )
    );
$$;

revoke all on function app_private.has_tenant_permission(uuid, text) from public, anon;
revoke all on function app_private.is_assigned_professional(uuid, uuid) from public, anon;
revoke all on function app_private.can_read_client(uuid, uuid) from public, anon;
grant execute on function app_private.has_tenant_permission(uuid, text) to authenticated;
grant execute on function app_private.is_assigned_professional(uuid, uuid) to authenticated;
grant execute on function app_private.can_read_client(uuid, uuid) to authenticated;

create function app_private.prevent_tenant_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tenant_id is distinct from old.tenant_id then
    raise exception 'Moving records between tenants is not allowed'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create function app_private.validate_appointment_schedule()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  unit_timezone text;
  local_start timestamp;
  local_end timestamp;
  local_weekday smallint;
  local_start_time time;
  local_end_time time;
begin
  if new.status not in ('pending', 'confirmed', 'in_service') then
    return new;
  end if;

  select u.timezone
    into unit_timezone
  from public.tenant_units u
  where u.tenant_id = new.tenant_id
    and u.id = new.unit_id
    and u.is_active;

  if unit_timezone is null then
    raise exception 'The selected unit is not active or does not belong to this tenant'
      using errcode = '23514';
  end if;

  local_start := new.starts_at at time zone unit_timezone;
  local_end := new.ends_at at time zone unit_timezone;

  if local_start::date <> local_end::date then
    raise exception 'Appointments must start and end on the same local day'
      using errcode = '23514';
  end if;

  local_weekday := extract(isodow from local_start)::smallint - 1;
  local_start_time := local_start::time;
  local_end_time := local_end::time;

  if not exists (
    select 1
    from public.unit_business_hours h
    where h.tenant_id = new.tenant_id
      and h.unit_id = new.unit_id
      and h.weekday = local_weekday
      and h.opens_at <= local_start_time
      and h.closes_at >= local_end_time
  ) then
    raise exception 'The appointment is outside the unit business hours'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.professional_working_hours h
    where h.tenant_id = new.tenant_id
      and h.unit_id = new.unit_id
      and h.professional_id = new.professional_id
      and h.weekday = local_weekday
      and h.starts_at <= local_start_time
      and h.ends_at >= local_end_time
      and (
        h.break_starts_at is null
        or local_end_time <= h.break_starts_at
        or local_start_time >= h.break_ends_at
      )
  ) then
    raise exception 'The professional is not scheduled for the selected time'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.professional_time_off t
    where t.tenant_id = new.tenant_id
      and t.professional_id = new.professional_id
      and (t.unit_id is null or t.unit_id = new.unit_id)
      and t.starts_at < new.ends_at
      and t.ends_at > new.starts_at
  ) then
    raise exception 'The professional is unavailable during the selected time'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function app_private.validate_appointment_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
    and not app_private.has_tenant_permission(new.tenant_id, 'appointments.manage')
    and app_private.is_assigned_professional(old.tenant_id, old.professional_id)
    and (
      new.tenant_id is distinct from old.tenant_id
      or new.unit_id is distinct from old.unit_id
      or new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.starts_at is distinct from old.starts_at
      or new.ends_at is distinct from old.ends_at
      or new.created_by is distinct from old.created_by
    )
  then
    raise exception 'Professionals may only update the status and notes of their appointments'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if old.status in ('completed', 'cancelled', 'no_show') then
      raise exception 'A final appointment status cannot be changed'
        using errcode = '23514';
    end if;

    if old.status = 'pending'
      and new.status not in ('confirmed', 'cancelled', 'no_show')
    then
      raise exception 'Invalid appointment status transition'
        using errcode = '23514';
    end if;

    if old.status = 'confirmed'
      and new.status not in ('in_service', 'completed', 'cancelled', 'no_show')
    then
      raise exception 'Invalid appointment status transition'
        using errcode = '23514';
    end if;

    if old.status = 'in_service'
      and new.status not in ('completed', 'cancelled')
    then
      raise exception 'Invalid appointment status transition'
        using errcode = '23514';
    end if;
  end if;

  if new.status = 'completed' and not exists (
    select 1
    from public.appointment_items i
    where i.tenant_id = new.tenant_id
      and i.appointment_id = new.id
  ) then
    raise exception 'An appointment needs at least one service before completion'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function app_private.record_appointment_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.appointment_status_history (
      tenant_id, appointment_id, old_status, new_status, changed_by
    )
    values (
      new.tenant_id, new.id, null, new.status, auth.uid()
    );
  elsif new.status is distinct from old.status then
    insert into public.appointment_status_history (
      tenant_id, appointment_id, old_status, new_status, changed_by
    )
    values (
      new.tenant_id, new.id, old.status, new.status, auth.uid()
    );
  end if;

  return new;
end;
$$;

create function app_private.accrue_appointment_commissions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'completed'
    and (tg_op = 'INSERT' or old.status is distinct from 'completed')
  then
    insert into public.commissions (
      tenant_id,
      appointment_id,
      appointment_item_id,
      professional_id,
      amount
    )
    select
      new.tenant_id,
      new.id,
      i.id,
      new.professional_id,
      case coalesce(s.commission_type, p.commission_type)
        when 'percentage' then round(
          i.unit_price * i.quantity
          * coalesce(s.commission_value, p.commission_value) / 100,
          2
        )
        when 'fixed_per_service' then
          coalesce(s.commission_value, p.commission_value) * i.quantity
        else 0
      end
    from public.appointment_items i
    join public.services s
      on s.tenant_id = i.tenant_id
     and s.id = i.service_id
    join public.professionals p
      on p.tenant_id = new.tenant_id
     and p.id = new.professional_id
    where i.tenant_id = new.tenant_id
      and i.appointment_id = new.id
      and (
        case coalesce(s.commission_type, p.commission_type)
          when 'percentage' then round(
            i.unit_price * i.quantity
            * coalesce(s.commission_value, p.commission_value) / 100,
            2
          )
          when 'fixed_per_service' then
            coalesce(s.commission_value, p.commission_value) * i.quantity
          else 0
        end
      ) > 0
    on conflict (tenant_id, appointment_item_id) do nothing;
  end if;

  return new;
end;
$$;

create function app_private.prevent_completed_appointment_item_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_status public.appointment_status;
  appointment_professional_id uuid;
begin
  select a.status, a.professional_id
    into current_status, appointment_professional_id
  from public.appointments a
  where a.tenant_id = new.tenant_id
    and a.id = new.appointment_id;

  if current_status is null or current_status in ('completed', 'cancelled', 'no_show') then
    raise exception 'Services cannot be added to a final appointment'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.professional_services ps
    join public.services s
      on s.tenant_id = ps.tenant_id
     and s.id = ps.service_id
    where ps.tenant_id = new.tenant_id
      and ps.professional_id = appointment_professional_id
      and ps.service_id = new.service_id
      and s.is_active
  ) then
    raise exception 'The selected service is not active or not assigned to this professional'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function app_private.validate_time_off()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.appointments a
    where a.tenant_id = new.tenant_id
      and a.professional_id = new.professional_id
      and a.status in ('pending', 'confirmed', 'in_service')
      and (new.unit_id is null or a.unit_id = new.unit_id)
      and a.starts_at < new.ends_at
      and a.ends_at > new.starts_at
  ) then
    raise exception 'Time off cannot overlap an active appointment'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function app_private.apply_inventory_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  quantity_delta numeric(12, 3);
begin
  quantity_delta := case new.movement_type
    when 'purchase' then new.quantity
    when 'return' then new.quantity
    when 'adjustment_in' then new.quantity
    when 'sale' then -new.quantity
    when 'consumption' then -new.quantity
    when 'adjustment_out' then -new.quantity
  end;

  update public.products p
  set stock_quantity = p.stock_quantity + quantity_delta,
      updated_at = now()
  where p.tenant_id = new.tenant_id
    and p.id = new.product_id
    and p.stock_quantity + quantity_delta >= 0;

  if not found then
    if exists (
      select 1 from public.products p
      where p.tenant_id = new.tenant_id and p.id = new.product_id
    ) then
      raise exception 'The movement would result in negative inventory'
        using errcode = '23514';
    end if;

    raise exception 'Product does not belong to the movement tenant'
      using errcode = '23503';
  end if;

  return new;
end;
$$;

create function app_private.apply_commission_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.commissions c
  set paid_amount = c.paid_amount + new.amount,
      status = case
        when c.paid_amount + new.amount = c.amount then 'paid'::public.commission_status
        else 'partial'::public.commission_status
      end
  where c.tenant_id = new.tenant_id
    and c.id = new.commission_id
    and c.paid_amount + new.amount <= c.amount;

  if not found then
    raise exception 'Commission payment exceeds the unpaid balance'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function app_private.record_audit_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_row jsonb;
  new_row jsonb;
  record_tenant_id uuid;
  record_id uuid;
  changed text[];
begin
  if tg_op <> 'INSERT' then
    old_row := to_jsonb(old);
  end if;
  if tg_op <> 'DELETE' then
    new_row := to_jsonb(new);
  end if;

  record_tenant_id := coalesce(
    (new_row ->> 'tenant_id')::uuid,
    (old_row ->> 'tenant_id')::uuid,
    (new_row ->> 'id')::uuid,
    (old_row ->> 'id')::uuid
  );
  record_id := coalesce(
    (new_row ->> 'id')::uuid,
    (old_row ->> 'id')::uuid,
    (new_row ->> 'tenant_id')::uuid,
    (old_row ->> 'tenant_id')::uuid
  );

  if tg_op = 'INSERT' then
    select coalesce(array_agg(k order by k), '{}')
      into changed
    from jsonb_object_keys(new_row) as keys(k);
  elsif tg_op = 'DELETE' then
    select coalesce(array_agg(k order by k), '{}')
      into changed
    from jsonb_object_keys(old_row) as keys(k);
  else
    select coalesce(array_agg(keys.k order by keys.k), '{}')
      into changed
    from (
      select jsonb_object_keys(old_row) as k
      union
      select jsonb_object_keys(new_row) as k
    ) as keys
    where old_row -> keys.k is distinct from new_row -> keys.k;
  end if;

  insert into public.audit_logs (
    tenant_id, table_name, record_id, action, changed_fields, actor_id
  )
  values (
    record_tenant_id, tg_table_name, record_id, tg_op, changed, auth.uid()
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create function app_private.apply_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function app_private.validate_unit_timezone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_timezone_names z
    where z.name = new.timezone
  ) then
    raise exception 'Unknown IANA time zone'
      using errcode = '22023';
  end if;

  return new;
end;
$$;

create function public.set_tenant_member_role(
  _tenant_id uuid,
  _user_id uuid,
  _role public.membership_role
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_is_owner boolean;
  other_owner_count bigint;
begin
  if auth.uid() is null
    or not app_private.has_tenant_permission(_tenant_id, 'members.manage')
  then
    raise exception 'Permission to manage tenant members is required'
      using errcode = '42501';
  end if;

  perform 1
  from public.tenants t
  where t.id = _tenant_id
  for update;

  if not app_private.has_tenant_permission(_tenant_id, 'members.manage') then
    raise exception 'Permission to manage tenant members is required'
      using errcode = '42501';
  end if;

  if _role is null then
    raise exception 'A role is required'
      using errcode = '22023';
  end if;

  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = _tenant_id
      and m.user_id = _user_id
      and m.role = 'owner'
  )
  into target_is_owner;

  if target_is_owner and _role <> 'owner' then
    select count(*)
      into other_owner_count
    from public.memberships m
    where m.tenant_id = _tenant_id
      and m.role = 'owner'
      and m.user_id <> _user_id;

    if other_owner_count = 0 then
      raise exception 'A tenant must retain at least one owner'
        using errcode = '23514';
    end if;
  end if;

  insert into public.memberships (tenant_id, user_id, role)
  values (_tenant_id, _user_id, _role)
  on conflict (tenant_id, user_id)
  do update set role = excluded.role;
end;
$$;

create function public.remove_tenant_member(
  _tenant_id uuid,
  _user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_is_owner boolean;
  other_owner_count bigint;
begin
  if auth.uid() is null
    or not app_private.has_tenant_permission(_tenant_id, 'members.manage')
  then
    raise exception 'Permission to manage tenant members is required'
      using errcode = '42501';
  end if;

  perform 1
  from public.tenants t
  where t.id = _tenant_id
  for update;

  if not app_private.has_tenant_permission(_tenant_id, 'members.manage') then
    raise exception 'Permission to manage tenant members is required'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = _tenant_id
      and m.user_id = _user_id
      and m.role = 'owner'
  )
  into target_is_owner;

  if target_is_owner then
    select count(*)
      into other_owner_count
    from public.memberships m
    where m.tenant_id = _tenant_id
      and m.role = 'owner'
      and m.user_id <> _user_id;

    if other_owner_count = 0 then
      raise exception 'A tenant must retain at least one owner'
        using errcode = '23514';
    end if;
  end if;

  delete from public.memberships
  where tenant_id = _tenant_id
    and user_id = _user_id;
end;
$$;

revoke all on function public.set_tenant_member_role(uuid, uuid, public.membership_role)
  from public, anon;
revoke all on function public.remove_tenant_member(uuid, uuid)
  from public, anon;
grant execute on function public.set_tenant_member_role(uuid, uuid, public.membership_role)
  to authenticated;
grant execute on function public.remove_tenant_member(uuid, uuid)
  to authenticated;

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

  insert into public.tenant_units (tenant_id, name, slug, is_primary)
  values (new_tenant_id, clean_name, 'principal', true);

  insert into public.tenant_settings (tenant_id)
  values (new_tenant_id);

  return new_tenant_id;
end;
$$;

revoke all on function public.create_tenant(text, text) from public, anon;
grant execute on function public.create_tenant(text, text) to authenticated;

create trigger tenant_units_set_updated_at
before update on public.tenant_units
for each row execute function app_private.apply_updated_at();
create trigger tenant_units_validate_timezone
before insert or update of timezone on public.tenant_units
for each row execute function app_private.validate_unit_timezone();
create trigger tenant_settings_set_updated_at
before update on public.tenant_settings
for each row execute function app_private.apply_updated_at();
create trigger service_categories_set_updated_at
before update on public.service_categories
for each row execute function app_private.apply_updated_at();
create trigger professionals_set_updated_at
before update on public.professionals
for each row execute function app_private.apply_updated_at();
create trigger services_set_updated_at
before update on public.services
for each row execute function app_private.apply_updated_at();
create trigger appointments_set_updated_at
before update on public.appointments
for each row execute function app_private.apply_updated_at();
create trigger financial_transactions_set_updated_at
before update on public.financial_transactions
for each row execute function app_private.apply_updated_at();
create trigger product_categories_set_updated_at
before update on public.product_categories
for each row execute function app_private.apply_updated_at();
create trigger products_set_updated_at
before update on public.products
for each row execute function app_private.apply_updated_at();

create trigger tenant_units_prevent_tenant_change
before update on public.tenant_units
for each row execute function app_private.prevent_tenant_change();
create trigger tenant_settings_prevent_tenant_change
before update on public.tenant_settings
for each row execute function app_private.prevent_tenant_change();
create trigger unit_business_hours_prevent_tenant_change
before update on public.unit_business_hours
for each row execute function app_private.prevent_tenant_change();
create trigger service_categories_prevent_tenant_change
before update on public.service_categories
for each row execute function app_private.prevent_tenant_change();
create trigger professionals_prevent_tenant_change
before update on public.professionals
for each row execute function app_private.prevent_tenant_change();
create trigger services_prevent_tenant_change
before update on public.services
for each row execute function app_private.prevent_tenant_change();
create trigger professional_services_prevent_tenant_change
before update on public.professional_services
for each row execute function app_private.prevent_tenant_change();
create trigger professional_working_hours_prevent_tenant_change
before update on public.professional_working_hours
for each row execute function app_private.prevent_tenant_change();
create trigger professional_time_off_prevent_tenant_change
before update on public.professional_time_off
for each row execute function app_private.prevent_tenant_change();
create trigger appointments_prevent_tenant_change
before update on public.appointments
for each row execute function app_private.prevent_tenant_change();
create trigger appointment_items_prevent_tenant_change
before update on public.appointment_items
for each row execute function app_private.prevent_tenant_change();
create trigger cash_sessions_prevent_tenant_change
before update on public.cash_sessions
for each row execute function app_private.prevent_tenant_change();
create trigger financial_transactions_prevent_tenant_change
before update on public.financial_transactions
for each row execute function app_private.prevent_tenant_change();
create trigger commissions_prevent_tenant_change
before update on public.commissions
for each row execute function app_private.prevent_tenant_change();
create trigger product_categories_prevent_tenant_change
before update on public.product_categories
for each row execute function app_private.prevent_tenant_change();
create trigger products_prevent_tenant_change
before update on public.products
for each row execute function app_private.prevent_tenant_change();
create trigger inventory_movements_prevent_tenant_change
before update on public.inventory_movements
for each row execute function app_private.prevent_tenant_change();

create trigger appointments_validate_schedule
before insert or update of tenant_id, unit_id, professional_id, starts_at, ends_at
on public.appointments
for each row execute function app_private.validate_appointment_schedule();
create trigger appointments_validate_transition
before insert or update of status on public.appointments
for each row execute function app_private.validate_appointment_transition();
create trigger appointments_record_status
after insert or update of status on public.appointments
for each row execute function app_private.record_appointment_status();
create trigger appointments_accrue_commissions
after insert or update of status on public.appointments
for each row execute function app_private.accrue_appointment_commissions();
create trigger appointment_items_validate_parent
before insert on public.appointment_items
for each row execute function app_private.prevent_completed_appointment_item_changes();
create trigger professional_time_off_validate
before insert or update on public.professional_time_off
for each row execute function app_private.validate_time_off();
create trigger inventory_movements_update_stock
before insert on public.inventory_movements
for each row execute function app_private.apply_inventory_movement();
create trigger commission_payments_update_balance
before insert on public.commission_payments
for each row execute function app_private.apply_commission_payment();

create function app_private.validate_cash_session_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.closed_at is not null then
    raise exception 'A closed cash session cannot be changed'
      using errcode = '23514';
  end if;

  if new.tenant_id is distinct from old.tenant_id
    or new.unit_id is distinct from old.unit_id
    or new.opened_by is distinct from old.opened_by
    or new.opening_amount is distinct from old.opening_amount
    or new.opened_at is distinct from old.opened_at
  then
    raise exception 'Cash session opening details are immutable'
      using errcode = '23514';
  end if;

  if new.closed_at is null then
    raise exception 'A cash session update must close the session'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function app_private.validate_financial_transaction_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status in ('paid', 'cancelled') then
    raise exception 'A paid or cancelled financial transaction is immutable'
      using errcode = '23514';
  end if;

  if new.tenant_id is distinct from old.tenant_id
    or new.unit_id is distinct from old.unit_id
    or new.cash_session_id is distinct from old.cash_session_id
    or new.client_id is distinct from old.client_id
    or new.appointment_id is distinct from old.appointment_id
    or new.direction is distinct from old.direction
    or new.category is distinct from old.category
    or new.description is distinct from old.description
    or new.amount is distinct from old.amount
    or new.due_on is distinct from old.due_on
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'Financial transaction details are immutable; create an adjustment instead'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger cash_sessions_validate_update
before update on public.cash_sessions
for each row execute function app_private.validate_cash_session_update();
create trigger financial_transactions_validate_update
before update on public.financial_transactions
for each row execute function app_private.validate_financial_transaction_update();

create trigger audit_tenant_units
after insert or update or delete on public.tenant_units
for each row execute function app_private.record_audit_log();
create trigger audit_tenants
after insert or update or delete on public.tenants
for each row execute function app_private.record_audit_log();
create trigger audit_tenant_settings
after insert or update or delete on public.tenant_settings
for each row execute function app_private.record_audit_log();
create trigger audit_memberships
after insert or update or delete on public.memberships
for each row execute function app_private.record_audit_log();
create trigger audit_clients
after insert or update or delete on public.clients
for each row execute function app_private.record_audit_log();
create trigger audit_professionals
after insert or update or delete on public.professionals
for each row execute function app_private.record_audit_log();
create trigger audit_services
after insert or update or delete on public.services
for each row execute function app_private.record_audit_log();
create trigger audit_service_categories
after insert or update or delete on public.service_categories
for each row execute function app_private.record_audit_log();
create trigger audit_unit_business_hours
after insert or update or delete on public.unit_business_hours
for each row execute function app_private.record_audit_log();
create trigger audit_professional_working_hours
after insert or update or delete on public.professional_working_hours
for each row execute function app_private.record_audit_log();
create trigger audit_professional_time_off
after insert or update or delete on public.professional_time_off
for each row execute function app_private.record_audit_log();
create trigger audit_appointments
after insert or update or delete on public.appointments
for each row execute function app_private.record_audit_log();
create trigger audit_financial_transactions
after insert or update or delete on public.financial_transactions
for each row execute function app_private.record_audit_log();
create trigger audit_cash_sessions
after insert or update or delete on public.cash_sessions
for each row execute function app_private.record_audit_log();
create trigger audit_commissions
after insert or update or delete on public.commissions
for each row execute function app_private.record_audit_log();
create trigger audit_commission_payments
after insert or update or delete on public.commission_payments
for each row execute function app_private.record_audit_log();
create trigger audit_products
after insert or update or delete on public.products
for each row execute function app_private.record_audit_log();
create trigger audit_inventory_movements
after insert or update or delete on public.inventory_movements
for each row execute function app_private.record_audit_log();

alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.tenant_units enable row level security;
alter table public.tenant_settings enable row level security;
alter table public.unit_business_hours enable row level security;
alter table public.service_categories enable row level security;
alter table public.professionals enable row level security;
alter table public.services enable row level security;
alter table public.professional_services enable row level security;
alter table public.professional_working_hours enable row level security;
alter table public.professional_time_off enable row level security;
alter table public.appointments enable row level security;
alter table public.appointment_items enable row level security;
alter table public.appointment_status_history enable row level security;
alter table public.cash_sessions enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.commissions enable row level security;
alter table public.commission_payments enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.audit_logs enable row level security;

revoke all on table
  public.permissions,
  public.role_permissions,
  public.tenant_units,
  public.tenant_settings,
  public.unit_business_hours,
  public.service_categories,
  public.professionals,
  public.services,
  public.professional_services,
  public.professional_working_hours,
  public.professional_time_off,
  public.appointments,
  public.appointment_items,
  public.appointment_status_history,
  public.cash_sessions,
  public.financial_transactions,
  public.commissions,
  public.commission_payments,
  public.product_categories,
  public.products,
  public.inventory_movements,
  public.audit_logs
from public, anon, authenticated;

revoke all on type
  public.appointment_status,
  public.financial_direction,
  public.financial_status,
  public.payment_method,
  public.commission_status,
  public.inventory_movement_type
from public, anon;

revoke all on function app_private.record_appointment_status() from public, anon, authenticated;
revoke all on function app_private.accrue_appointment_commissions() from public, anon, authenticated;
revoke all on function app_private.apply_inventory_movement() from public, anon, authenticated;
revoke all on function app_private.apply_commission_payment() from public, anon, authenticated;
revoke all on function app_private.record_audit_log() from public, anon, authenticated;

drop policy "Members can read their tenants" on public.tenants;
create policy "Members can read permitted tenants"
on public.tenants for select to authenticated
using ((select app_private.has_tenant_permission(id, 'tenant.read')));

drop policy "Owners can update their tenants" on public.tenants;
create policy "Authorized members can update their tenants"
on public.tenants for update to authenticated
using ((select app_private.has_tenant_permission(id, 'tenant.manage')))
with check ((select app_private.has_tenant_permission(id, 'tenant.manage')));

drop policy "Members can read tenant memberships" on public.memberships;
create policy "Authorized members can read tenant memberships"
on public.memberships for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'members.read')));

drop policy "Members can read tenant clients" on public.clients;
drop policy "Operators can create tenant clients" on public.clients;
drop policy "Operators can update tenant clients" on public.clients;
drop policy "Managers can delete tenant clients" on public.clients;

create policy "Authorized users can read tenant clients"
on public.clients for select to authenticated
using ((select app_private.can_read_client(tenant_id, id)));

create policy "Authorized users can create tenant clients"
on public.clients for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select app_private.has_tenant_permission(tenant_id, 'clients.manage'))
);

create policy "Authorized users can update tenant clients"
on public.clients for update to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'clients.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'clients.manage')));

create policy "Authorized users can delete tenant clients"
on public.clients for delete to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'clients.delete')));

create policy "Authenticated users can read permission catalog"
on public.permissions for select to authenticated using (true);
create policy "Authenticated users can read role permissions"
on public.role_permissions for select to authenticated using (true);

create policy "Members can read tenant units"
on public.tenant_units for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'tenant.read')));
create policy "Managers can create tenant units"
on public.tenant_units for insert to authenticated
with check ((select app_private.has_tenant_permission(tenant_id, 'tenant.manage')));
create policy "Managers can update tenant units"
on public.tenant_units for update to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'tenant.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'tenant.manage')));
create policy "Managers can delete tenant units"
on public.tenant_units for delete to authenticated
using (
  not is_primary
  and (select app_private.has_tenant_permission(tenant_id, 'tenant.manage'))
);

create policy "Members can read tenant settings"
on public.tenant_settings for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'settings.read'))
  or (select app_private.has_tenant_permission(tenant_id, 'settings.manage'))
);
create policy "Managers can create tenant settings"
on public.tenant_settings for insert to authenticated
with check ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')));
create policy "Managers can update tenant settings"
on public.tenant_settings for update to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')));

create policy "Members can read unit business hours"
on public.unit_business_hours for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'appointments.read')));
create policy "Managers can manage unit business hours"
on public.unit_business_hours for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')));

create policy "Members can read service categories"
on public.service_categories for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'services.read')));
create policy "Managers can manage service categories"
on public.service_categories for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'services.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'services.manage')));

create policy "Members can read professionals"
on public.professionals for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'professionals.read'))
  or user_id = (select auth.uid())
);
create policy "Managers can manage professionals"
on public.professionals for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'professionals.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'professionals.manage')));

create policy "Members can read services"
on public.services for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'services.read')));
create policy "Managers can manage services"
on public.services for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'services.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'services.manage')));

create policy "Members can read professional services"
on public.professional_services for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'services.read'))
  or (select app_private.is_assigned_professional(tenant_id, professional_id))
);
create policy "Managers can manage professional services"
on public.professional_services for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'services.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'services.manage')));

create policy "Members can read professional working hours"
on public.professional_working_hours for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.read'))
  or (select app_private.is_assigned_professional(tenant_id, professional_id))
);
create policy "Managers can manage professional working hours"
on public.professional_working_hours for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')));

create policy "Members can read professional time off"
on public.professional_time_off for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.read'))
  or (select app_private.is_assigned_professional(tenant_id, professional_id))
);
create policy "Managers can manage professional time off"
on public.professional_time_off for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'settings.manage')));

create policy "Authorized users can read appointments"
on public.appointments for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.read'))
  or (
    (select app_private.has_tenant_permission(tenant_id, 'appointments.own'))
    and (select app_private.is_assigned_professional(tenant_id, professional_id))
  )
);
create policy "Authorized users can create appointments"
on public.appointments for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select app_private.has_tenant_permission(tenant_id, 'appointments.manage'))
);
create policy "Authorized users can update appointments"
on public.appointments for update to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.manage'))
  or (
    (select app_private.has_tenant_permission(tenant_id, 'appointments.own'))
    and (select app_private.is_assigned_professional(tenant_id, professional_id))
  )
)
with check (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.manage'))
  or (
    (select app_private.has_tenant_permission(tenant_id, 'appointments.own'))
    and (select app_private.is_assigned_professional(tenant_id, professional_id))
  )
);
create policy "Managers can delete appointments"
on public.appointments for delete to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'appointments.delete')));

create policy "Authorized users can read appointment items"
on public.appointment_items for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.read'))
  or exists (
    select 1
    from public.appointments a
    where a.tenant_id = appointment_items.tenant_id
      and a.id = appointment_items.appointment_id
      and (select app_private.is_assigned_professional(a.tenant_id, a.professional_id))
  )
);
create policy "Managers can add appointment items"
on public.appointment_items for insert to authenticated
with check (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.manage'))
);

create policy "Authorized users can read appointment status history"
on public.appointment_status_history for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'appointments.read'))
  or exists (
    select 1
    from public.appointments a
    where a.tenant_id = appointment_status_history.tenant_id
      and a.id = appointment_status_history.appointment_id
      and (select app_private.is_assigned_professional(a.tenant_id, a.professional_id))
  )
);

create policy "Finance users can read cash sessions"
on public.cash_sessions for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'finance.read')));
create policy "Finance users can create cash sessions"
on public.cash_sessions for insert to authenticated
with check (
  opened_by = (select auth.uid())
  and (select app_private.has_tenant_permission(tenant_id, 'finance.manage'))
);
create policy "Finance users can close cash sessions"
on public.cash_sessions for update to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'finance.manage')))
with check (
  (select app_private.has_tenant_permission(tenant_id, 'finance.manage'))
  and (closed_at is null or closed_by = (select auth.uid()))
);

create policy "Finance users can read financial transactions"
on public.financial_transactions for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'finance.read')));
create policy "Finance users can create financial transactions"
on public.financial_transactions for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select app_private.has_tenant_permission(tenant_id, 'finance.manage'))
);
create policy "Finance users can update financial transactions"
on public.financial_transactions for update to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'finance.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'finance.manage')));

create policy "Authorized users can read commissions"
on public.commissions for select to authenticated
using (
  (select app_private.has_tenant_permission(tenant_id, 'commissions.read'))
  or (
    (select app_private.has_tenant_permission(tenant_id, 'commissions.read_own'))
    and (select app_private.is_assigned_professional(tenant_id, professional_id))
  )
);
create policy "Finance users can read commission payments"
on public.commission_payments for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'commissions.read')));
create policy "Finance users can record commission payments"
on public.commission_payments for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select app_private.has_tenant_permission(tenant_id, 'commissions.manage'))
);

create policy "Members can read product categories"
on public.product_categories for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'inventory.read')));
create policy "Managers can manage product categories"
on public.product_categories for all to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'inventory.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'inventory.manage')));

create policy "Members can read products"
on public.products for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'inventory.read')));
create policy "Managers can create products"
on public.products for insert to authenticated
with check ((select app_private.has_tenant_permission(tenant_id, 'inventory.manage')));
create policy "Managers can update products"
on public.products for update to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'inventory.manage')))
with check ((select app_private.has_tenant_permission(tenant_id, 'inventory.manage')));
create policy "Managers can delete products"
on public.products for delete to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'inventory.manage')));

create policy "Members can read inventory movements"
on public.inventory_movements for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'inventory.read')));
create policy "Managers can create inventory movements"
on public.inventory_movements for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select app_private.has_tenant_permission(tenant_id, 'inventory.manage'))
);

create policy "Authorized users can read audit logs"
on public.audit_logs for select to authenticated
using ((select app_private.has_tenant_permission(tenant_id, 'audit.read')));

grant select on public.permissions, public.role_permissions to authenticated;
revoke update on public.clients from authenticated;
grant update (name, phone, email, birth_date, notes)
  on public.clients to authenticated;
grant select, insert, update, delete on public.tenant_units to authenticated;
grant select, insert, update on public.tenant_settings to authenticated;
grant select, insert, update, delete on public.unit_business_hours to authenticated;
grant select, insert, update, delete on public.service_categories to authenticated;
grant select, insert, update, delete on public.professionals to authenticated;
grant select, insert, update, delete on public.services to authenticated;
grant select, insert, update, delete on public.professional_services to authenticated;
grant select, insert, update, delete on public.professional_working_hours to authenticated;
grant select, insert, update, delete on public.professional_time_off to authenticated;
grant select, insert, update, delete on public.appointments to authenticated;
grant select, insert on public.appointment_items to authenticated;
grant select on public.appointment_status_history to authenticated;
grant select, insert on public.cash_sessions to authenticated;
grant update (closed_at, closed_by, closing_amount, notes)
  on public.cash_sessions to authenticated;
grant select, insert on public.financial_transactions to authenticated;
grant update (status, paid_at, payment_method)
  on public.financial_transactions to authenticated;
grant select on public.commissions to authenticated;
grant select, insert on public.commission_payments to authenticated;
grant select, insert, update, delete on public.product_categories to authenticated;
grant select, delete on public.products to authenticated;
grant insert (
  tenant_id, category_id, sku, name, description, unit_of_measure,
  cost_price, sale_price, minimum_stock, is_active
) on public.products to authenticated;
grant update (category_id, sku, name, description, unit_of_measure, cost_price, sale_price, minimum_stock, is_active)
  on public.products to authenticated;
grant select, insert on public.inventory_movements to authenticated;
grant select on public.audit_logs to authenticated;

grant usage on type public.appointment_status to authenticated;
grant usage on type public.financial_direction to authenticated;
grant usage on type public.financial_status to authenticated;
grant usage on type public.payment_method to authenticated;
grant usage on type public.commission_status to authenticated;
grant usage on type public.inventory_movement_type to authenticated;
