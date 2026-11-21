import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HoraCerta | Gestão para salões",
  description:
    "Plataforma de gestão de agenda, clientes e operação para salões, barbearias e estúdios de beleza.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
