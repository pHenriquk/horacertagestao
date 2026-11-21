import Link from "next/link";
import { LoginForm } from "@/app/login/login-form";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; notice?: string }>;
}) {
  const params = await searchParams;

  return (
    <main className="auth-page">
      <Link className="auth-brand" href="/">
        <span className="brand-mark">H</span> horacerta
      </Link>
      <section className="auth-card">
        <p className="eyebrow">BEM-VINDA DE VOLTA</p>
        <h1>Acesse seu espaço.</h1>
        <p className="auth-description">
          Entre com o e-mail e a senha da sua conta HoraCerta.
        </p>
        {params.notice === "confirm-email" && (
          <p className="auth-notice" role="status">
            Enviamos um link de confirmação para seu e-mail. Abra-o para
            concluir o cadastro.
          </p>
        )}
        {params.error && (
          <p className="auth-message" role="alert">
            {params.error === "callback"
              ? "Não foi possível confirmar o e-mail. Solicite um novo link ou tente novamente."
              : "Não foi possível concluir o acesso. Verifique a configuração do Supabase e tente novamente."}
          </p>
        )}
        <LoginForm />
        <p className="auth-footnote">
          Ainda não tem conta? <Link href="/signup">Criar meu acesso</Link>
        </p>
      </section>
    </main>
  );
}
