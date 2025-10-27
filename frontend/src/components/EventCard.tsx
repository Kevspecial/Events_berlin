import { Event } from '@/types';
import Link from 'next/link';
import { format } from 'date-fns';

interface EventCardProps {
  event: Event;
}

export default function EventCard({ event }: EventCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <h3 className="text-lg font-semibold text-gray-900 mb-2">
        <Link href={`/events/${event.id}`} className="hover:text-orange-600">
          {event.name}
        </Link>
      </h3>
      <p className="text-gray-600 text-sm mb-2">
        {format(new Date(event.date), 'PPP')}
      </p>
      <p className="text-gray-600 text-sm mb-4">{event.location}</p>
      <Link
        href={`/events/${event.id}`}
        className="bg-orange-600 hover:bg-orange-700 text-white px-4 py-2 rounded-md text-sm font-medium"
      >
        View Details
      </Link>
    </div>
  );
}
