"use client";

import Navbar from '@/components/Navbar';
import HeroSection from '@/components/HeroSection';
import EventCard from '@/components/EventCard';
import Footer from '@/components/Footer';
import TextBlock from '@/components/TextBlock';
import { useEvents } from '@/hooks/useEvents';
import { motion } from 'framer-motion';
import Link from 'next/link';

export default function Home() {
  const { data: eventsData, isLoading, error } = useEvents({ per_page: 8 });

  return (
    <div className="min-h-screen bg-white">
      <Navbar />
      <HeroSection />

      {/* Featured Events Section */}
      <section className="py-16 lg:py-24 px-6 lg:px-10">
        <div className="max-w-[1400px] mx-auto">
          {/* Section header */}
          <motion.div
            className="flex items-end justify-between mb-12"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            viewport={{ once: true }}
          >
            <div>
              <h2 className="heading-section">Featured Events</h2>
              <p className="mt-3 text-sm text-black/50 uppercase tracking-wide font-bold">
                The most popular events happening now
              </p>
            </div>
            <Link
              href="/events"
              className="hidden sm:block text-sm font-bold uppercase tracking-wide border-b-2 border-black pb-1 hover:opacity-50 transition-opacity"
            >
              View All
            </Link>
          </motion.div>

          {/* Events grid */}
          {isLoading ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="animate-pulse">
                  <div className="aspect-[4/3] bg-black/5 mb-4" />
                  <div className="h-5 bg-black/5 mb-2 w-3/4" />
                  <div className="h-3 bg-black/5 w-1/2" />
                </div>
              ))}
            </div>
          ) : error ? (
            <div className="text-center py-16">
              <div className="border border-black/10 p-10 max-w-md mx-auto">
                <p className="text-3xl font-black mb-3">!</p>
                <h3 className="text-base font-black uppercase tracking-tight mb-2">
                  Error Loading Events
                </h3>
                <p className="text-sm text-black/50">
                  {(error as Error).message || 'Please try again.'}
                </p>
              </div>
            </div>
          ) : eventsData && eventsData.data && eventsData.data.length > 0 ? (
            <motion.div
              className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8"
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true }}
              variants={{
                hidden: {},
                visible: { transition: { staggerChildren: 0.08 } },
              }}
            >
              {eventsData.data.slice(0, 8).map((event) => (
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
            <div className="text-center py-16">
              <div className="border border-black/10 p-10 max-w-md mx-auto">
                <p className="text-4xl mb-4">&#8709;</p>
                <h3 className="text-base font-black uppercase tracking-tight mb-2">
                  No Featured Events
                </h3>
                <p className="text-sm text-black/50">
                  Check back later or browse all events.
                </p>
              </div>
            </div>
          )}

          {/* Mobile "View All" link */}
          <div className="sm:hidden mt-10 text-center">
            <Link
              href="/events"
              className="text-sm font-bold uppercase tracking-wide border-b-2 border-black pb-1"
            >
              View All Events
            </Link>
          </div>
        </div>
      </section>

      {/* Mission Section */}
      <section className="py-16 lg:py-24 px-6 lg:px-10 border-t border-black/10">
        <div className="max-w-[1400px] mx-auto">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 lg:gap-20">
            {/* Left Column */}
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
            >
              <h2 className="text-rotated heading-section text-[clamp(2.5rem,5vw,4rem)] mb-8">
                Our Mission
              </h2>

              <TextBlock
                content="We create inspiring events combined with art and culture. An effective form of involving people in creative expression through modern digital experiences."
                isUppercase
                isTight
                className="text-black/70 mb-6"
              />

              <TextBlock
                content="Bringing together communities through curated cultural experiences, festivals, museum collections, and live performances since 2022."
                isUppercase
                isTight
                className="text-black/40"
              />
            </motion.div>

            {/* Right Column */}
            <motion.div
              className="flex flex-col gap-8"
              initial={{ opacity: 0, x: 20 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.6, delay: 0.15 }}
              viewport={{ once: true }}
            >
              {/* Stat cards */}
              <div className="grid grid-cols-2 gap-6">
                <div className="border border-black/10 p-6">
                  <p className="text-4xl font-black mb-1">500+</p>
                  <p className="text-xs font-bold uppercase tracking-wider text-black/50">
                    Events Hosted
                  </p>
                </div>
                <div className="border border-black/10 p-6">
                  <p className="text-4xl font-black mb-1">10K+</p>
                  <p className="text-xs font-bold uppercase tracking-wider text-black/50">
                    Attendees
                  </p>
                </div>
                <div className="border border-black/10 p-6">
                  <p className="text-4xl font-black mb-1">50+</p>
                  <p className="text-xs font-bold uppercase tracking-wider text-black/50">
                    Venues
                  </p>
                </div>
                <div className="border border-black/10 p-6">
                  <p className="text-4xl font-black mb-1">Berlin</p>
                  <p className="text-xs font-bold uppercase tracking-wider text-black/50">
                    Based In
                  </p>
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}


