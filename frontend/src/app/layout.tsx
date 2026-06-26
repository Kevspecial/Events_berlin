import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import QueryProvider from "@/providers/QueryProvider";
import { AuthProvider } from "@/providers/AuthProvider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: {
    default: 'Events Berlin — Discover Local Events',
    template: '%s | Events Berlin',
  },
  description: 'Discover and book the best events in Berlin — cultural, professional, and community events all in one place.',
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://events-berlin-frontend.fly.dev'),
  openGraph: {
    type: 'website',
    locale: 'en_DE',
    siteName: 'Events Berlin',
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} font-sans antialiased`} suppressHydrationWarning>
        <AuthProvider>
          <QueryProvider>
            {children}
          </QueryProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
