'use client';

import { Event } from '@/types';
import Link from 'next/link';
import { format } from 'date-fns';
import { motion } from 'framer-motion';
import { Calendar, MapPin } from 'lucide-react';

interface EventCardProps {
  event: Event;
}

export default function EventCard({ event }: EventCardProps) {
  return (
    <motion.div
      whileHover={{ y: -4 }}
      transition={{ duration: 0.2 }}
      className="group"
    >
      <Link href={`/events/${event.id}`} className="block">
        {/* Image */}
        <div className="relative overflow-hidden aspect-[4/3] bg-gray-100 mb-4">
          {event.image_url ? (
            <img
              src={event.image_url}
              alt={event.name}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
            />
          ) : (
            <div className="w-full h-full bg-black/5 flex items-center justify-center">
              <span className="text-4xl font-black text-black/10 uppercase">
                {event.name.charAt(0)}
              </span>
            </div>
          )}
          <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors duration-300" />

          {/* Category badge */}
          {event.category && (
            <div className="absolute top-3 left-3 bg-white px-3 py-1 text-xs font-bold uppercase tracking-wider">
              {event.category.name}
            </div>
          )}
        </div>

        {/* Content */}
        <div>
          <h3 className="text-xl font-black uppercase tracking-tight mb-2 group-hover:underline decoration-2 underline-offset-4">
            {event.name}
          </h3>

          <div className="flex items-center gap-4 text-sm text-black/50">
            <span className="flex items-center gap-1.5">
              <Calendar className="w-3.5 h-3.5" />
              {format(new Date(event.date), 'MMM d, yyyy')}
            </span>
            <span className="flex items-center gap-1.5">
              <MapPin className="w-3.5 h-3.5" />
              {event.location}
            </span>
          </div>

          {event.price !== undefined && event.price !== null && (
            <p className="mt-2 text-sm font-bold">
              {event.price === 0 ? 'FREE' : `€${event.price}`}
            </p>
          )}
        </div>
      </Link>
    </motion.div>
  );
}
