'use client';

import { Event } from '@/types';
import EventCard from './EventCard';
import { motion } from 'framer-motion';

interface EventListProps {
  events: Event[];
  loading?: boolean;
  error?: string;
}

export default function EventList({ events, loading, error }: EventListProps) {
  if (loading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
        {[...Array(8)].map((_, i) => (
          <div key={i} className="animate-pulse">
            <div className="aspect-[4/3] bg-black/5 mb-4" />
            <div className="h-5 bg-black/5 mb-2 w-3/4" />
            <div className="h-3 bg-black/5 w-1/2" />
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-20">
        <div className="border border-black/10 p-10 max-w-md mx-auto">
          <p className="text-3xl font-black mb-3">!</p>
          <h3 className="text-lg font-black uppercase tracking-tight mb-2">
            Error Loading Events
          </h3>
          <p className="text-sm text-black/50 mb-6">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="bg-black text-white px-6 py-2.5 text-sm font-bold uppercase tracking-wide hover:bg-black/80 transition-colors"
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  if (!events || events.length === 0) {
    return (
      <div className="text-center py-20">
        <div className="border border-black/10 p-10 max-w-md mx-auto">
          <p className="text-4xl mb-4">&#8709;</p>
          <h3 className="text-lg font-black uppercase tracking-tight mb-2">
            No Events Found
          </h3>
          <p className="text-sm text-black/50">
            Try adjusting your search criteria or check back later for new events.
          </p>
        </div>
      </div>
    );
  }

  return (
    <motion.div
      className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8"
      initial="hidden"
      animate="visible"
      variants={{
        hidden: {},
        visible: { transition: { staggerChildren: 0.06 } },
      }}
    >
      {events.map((event) => (
        <motion.div
          key={event.id}
          variants={{
            hidden: { opacity: 0, y: 20 },
            visible: { opacity: 1, y: 0 },
          }}
          transition={{ duration: 0.4 }}
        >
          <EventCard event={event} />
        </motion.div>
      ))}
    </motion.div>
  );
}