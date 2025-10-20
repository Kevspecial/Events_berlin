'use client';

import Navbar from '@/components/Navbar';
import HeroSection from '@/components/HeroSection';

export default function Home() {
  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <HeroSection />

      {/* Featured Events Section */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              Featured Events
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Discover the most popular events happening in Berlin this week
            </p>
          </div>

          {/* Events will be loaded here via API */}
          <div className="text-center py-12">
            <div className="bg-orange-50 border border-orange-200 rounded-lg p-8 max-w-md mx-auto">
              <div className="text-4xl mb-4">🎪</div>
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                Events Loading...
              </h3>
              <p className="text-gray-600">
                Connecting to the Events Berlin API
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div className="col-span-1 md:col-span-2">
              <div className="text-2xl font-bold text-orange-500 mb-4">Evently</div>
              <p className="text-gray-300 mb-4">
                Discover amazing events in Berlin. From concerts and festivals to workshops and networking events.
              </p>
            </div>

            <div>
              <h3 className="text-lg font-semibold mb-4">Quick Links</h3>
              <ul className="space-y-2 text-gray-300">
                <li><a href="/events" className="hover:text-orange-400 transition-colors">Browse Events</a></li>
                <li><a href="/events/create" className="hover:text-orange-400 transition-colors">Create Event</a></li>
                <li><a href="/about" className="hover:text-orange-400 transition-colors">About Us</a></li>
                <li><a href="/contact" className="hover:text-orange-400 transition-colors">Contact</a></li>
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold mb-4">Support</h3>
              <ul className="space-y-2 text-gray-300">
                <li><a href="/help" className="hover:text-orange-400 transition-colors">Help Center</a></li>
                <li><a href="/terms" className="hover:text-orange-400 transition-colors">Terms of Service</a></li>
                <li><a href="/privacy" className="hover:text-orange-400 transition-colors">Privacy Policy</a></li>
              </ul>
            </div>
          </div>

          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
            <p>&copy; 2025 Evently. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}


