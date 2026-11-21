begin;

select plan(30);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '20000000-0000-4000-8000-000000000001', 'authenticated',
    'authenticated', 'owner-a@example.test', '', now(), '{}'::jsonb,
    '{"full_name":"Owner A"}'::jsonb, now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000002', 'authenticated',
    'authenticated', 'manager-a@example.test', '', now(), '{}'::jsonb,
    '{"full_name":"Manager A"}'::jsonb, now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000003', 'authenticated',
    'authenticated', 'reception-a@example.test', '', now(), '{}'::jsonb,
    '{"full_name":"Reception A"}'::jsonb, now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000004', 'authenticated',
    'authenticated', 'professional-a@example.test', '', now(), '{}'::jsonb,
    '{"full_name":"Professional A"}'::jsonb, now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000005', 'authenticated',
    'authenticated', 'finance-a@example.test', '', now(), '{}'::jsonb,
    '{"full_name":"Finance A"}'::jsonb, now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000006', 'authenticated',
    'authenticated', 'owner-b@example.test', '', now(), '{}'::jsonb,
    '{"full_name":"Owner B"}'::jsonb, now(), now()
  );

insert into public.tenants (id, name, slug)
values
  ('21000000-0000-4000-8000-000000000001', 'Salão A', 'operational-salao-a'),
  ('21000000-0000-4000-8000-000000000002', 'Salão B', 'operational-salao-b');

insert into public.memberships (tenant_id, user_id, role)
values
  (
    '21000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'owner'
  ),
  (
    '21000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000002', 'manager'
  ),
  (
    '21000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000003', 'receptionist'
  ),
  (
    '21000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000004', 'professional'
  ),
  (
    '21000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000005', 'finance'
  ),
  (
    '21000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000006', 'owner'
  );

insert into public.tenant_units (id, tenant_id, name, slug, is_primary)
values
  (
    '22000000-0000-4000-8000-000000000001',
    '21000000-0000-4000-8000-000000000001',
    'Unidade A', 'unidade-a', true
  ),
  (
    '22000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000002',
    'Unidade B', 'unidade-b', true
  );

insert into public.unit_business_hours (
  tenant_id, unit_id, weekday, opens_at, closes_at
)
values
  (
    '21000000-0000-4000-8000-000000000001',
    '22000000-0000-4000-8000-000000000001', 0, '08:00', '18:00'
  );

insert into public.clients (id, tenant_id, name, created_by)
values
  (
    '23000000-0000-4000-8000-000000000001',
    '21000000-0000-4000-8000-000000000001',
    'Cliente A', '20000000-0000-4000-8000-000000000001'
  ),
  (
    '23000000-0000-4000-8000-000000000002',
    '21000000-0000-4000-8000-000000000002',
    'Cliente B', '20000000-0000-4000-8000-000000000006'
  );

insert into public.professionals (
  id, tenant_id, user_id, name, commission_type, commission_value
)
values (
  '24000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000004',
  'Profissional A', 'percentage', 50
);

insert into public.professional_working_hours (
  tenant_id, unit_id, professional_id, weekday, starts_at, ends_at,
  break_starts_at, break_ends_at
)
values (
  '21000000-0000-4000-8000-000000000001',
  '22000000-0000-4000-8000-000000000001',
  '24000000-0000-4000-8000-000000000001',
  0, '08:00', '18:00', '13:00', '14:00'
);

insert into public.service_categories (id, tenant_id, name)
values (
  '25000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  'Cabelo'
);

insert into public.services (
  id, tenant_id, category_id, name, price, duration_minutes
)
values (
  '26000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  '25000000-0000-4000-8000-000000000001',
  'Corte', 100, 45
);

insert into public.professional_services (tenant_id, professional_id, service_id)
values (
  '21000000-0000-4000-8000-000000000001',
  '24000000-0000-4000-8000-000000000001',
  '26000000-0000-4000-8000-000000000001'
);

insert into public.product_categories (id, tenant_id, name)
values (
  '27000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  'Cuidados'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000003',
  true
);

select is(
  (select count(*)::integer from public.clients),
  1,
  'receptionists can read clients only in their tenant'
);
select is(
  (select count(*)::integer from public.clients where id = '23000000-0000-4000-8000-000000000002'),
  0,
  'a receptionist cannot read another tenant client'
);
select ok(
  app_private.has_tenant_permission(
    '21000000-0000-4000-8000-000000000001', 'clients.manage'
  ),
  'receptionists can manage clients'
);
select ok(
  not app_private.has_tenant_permission(
    '21000000-0000-4000-8000-000000000001', 'finance.read'
  ),
  'receptionists cannot read financial data'
);

