import { NextResponse, type NextRequest } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");

  if (!code) {
    return NextResponse.redirect(new URL("/login?error=callback", request.url));
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(
      new URL("/login?error=callback", request.url),
    );
  }

  const onboardingUrl = new URL("/onboarding", request.url);
  const tenantName = requestUrl.searchParams.get("tenant_name");
  const tenantSlug = requestUrl.searchParams.get("tenant_slug");

  if (tenantName) onboardingUrl.searchParams.set("tenant_name", tenantName);
  if (tenantSlug) onboardingUrl.searchParams.set("tenant_slug", tenantSlug);

  return NextResponse.redirect(onboardingUrl);
}
