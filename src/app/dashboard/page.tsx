import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) redirect("/login");

  const { data: memberships, error: membershipsError } = await supabase
    .from("memberships")
    .select("tenant_id, role")
    .eq("user_id", user.id);

  if (membershipsError) {
    throw new Error(`Não foi possível carregar seus estabelecimentos: ${membershipsError.message}`);
  }

  const tenantIds = memberships.map((membership) => membership.tenant_id);
  const { data: tenants, error: tenantsError } = tenantIds.length
    ? await supabase
        .from("tenants")
        .select("id, name, slug")
        .in("id", tenantIds)
    : { data: [], error: null };

  if (tenantsError) {
    throw new Error(`Não foi possível carregar os dados da empresa: ${tenantsError.message}`);
  }

  const firstName =
    user.user_metadata.full_name?.trim().split(/\s+/)[0] ?? "bem-vinda";

  return (
    <main className="dashboard-page">
      <header className="dashboard-header">
        <Link className="auth-brand" href="/">
          <span className="brand-mark">H</span> horacerta
        </Link>
        <form
          action={async () => {
            "use server";
            const serverClient = await createSupabaseServerClient();
            const { error } = await serverClient.auth.signOut();
            if (error) throw new Error(`Não foi possível encerrar a sessão: ${error.message}`);
            redirect("/login");
          }}
        >
          <button className="button button-light" type="submit">
            Sair
          </button>
        </form>
      </header>
      <section className="dashboard-content">
        <p className="eyebrow">SEU ESPAÇO HORACERTA</p>
        <h1>Olá, {firstName}.</h1>
        <p className="dashboard-intro">
          Sua conta está conectada. Selecione um estabelecimento para continuar.
        </p>
        {tenants.length > 0 ? (
          <div className="tenant-grid">
            {tenants.map((tenant) => {
              const role = memberships.find(
                (membership) => membership.tenant_id === tenant.id,
              )?.role;

              return (
                <article className="tenant-card" key={tenant.id}>
                  <span className="tenant-symbol" aria-hidden="true">
                    {tenant.name.slice(0, 1).toUpperCase()}
                  </span>
                  <div>
                    <h2>{tenant.name}</h2>
                    <p>
                      {role === "owner" ? "Proprietário" : role} ·{" "}
                      <span className="tenant-slug">{tenant.slug}</span>
                    </p>
                  </div>
                  <span className="tenant-status">Conta criada</span>
                </article>
              );
            })}
          </div>
        ) : (
          <article className="empty-state">
            <span className="feature-icon" aria-hidden="true">✦</span>
            <h2>Cadastre seu estabelecimento</h2>
            <p>
              Sua conta está pronta. Crie o espaço do salão para iniciar a
              configuração.
            </p>
            <Link className="button" href="/onboarding">
              Continuar configuração
            </Link>
          </article>
        )}
        <p className="dashboard-next">
          Próximo: completar os dados do negócio e configurar serviços,
          profissionais e horários.
        </p>
      </section>
    </main>
  );
}
