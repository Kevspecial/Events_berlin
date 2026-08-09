export async function GET() {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://events-berlin-frontend.fly.dev';
  const body = `User-agent: *\nAllow: /\nDisallow: /profile\nDisallow: /profile/bookings\n\nSitemap: ${siteUrl}/sitemap.xml`;
  return new Response(body, {
    headers: { 'Content-Type': 'text/plain' },
  });
}
