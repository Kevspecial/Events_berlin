import type { Metadata } from 'next';
import EventDetailClient from './EventDetailClient';

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  try {
    const response = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}/events/${params.id}`,
      { next: { revalidate: 3600 } }
    );
    if (!response.ok) return { title: 'Event' };
    const data = await response.json();
    const event = data.event ?? data;
    return {
      title: event.name,
      description: event.description?.substring(0, 160),
      openGraph: {
        title: event.name,
        description: event.description?.substring(0, 160),
        images: event.image_url ? [{ url: event.image_url }] : [],
      },
    };
  } catch {
    return { title: 'Event' };
  }
}

export default function EventDetailPage() {
  return <EventDetailClient />;
}
