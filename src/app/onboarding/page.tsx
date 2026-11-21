import Link from "next/link";
import { redirect } from "next/navigation";
import { createFirstTenant } from "@/app/onboarding/actions";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const errorMessages: Record<string, string> = {
  invalid: "Confira o nome do estabelecimento e tente novamente.",
  "slug-taken": "Esse endereço já está sendo usado. Experimente outro nome.",
  creation: "Não foi possível criar o estabelecimento. Tente novamente.",
};

export const dynamic = "force-dynamic";

export default async function OnboardingPage({
  searchParams,
}: {
  searchParams: Promise<{
    error?: string;
    tenant_name?: string;
    tenant_slug?: string;
  }>;
}) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) redirect("/login");

  const initialName = params.tenant_name ?? "";
  const initialSlug = params.tenant_slug ?? "";

  return (
    <main className="auth-page">
      <Link className="auth-brand" href="/dashboard">
        <span className="brand-mark">H</span> horacerta
      </Link>
      <section className="auth-card">
        <p className="eyebrow">SEU ESPAÇO ESTÁ QUASE PRONTO</p>
        <h1>Vamos preparar seu estabelecimento.</h1>
        <p className="auth-description">
          Esse é o primeiro passo. Depois você poderá adicionar unidade,
          endereço, equipe, serviços e horários.
        </p>
        {params.error && (
          <p className="auth-message" role="alert">
            {errorMessages[params.error] ?? errorMessages.creation}
          </p>
        )}
        <form action={createFirstTenant} className="auth-form">
          <label>
            Nome do estabelecimento
            <input
              defaultValue={initialName}
              maxLength={120}
              name="tenant_name"
              placeholder="Ex.: Studio Flor de Lis"
              required
            />
          </label>
          <label>
            Endereço público
            <input
              defaultValue={initialSlug}
              maxLength={60}
              name="tenant_slug"
              placeholder="studio-flor-de-lis"
              required
            />
            <span className="input-hint">
              Esse identificador será usado no endereço público do salão.
            </span>
          </label>
          <button className="button auth-submit" type="submit">
            Criar estabelecimento
          </button>
        </form>
      </section>
    </main>
  );
}
