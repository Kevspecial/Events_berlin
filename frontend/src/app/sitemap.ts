import type { MetadataRoute } from 'next';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://events-berlin-frontend.fly.dev';
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000/api/v1';

  const staticRoutes: MetadataRoute.Sitemap = [
    { url: `${siteUrl}/`, changeFrequency: 'daily', priority: 1 },
    { url: `${siteUrl}/events`, changeFrequency: 'hourly', priority: 0.9 },
    { url: `${siteUrl}/about`, changeFrequency: 'monthly', priority: 0.3 },
  ];

  try {
    const response = await fetch(`${apiUrl}/events?limit=100`, {
      next: { revalidate: 3600 },
    });
    if (!response.ok) return staticRoutes;
    const data = await response.json();
    const events = data.events ?? [];
    const eventRoutes: MetadataRoute.Sitemap = events.map((e: { id: number; updated_at: string }) => ({
      url: `${siteUrl}/events/${e.id}`,
      lastModified: new Date(e.updated_at),
      changeFrequency: 'weekly' as const,
      priority: 0.7,
    }));
    return [...staticRoutes, ...eventRoutes];
  } catch {
    return staticRoutes;
  }
}
