"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";

export function LoginForm() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    setPending(true);

    const formData = new FormData(event.currentTarget);
    const email = String(formData.get("email") ?? "").trim();
    const password = String(formData.get("password") ?? "");

    try {
      const supabase = createSupabaseBrowserClient();
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        setMessage("E-mail ou senha inválidos. Confira seus dados e tente novamente.");
        return;
      }

      router.replace("/dashboard");
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
          autoComplete="current-password"
          name="password"
          placeholder="Sua senha"
          required
          type="password"
        />
      </label>
      {message && (
        <p aria-live="polite" className="auth-message" role="alert">
          {message}
        </p>
      )}
      <button className="button auth-submit" disabled={pending} type="submit">
        {pending ? "Entrando..." : "Entrar"}
      </button>
    </form>
  );
}
