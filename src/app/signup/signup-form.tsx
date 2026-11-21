"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";

function createSlug(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60)
    .replace(/-+$/g, "");
}

export function SignupForm() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");

    const formData = new FormData(event.currentTarget);
    const fullName = String(formData.get("fullName") ?? "").trim();
    const tenantName = String(formData.get("tenantName") ?? "").trim();
    const email = String(formData.get("email") ?? "").trim();
    const password = String(formData.get("password") ?? "");
    const tenantSlug = createSlug(tenantName);

    if (fullName.length < 2 || tenantName.length < 2) {
      setMessage("Informe seu nome e o nome do estabelecimento.");
      return;
    }

    if (tenantSlug.length < 3) {
      setMessage("O nome precisa ter pelo menos 3 letras ou números.");
      return;
    }

    if (password.length < 8) {
      setMessage("A senha precisa ter pelo menos 8 caracteres.");
      return;
    }

    setPending(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const callbackUrl = new URL("/auth/callback", window.location.origin);
      callbackUrl.searchParams.set("tenant_name", tenantName);
      callbackUrl.searchParams.set("tenant_slug", tenantSlug);

      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: { full_name: fullName },
          emailRedirectTo: callbackUrl.toString(),
        },
      });

      if (error) {
        setMessage(
          error.message.toLowerCase().includes("already registered")
            ? "Este e-mail já possui uma conta. Entre ou use outro e-mail."
            : "Não foi possível criar sua conta. Confira os dados e tente novamente.",
        );
        return;
      }

      if (!data.session) {
        setMessage(
          "Conta criada. Confirme o e-mail enviado para continuar com o cadastro do estabelecimento.",
        );
        return;
      }

      const onboardingUrl = new URL("/onboarding", window.location.origin);
      onboardingUrl.searchParams.set("tenant_name", tenantName);
      onboardingUrl.searchParams.set("tenant_slug", tenantSlug);
      router.push(onboardingUrl.pathname + onboardingUrl.search);
      router.refresh();
    } catch (error) {
      setMessage(
        error instanceof Error && error.message.includes("Supabase is not configured")
          ? "O Supabase ainda não foi configurado. Adicione a URL e a chave pública ao arquivo .env.local."
          : "Não foi possível conectar ao serviço de autenticação. Tente novamente.",
      );
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="auth-form" onSubmit={handleSubmit}>
      <label>
        Seu nome
        <input
          autoComplete="name"
          maxLength={120}
          name="fullName"
          placeholder="Como podemos chamar você?"
          required
        />
      </label>
      <label>
        Nome do estabelecimento
        <input
          autoComplete="organization"
          maxLength={120}
          name="tenantName"
          placeholder="Ex.: Studio Flor de Lis"
          required
        />
      </label>
      <label>
        E-mail
        <input
          autoComplete="email"
          name="email"
          placeholder="voce@exemplo.com"
          required
          type="email"
        />
      </label>
      <label>
        Senha
        <input
          autoComplete="new-password"
          minLength={8}
          name="password"
          placeholder="Pelo menos 8 caracteres"
          required
          type="password"
        />
      </label>
      {message && (
        <p aria-live="polite" className="auth-message" role="status">
          {message}
        </p>
      )}
      <button className="button auth-submit" disabled={pending} type="submit">
        {pending ? "Criando sua conta..." : "Criar conta e continuar"}
      </button>
    </form>
  );
}
