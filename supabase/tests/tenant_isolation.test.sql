begin;

select plan(4);

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'owner-a@example.test',
    '',
    now(),
    '{}'::jsonb,
    '{"full_name":"Owner A"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'owner-b@example.test',
    '',
    now(),
    '{}'::jsonb,
    '{"full_name":"Owner B"}'::jsonb,
    now(),
    now()
  );

insert into public.tenants (id, name, slug)
values
  ('10000000-0000-4000-8000-000000000001', 'Salão A', 'salao-a'),
  ('10000000-0000-4000-8000-000000000002', 'Salão B', 'salao-b');

insert into public.memberships (tenant_id, user_id, role)
values
  (
    '10000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000001',
    'owner'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000002',
    'owner'
  );

insert into public.clients (tenant_id, name, created_by)
values
  (
    '10000000-0000-4000-8000-000000000001',
    'Cliente A',
    '00000000-0000-4000-8000-000000000001'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    'Cliente B',
    '00000000-0000-4000-8000-000000000002'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000001',
  true
);

select is(
  (select count(*)::integer from public.tenants),
  1,
  'a user only sees their own tenant'
);

select is(
  (select count(*)::integer from public.memberships),
  1,
  'a user only sees memberships from their tenant'
);

select is(
  (select count(*)::integer from public.clients),
  1,
  'a user only sees clients from their tenant'
);

select throws_ok(
  $$insert into public.clients (tenant_id, name, created_by)
    values (
      '10000000-0000-4000-8000-000000000002',
      'Cross-tenant write',
      '00000000-0000-4000-8000-000000000001'
    )$$,
  '42501',
  'users cannot create clients in another tenant'
);

select * from finish();
rollback;
