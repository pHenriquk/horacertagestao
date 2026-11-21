import Link from "next/link";
import { SignupForm } from "@/app/signup/signup-form";

export default function SignupPage() {
  return (
    <main className="auth-page">
      <Link className="auth-brand" href="/">
        <span className="brand-mark">H</span> horacerta
      </Link>
      <section className="auth-card">
        <p className="eyebrow">VAMOS COMEÇAR</p>
        <h1>Crie o acesso do seu salão.</h1>
        <p className="auth-description">
          Cadastre sua conta e o estabelecimento. Você poderá completar os
          detalhes do negócio depois.
        </p>
        <SignupForm />
        <p className="auth-footnote">
          Já tem uma conta? <Link href="/login">Entrar</Link>
        </p>
      </section>
      <p className="auth-legal">
        Ao continuar, você autoriza o uso dos dados para criar sua conta.
      </p>
    </main>
  );
}
