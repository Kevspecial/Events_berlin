'use client';

import Link from 'next/link';

export default function HeroSection() {
  return (
    <section className="relative bg-gradient-to-r from-orange-500 to-red-500 text-white">
      <div className="absolute inset-0 bg-black bg-opacity-30"></div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 lg:py-32">
        <div className="text-center">
          <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold mb-6 leading-tight">
            Discover events that
            <span className="block text-orange-200">move you</span>
          </h1>

          <p className="text-xl md:text-2xl lg:text-3xl mb-8 text-orange-100 max-w-3xl mx-auto leading-relaxed">
            From concerts and festivals to workshops and networking events,
            find your next unforgettable experience in Berlin.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <Link
              href="/events"
              className="bg-white text-orange-600 hover:bg-gray-50 px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200 transform hover:scale-105 shadow-lg hover:shadow-xl"
            >
              Browse Events
            </Link>
            <Link
              href="/events/create"
              className="border-2 border-white text-white hover:bg-white hover:text-orange-600 px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200"
            >
              Create Your Event
            </Link>
          </div>

          <div className="mt-12 text-orange-200">
            <p className="text-lg">
              Join thousands of event-goers and organizers in Berlin
            </p>
          </div>
        </div>
      </div>

      {/* Decorative elements */}
      <div className="absolute bottom-0 left-0 right-0 h-16 bg-gradient-to-t from-white to-transparent"></div>
    </section>
  );
}