insert into public.clients (tenant_id, name, created_by)
values (
  '21000000-0000-4000-8000-000000000001',
  'Cliente cadastrado', '20000000-0000-4000-8000-000000000003'
);

select throws_ok(
  $$update public.clients
    set created_by = '20000000-0000-4000-8000-000000000001'
    where id = '23000000-0000-4000-8000-000000000001'$$,
  '42501',
  'client creators cannot be reassigned'
);
select throws_ok(
  $$update public.clients
    set tenant_id = '21000000-0000-4000-8000-000000000002'
    where id = '23000000-0000-4000-8000-000000000001'$$,
  '42501',
  'clients cannot be moved between tenants'
);

select throws_ok(
  $$insert into public.clients (tenant_id, name, created_by)
    values (
      '21000000-0000-4000-8000-000000000002',
      'Cliente cross tenant',
      '20000000-0000-4000-8000-000000000003'
    )$$,
  '42501',
  'a receptionist cannot create a client in another tenant'
);
select is(
  (select count(*)::integer from public.financial_transactions),
  0,
  'receptionists cannot read financial transactions'
);

insert into public.appointments (
  id, tenant_id, unit_id, client_id, professional_id,
  starts_at, ends_at, created_by
)
values (
  '28000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  '22000000-0000-4000-8000-000000000001',
  '23000000-0000-4000-8000-000000000001',
  '24000000-0000-4000-8000-000000000001',
  '2026-11-02 10:00:00-03',
  '2026-11-02 10:45:00-03',
  '20000000-0000-4000-8000-000000000003'
);

select throws_ok(
  $$insert into public.appointments (
      tenant_id, unit_id, client_id, professional_id,
      starts_at, ends_at, created_by
    ) values (
      '21000000-0000-4000-8000-000000000001',
      '22000000-0000-4000-8000-000000000001',
      '23000000-0000-4000-8000-000000000001',
      '24000000-0000-4000-8000-000000000001',
      '2026-11-02 10:30:00-03',
      '2026-11-02 11:15:00-03',
      '20000000-0000-4000-8000-000000000003'
    )$$,
  '23P01',
  'overlapping appointments for one professional are rejected'
);

select throws_ok(
  $$insert into public.appointments (
      tenant_id, unit_id, client_id, professional_id,
      starts_at, ends_at, created_by
    ) values (
      '21000000-0000-4000-8000-000000000001',
      '22000000-0000-4000-8000-000000000001',
      '23000000-0000-4000-8000-000000000001',
      '24000000-0000-4000-8000-000000000001',
      '2026-11-02 13:15:00-03',
      '2026-11-02 14:00:00-03',
      '20000000-0000-4000-8000-000000000003'
    )$$,
  '23514',
  'appointments during a professional break are rejected'
);

insert into public.appointment_items (
  tenant_id, appointment_id, service_id, unit_price,
  duration_minutes, service_name
)
values (
  '21000000-0000-4000-8000-000000000001',
  '28000000-0000-4000-8000-000000000001',
  '26000000-0000-4000-8000-000000000001',
  100, 45, 'Corte'
);

update public.appointments
set status = 'confirmed'
where tenant_id = '21000000-0000-4000-8000-000000000001'
  and id = '28000000-0000-4000-8000-000000000001';

update public.appointments
set status = 'completed'
where tenant_id = '21000000-0000-4000-8000-000000000001'
  and id = '28000000-0000-4000-8000-000000000001';

reset role;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000005',
  true
);
set local role authenticated;

select ok(
  app_private.has_tenant_permission(
    '21000000-0000-4000-8000-000000000001', 'finance.manage'
  ),
  'finance users can manage finance'
);
select is(
  (select count(*)::integer from public.clients),
  0,
  'finance users cannot read client personal data by default'
);

insert into public.financial_transactions (
  tenant_id, unit_id, direction, status, category, description, amount,
  created_by
)
values (
  '21000000-0000-4000-8000-000000000001',
  '22000000-0000-4000-8000-000000000001',
  'income', 'pending', 'service', 'Recebimento pendente', 100,
  '20000000-0000-4000-8000-000000000005'
);

select is(
  (select count(*)::integer from public.financial_transactions),
  1,
  'finance users can create and read tenant financial transactions'
);

select throws_ok(
  $$update public.financial_transactions set amount = 1$$,
  '42501',
  'financial transaction amounts cannot be edited after creation'
);

