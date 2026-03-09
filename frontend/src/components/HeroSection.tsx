'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';

export default function HeroSection() {
  return (
    <section className="relative bg-white pt-28 pb-20 px-6 lg:px-10 overflow-hidden">
      <div className="max-w-[1400px] mx-auto">
        {/* Asymmetric grid layout */}
        <div className="grid grid-cols-12 gap-4 lg:gap-8 items-end">
          {/* Main heading */}
          <motion.div
            className="col-span-12 lg:col-span-8"
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          >
            <h1 className="heading-display text-[clamp(3.5rem,10vw,8rem)] leading-[0.85]">
              Discover
              <br />
              <span className="italic font-black">Events</span>
            </h1>
          </motion.div>

          {/* Rotated subheading */}
          <motion.div
            className="col-span-12 lg:col-span-4 lg:pb-4"
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          >
            <p className="text-editorial text-sm lg:text-base max-w-xs">
              We create the next level of cultural experiences. From art exhibitions to live performances.
            </p>
          </motion.div>
        </div>

        {/* CTA Row */}
        <motion.div
          className="mt-12 lg:mt-16 flex flex-col sm:flex-row gap-4 items-start"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.4 }}
        >
          <Link
            href="/events"
            className="bg-black text-white px-8 py-4 text-sm font-bold uppercase tracking-widest hover:bg-black/80 transition-colors"
          >
            Browse Events
          </Link>
          <Link
            href="/events/create"
            className="border-2 border-black text-black px-8 py-4 text-sm font-bold uppercase tracking-widest hover:bg-black hover:text-white transition-colors"
          >
            Create Event
          </Link>
        </motion.div>

        {/* Decorative line */}
        <motion.div
          className="mt-16 lg:mt-20 h-px bg-black/15 w-full"
          initial={{ scaleX: 0 }}
          animate={{ scaleX: 1 }}
          transition={{ duration: 1.2, delay: 0.6, ease: [0.16, 1, 0.3, 1] }}
          style={{ transformOrigin: 'left' }}
        />
      </div>
    </section>
  );
}