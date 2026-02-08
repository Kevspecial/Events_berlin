'use client';

import { useState } from 'react';
import { useEvents } from '@/hooks/useEvents';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import EventCard from '@/components/EventCard';
import { motion } from 'framer-motion';
import { Search, SlidersHorizontal, X, ChevronLeft, ChevronRight } from 'lucide-react';

export default function EventsPage() {
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('');
  const [page, setPage] = useState(1);

  const { data: eventsData, isLoading, error } = useEvents({
    page,
    per_page: 12,
    search: search || undefined,
    category: category || undefined,
  });

  const clearFilters = () => {
    setSearch('');
    setCategory('');
    setPage(1);
  };

  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        {/* Header */}
        <motion.div
          className="mb-12"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h1 className="heading-display text-[clamp(2.5rem,6vw,4.5rem)] mb-3">
            All Events
          </h1>
          <p className="text-sm font-bold uppercase tracking-wide text-black/50">
            Discover amazing events happening in Berlin
          </p>
        </motion.div>

        {/* Filters */}
        <motion.div
          className="mb-10 border border-black/10 p-5"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.15 }}
        >
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Search */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-black/30" />
              <input
                type="text"
                placeholder="Search events..."
                value={search}
                onChange={(e) => { setSearch(e.target.value); setPage(1); }}
                className="w-full pl-10 pr-4 py-3 border border-black/10 text-sm font-medium placeholder:text-black/30 focus:outline-none focus:border-black transition-colors bg-transparent"
              />
            </div>

            {/* Category Filter */}
            <div className="relative">
              <SlidersHorizontal className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-black/30" />
              <select
                value={category}
                onChange={(e) => { setCategory(e.target.value); setPage(1); }}
                className="w-full pl-10 pr-4 py-3 border border-black/10 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent appearance-none cursor-pointer"
              >
                <option value="">All Categories</option>
                <option value="technology">Technology</option>
                <option value="music">Music</option>
                <option value="art">Art &amp; Culture</option>
                <option value="sports">Sports</option>
                <option value="food">Food &amp; Drink</option>
                <option value="business">Business</option>
              </select>
            </div>

            {/* Clear Filters */}
            <button
              onClick={clearFilters}
              className="flex items-center justify-center gap-2 py-3 border border-black/10 text-sm font-bold uppercase tracking-wide hover:bg-black hover:text-white transition-colors"
            >
              <X className="w-4 h-4" />
              Clear Filters
            </button>
          </div>
        </motion.div>

        {/* Results count */}
        {eventsData && eventsData.meta && (
          <div className="flex items-center justify-between mb-8 text-xs font-bold uppercase tracking-wider text-black/40">
            <p>
              Showing {eventsData.data.length} of {eventsData.meta.total_count} events
            </p>
            <p>
              Page {eventsData.meta.current_page} of {eventsData.meta.total_pages}
            </p>
          </div>
        )}

        {/* Events Grid */}
        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="animate-pulse">
                <div className="aspect-[4/3] bg-black/5 mb-4" />
                <div className="h-5 bg-black/5 mb-2 w-3/4" />
                <div className="h-3 bg-black/5 w-1/2" />
              </div>
            ))}
          </div>
        ) : error ? (
          <div className="text-center py-20">
            <div className="border border-black/10 p-10 max-w-md mx-auto">
              <p className="text-3xl font-black mb-3">!</p>
              <h3 className="text-base font-black uppercase tracking-tight mb-2">
                Error Loading Events
              </h3>
              <p className="text-sm text-black/50">
                {error.message || 'Something went wrong. Please try again.'}
              </p>
            </div>
          </div>
        ) : eventsData && eventsData.data && eventsData.data.length > 0 ? (
          <motion.div
            className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8"
            initial="hidden"
            animate="visible"
            variants={{
              hidden: {},
              visible: { transition: { staggerChildren: 0.06 } },
            }}
          >
            {eventsData.data.map((event) => (
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
        ) : (
          <div className="text-center py-20">
            <div className="border border-black/10 p-10 max-w-md mx-auto">
              <p className="text-4xl mb-4">&#8709;</p>
              <h3 className="text-base font-black uppercase tracking-tight mb-2">
                No Events Found
              </h3>
              <p className="text-sm text-black/50">
                Try adjusting your search criteria or check back later.
              </p>
            </div>
          </div>
        )}

        {/* Pagination */}
        {eventsData && eventsData.meta && eventsData.meta.total_pages > 1 && (
          <div className="flex items-center justify-center gap-2 mt-16">
            <button
              onClick={() => setPage(page - 1)}
              disabled={page === 1}
              className="flex items-center gap-1 px-4 py-2.5 border border-black/10 text-sm font-bold uppercase tracking-wide hover:bg-black hover:text-white disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              Prev
            </button>

            <div className="flex gap-1">
              {Array.from({ length: Math.min(5, eventsData.meta.total_pages) }, (_, i) => {
                const pageNum = Math.max(1, page - 2) + i;
                if (pageNum > eventsData.meta.total_pages) return null;
                return (
                  <button
                    key={pageNum}
                    onClick={() => setPage(pageNum)}
                    className={`w-10 h-10 text-sm font-bold transition-colors ${
                      page === pageNum
                        ? 'bg-black text-white'
                        : 'border border-black/10 hover:bg-black hover:text-white'
                    }`}
                  >
                    {pageNum}
                  </button>
                );
              })}
            </div>

            <button
              onClick={() => setPage(page + 1)}
              disabled={page === eventsData.meta.total_pages}
              className="flex items-center gap-1 px-4 py-2.5 border border-black/10 text-sm font-bold uppercase tracking-wide hover:bg-black hover:text-white disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              Next
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>

      <Footer />
    </div>
  );
}