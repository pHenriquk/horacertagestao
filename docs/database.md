# Banco de dados do HoraCerta

## Estado e limites desta entrega

O banco está organizado em migrations PostgreSQL para Supabase. A migration
inicial cria autenticação de perfil, estabelecimentos, vínculos e clientes. A
migration operacional acrescenta agenda, equipe, serviços, caixa, financeiro,
comissões, estoque, permissões e auditoria.

As migrations deste repositório são propostas locais. Elas **não foram aplicadas**
ao projeto Supabase remoto nesta tarefa. A conexão da aplicação usa somente a
URL do projeto e a chave pública; nenhuma chave `service_role` é necessária no
frontend.

Ainda não existem telas CRUD para serviços, profissionais, agenda, financeiro
ou estoque. As tabelas e políticas do banco não devem ser interpretadas como
esses módulos já entregues na interface.

## Migrations

Aplicar em ordem:

1. `supabase/migrations/20261102230000_initial_multitenant_foundation.sql`
2. `supabase/migrations/20261103000000_operational_schema_and_rbac.sql`

A migration inicial é preservada. A segunda substitui as políticas de leitura e
escrita de `tenants`, `memberships` e `clients` para aplicar permissões por
papel. Não há `DROP TABLE`, `TRUNCATE` ou exclusão em massa.

## Modelo de dados

### Identidade e isolamento

- `profiles` contém o perfil associado a `auth.users`.
- `tenants` representa o salão/empresa.
- `memberships` liga usuários a empresas com um dos papéis `owner`, `manager`,
  `receptionist`, `professional` ou `finance`.
- `permissions` e `role_permissions` formam o catálogo global e imutável de
  permissões. Usuários autenticados podem consultá-lo, mas não alterá-lo.
- `tenant_units` e `tenant_settings` guardam unidades e preferências da empresa.
- `public.create_tenant(name, slug)` cria a empresa, associação de proprietário,
  unidade principal e configurações em uma transação.
- `set_tenant_member_role` e `remove_tenant_member` só aceitam chamadas de
  membros com `members.manage` e impedem rebaixar/remover o último proprietário.

Tabelas operacionais incluem `tenant_id`. Chaves estrangeiras compostas com
`tenant_id` impedem referências entre empresas. O trigger
`prevent_tenant_change` também impede mover uma linha entre tenants.

### Operação

- Clientes: `clients` (nome, telefone, e-mail, nascimento, observações) e
  relacionamentos com atendimentos. A API não permite alterar `tenant_id` nem
  `created_by` após o cadastro.
- Profissionais: `professionals`, `professional_services`,
  `professional_working_hours` e `professional_time_off`.
- Catálogo: `service_categories` e `services`, com preço, duração e comissão.
- Agenda: `unit_business_hours`, `appointments`, `appointment_items` e
  `appointment_status_history`.
- Financeiro: `financial_transactions` suporta receitas/despesas, situação,
  vencimento, pagamento e método; `cash_sessions` registra abertura/fechamento.
- Comissões: `commissions` e `commission_payments`; a conclusão de atendimento
  cria a comissão a partir dos serviços e regras vigentes.
- Estoque: `product_categories`, `products` e `inventory_movements`. O saldo só
  muda por movimento, o banco impede saldo negativo e o saldo não pode ser
  alterado diretamente pela API.
- Auditoria: `audit_logs` registra tabela, registro, operação, campos alterados,
  autor e horário. Não armazena cópias dos valores pessoais ou financeiros.

## Agendamento e regras transacionais

- Uma restrição de exclusão GiST baseada em `btree_gist` impede sobreposição de
  horários ativos para o mesmo profissional e para o mesmo cliente, inclusive
  em chamadas concorrentes.
- A validação consulta o fuso horário da unidade, o horário de funcionamento,
  o horário profissional, intervalos e afastamentos.