select throws_ok(
  $$select public.set_tenant_member_role(
      '21000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000003',
      'manager'
    )$$,
  '42501',
  'finance users cannot change tenant member roles'
);

select is(
  (select amount from public.commissions
   where tenant_id = '21000000-0000-4000-8000-000000000001'
     and appointment_item_id = (
       select id from public.appointment_items
       where appointment_id = '28000000-0000-4000-8000-000000000001'
     )),
  50::numeric,
  'completed service accrues the configured professional commission'
);

insert into public.commission_payments (
  tenant_id, commission_id, amount, payment_method, created_by
)
select
  tenant_id, id, 20, 'pix', '20000000-0000-4000-8000-000000000005'
from public.commissions
where tenant_id = '21000000-0000-4000-8000-000000000001';

select is(
  (select status from public.commissions
   where tenant_id = '21000000-0000-4000-8000-000000000001'),
  'partial'::public.commission_status,
  'commission payments update the balance to partial'
);

insert into public.commission_payments (
  tenant_id, commission_id, amount, payment_method, created_by
)
select
  tenant_id, id, 30, 'pix', '20000000-0000-4000-8000-000000000005'
from public.commissions
where tenant_id = '21000000-0000-4000-8000-000000000001';

select is(
  (select status from public.commissions
   where tenant_id = '21000000-0000-4000-8000-000000000001'),
  'paid'::public.commission_status,
  'fully paid commissions are marked paid'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);
set local role authenticated;

select ok(
  not app_private.has_tenant_permission(
    '21000000-0000-4000-8000-000000000001', 'tenant.manage'
  ),
  'managers cannot alter tenant ownership or settings outside their role'
);
select ok(
  app_private.has_tenant_permission(
    '21000000-0000-4000-8000-000000000001', 'inventory.manage'
  ),
  'managers can manage inventory'
);

insert into public.products (
  tenant_id, category_id, name, cost_price, sale_price, minimum_stock
)
values (
  '21000000-0000-4000-8000-000000000001',
  '27000000-0000-4000-8000-000000000001',
  'Shampoo', 10, 20, 2
);

insert into public.inventory_movements (
  tenant_id, unit_id, product_id, movement_type, quantity, created_by
)
values (
  '21000000-0000-4000-8000-000000000001',
  '22000000-0000-4000-8000-000000000001',
  (select id from public.products
   where tenant_id = '21000000-0000-4000-8000-000000000001'
     and name = 'Shampoo'),
  'purchase', 10, '20000000-0000-4000-8000-000000000002'
);

select is(
  (select stock_quantity from public.products
   where tenant_id = '21000000-0000-4000-8000-000000000001'
     and name = 'Shampoo'),
  10::numeric,
  'inventory movements update the stock ledger'
);

select throws_ok(
  $$insert into public.inventory_movements (
      tenant_id, unit_id, product_id, movement_type, quantity, created_by
    ) values (
      '21000000-0000-4000-8000-000000000001',
      '22000000-0000-4000-8000-000000000001',
      (select id from public.products
       where tenant_id = '21000000-0000-4000-8000-000000000001'
         and name = 'Shampoo'),
      'consumption', 11, '20000000-0000-4000-8000-000000000002'
    )$$,
  '23514',
  'inventory cannot be reduced below zero'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000004',
  true
);
set local role authenticated;

select is(
  (select count(*)::integer from public.clients),
  1,
  'professionals can read clients they served while they remain members'
);
select is(
  (select count(*)::integer from public.appointments),
  1,
  'a professional can read their own appointment'
);
select is(
  (select count(*)::integer from public.audit_logs),
  0,
  'professionals cannot read administrative audit logs'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.set_tenant_member_role(
      '21000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000003',
      'receptionist'
    )$$,
  'owners can manage member roles'
);
select throws_ok(
  $$select public.set_tenant_member_role(
      '21000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001',
      'manager'
    )$$,
  '23514',
  'the last tenant owner cannot be demoted'
);
select is(
  (select count(*)::integer from public.memberships
   where tenant_id = '21000000-0000-4000-8000-000000000001'
     and role = 'owner'),
  1,
  'owner role protection preserves the last owner'
);

select lives_ok(
  $$select public.remove_tenant_member(
      '21000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000004'
    )$$,
  'owners can revoke a professional membership'
);
reset role;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000004',
  true
);
set local role authenticated;
select is(
  (select count(*)::integer from public.clients),
  0,
  'a removed professional cannot retain access to former clients'
);

select * from finish();
rollback;
