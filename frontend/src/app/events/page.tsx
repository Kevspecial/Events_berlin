'use client';

import { useState } from 'react';
import { useEvents } from '@/hooks/useEvents';
import Navbar from '@/components/Navbar';
import EventCard from '@/components/EventCard';
import { MagnifyingGlassIcon, FunnelIcon, ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/24/outline';

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

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">All Events</h1>
          <p className="text-xl text-gray-600">
            Discover amazing events happening in Berlin
          </p>
        </div>

        {/* Filters */}
        <div className="mb-8 bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Search */}
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" />
              </div>
              <input
                type="text"
                placeholder="Search events..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
              />
            </div>

            {/* Category Filter */}
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <FunnelIcon className="h-5 w-5 text-gray-400" />
              </div>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500 bg-white"
              >
                <option value="">All Categories</option>
                <option value="technology">Technology</option>
                <option value="music">Music</option>
                <option value="art">Art & Culture</option>
                <option value="sports">Sports</option>
                <option value="food">Food & Drink</option>
                <option value="business">Business</option>
              </select>
            </div>

            {/* Clear Filters */}
            <div className="flex items-center">
              <button
                onClick={() => {
                  setSearch('');
                  setCategory('');
                  setPage(1);
                }}
                className="w-full bg-orange-100 hover:bg-orange-200 text-orange-700 px-4 py-3 rounded-lg text-sm font-medium transition-colors duration-200"
              >
                Clear Filters
              </button>
            </div>
          </div>
        </div>

        {/* Results */}
        <div className="mb-8">
          {eventsData && eventsData.meta && (
            <div className="flex items-center justify-between mb-6">
              <p className="text-gray-600">
                Showing {eventsData.data.length} of {eventsData.meta.total_count} events
              </p>
              <p className="text-sm text-gray-500">
                Page {eventsData.meta.current_page} of {eventsData.meta.total_pages}
              </p>
            </div>
          )}

          {/* Events Grid */}
          {isLoading ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="bg-white rounded-xl shadow-sm overflow-hidden border border-gray-100 animate-pulse">
                  <div className="h-48 bg-gray-200"></div>
                  <div className="p-6">
                    <div className="h-4 bg-gray-200 rounded mb-2"></div>
                    <div className="h-3 bg-gray-200 rounded mb-4"></div>
                    <div className="h-3 bg-gray-200 rounded w-3/4"></div>
                  </div>
                </div>
              ))}
            </div>
          ) : error ? (
            <div className="text-center py-12">
              <div className="bg-red-50 border border-red-200 rounded-lg p-8 max-w-md mx-auto">
                <div className="text-red-400 text-4xl mb-4">⚠️</div>
                <h3 className="text-lg font-semibold text-red-900 mb-2">
                  Error Loading Events
                </h3>
                <p className="text-red-600">
                  {error.message || 'Something went wrong. Please try again.'}
                </p>
              </div>
            </div>
          ) : eventsData && eventsData.data && eventsData.data.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {eventsData.data.map((event) => (
                <EventCard key={event.id} event={event} />
              ))}
            </div>
          ) : (
            <div className="text-center py-12">
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 max-w-md mx-auto">
                <div className="text-gray-400 text-4xl mb-4">🔍</div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  No Events Found
                </h3>
                <p className="text-gray-600">
                  Try adjusting your search criteria or check back later for new events.
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Pagination */}
        {eventsData && eventsData.meta && eventsData.meta.total_pages > 1 && (
          <div className="flex items-center justify-center space-x-2">
            <button
              onClick={() => setPage(page - 1)}
              disabled={page === 1}
              className="flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeftIcon className="h-4 w-4 mr-1" />
              Previous
            </button>

            <div className="flex space-x-1">
              {Array.from({ length: Math.min(5, eventsData.meta.total_pages) }, (_, i) => {
                const pageNum = Math.max(1, page - 2) + i;
                if (pageNum > eventsData.meta.total_pages) return null;
                return (
                  <button
                    key={pageNum}
                    onClick={() => setPage(pageNum)}
                    className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
                      page === pageNum
                        ? 'bg-orange-600 text-white'
                        : 'text-gray-700 bg-white border border-gray-300 hover:bg-gray-50'
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
              className="flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Next
              <ChevronRightIcon className="h-4 w-4 ml-1" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}