- Afastamentos não podem ser criados sobre agendamentos ativos já existentes.
- Serviços de um atendimento precisam estar habilitados para o profissional.
- Situações finais (`completed`, `cancelled`, `no_show`) não podem ser
  reabertas. Um atendimento só pode ser concluído se contiver pelo menos um
  serviço.
- Os dias da semana usam `0 = segunda-feira` até `6 = domingo`; sem horário de
  funcionamento configurado, não são aceitos agendamentos.
- O saldo de comissões é atualizado por pagamentos imutáveis e não permite
  pagamento acima do valor devido.

## RLS e papéis

RLS está habilitado em todas as tabelas operacionais e no catálogo de
permissões. As políticas usam funções `SECURITY DEFINER` internas, com
`search_path` vazio, para consultar memberships sem recursão de RLS.

Resumo do acesso:

| Papel | Acesso principal |
|---|---|
| Proprietário | Administração integral do próprio tenant |
| Gerente | Operação, equipe, serviços, agenda, financeiro, estoque e auditoria |
| Recepcionista | Clientes, profissionais/serviços de leitura e agenda |
| Profissional | Própria agenda, próprios clientes atendidos e comissões próprias |
| Financeiro | Financeiro, comissões, relatórios e dados operacionais de leitura |

O usuário profissional só pode consultar clientes com os quais tem atendimento
associado e só pode alterar situação/notas da própria agenda. Não há escrita
direta em `memberships`; use as funções autorizadas para atribuir/remover
papéis. Nunca substitua essas regras por filtros no frontend.

## Configuração da aplicação

Crie `.env.local` na raiz a partir de `.env.example`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<chave-publica-anon-ou-publishable>
```

Configure Authentication → URL Configuration:

- Site URL: `http://localhost:3000`
- Redirect URL: `http://localhost:3000/**`

Não use `service_role` em variáveis `NEXT_PUBLIC_*`, no navegador ou em commits.
O arquivo `.env.local` está coberto pelo `.gitignore`.

## Aplicar no Supabase

Esta execução não aplicou mudanças ao banco remoto. Antes de aplicar em um
ambiente real:

1. Faça e verifique um backup do projeto.
2. Confirme se a migration inicial já foi aplicada. Não execute uma migration
   novamente por SQL Editor se ela já estiver registrada no histórico.
3. Leia e aplique, em ordem, somente as migrations pendentes pelo SQL Editor ou
   pelo fluxo versionado da CLI. Evite misturar os dois fluxos sem reconciliar
   o histórico de migrations.
4. Verifique a tabela `supabase_migrations.schema_migrations` (quando gerenciada
   pela CLI), as tabelas no Table Editor e execute os testes em um ambiente de
   desenvolvimento antes de produção.

Para produção, use uma janela de mudança, backup confirmado e revisão das
políticas. Não rode `db push` contra produção sem autorização e revisão
explícitas.

## Testes

- `supabase/tests/tenant_isolation.test.sql`: conserva os testes básicos de
  separação entre empresas.
- `supabase/tests/operational_security.test.sql`: cobre leitura por papel,
  tentativas cross-tenant, conflitos e horários de agenda, comissão, financeiro
  e estoque.
- `npx supabase test db` executa os testes pgTAP no Supabase local; requer
  Docker Desktop e o Supabase local inicializado. Os testes usam uma transação
  e fazem rollback.

Os testes **não foram executados nesta entrega**, porque o motor Docker local
não está ativo. Typecheck/lint da aplicação não validam a sintaxe ou execução
do SQL.

## Backups

Use os backups automáticos e/ou Point-in-Time Recovery disponíveis no plano
Supabase do projeto e confira a retenção correspondente ao plano. Antes de uma
mudança de schema, gere um backup manual, confirme que ele pode ser restaurado
em um projeto de teste e guarde-o fora do repositório. Um dump lógico com a CLI
pode ser gerado a partir de um projeto vinculado com `npx supabase db dump`;
consulte `npx supabase db dump --help` para selecionar arquivo e escopo
apropriados sem incluir credenciais no histórico do shell.
