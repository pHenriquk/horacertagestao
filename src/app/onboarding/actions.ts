"use server";

import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function slugify(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60)
    .replace(/-+$/g, "");
}

export async function createFirstTenant(formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/login");
  }

  const tenantName = String(formData.get("tenant_name") ?? "").trim();
  const tenantSlug = slugify(String(formData.get("tenant_slug") ?? tenantName));

  if (tenantName.length < 2 || tenantName.length > 120 || tenantSlug.length < 3) {
    redirect("/onboarding?error=invalid");
  }

  const { error } = await supabase.rpc("create_tenant", {
    _name: tenantName,
    _slug: tenantSlug,
  });

  if (error) {
    redirect(
      error.code === "23505"
        ? "/onboarding?error=slug-taken"
        : "/onboarding?error=creation",
    );
  }

  redirect("/dashboard");
}
