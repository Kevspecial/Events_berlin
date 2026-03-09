'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';

const footerLinks = [
  { label: 'Homepage', href: '/' },
  { label: 'Events', href: '/events' },
  { label: 'About Us', href: '/about' },
  { label: 'Privacy Policy', href: '/privacy' },
  { label: 'Terms', href: '/terms' },
];

export default function Footer() {
  return (
    <footer className="bg-white border-t border-black/10">
      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 py-16 lg:py-24">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 lg:gap-20">
          {/* Left Side */}
          <div>
            <motion.h2
              className="text-[clamp(3rem,7vw,5rem)] font-black leading-[0.9] uppercase tracking-tight mb-10"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
            >
              Get Your
              <br />
              Ticket
            </motion.h2>

            <nav className="space-y-2 mb-10">
              {footerLinks.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="block text-base font-bold uppercase tracking-wide hover:underline decoration-2 underline-offset-4 transition-all py-1"
                >
                  {link.label}
                </Link>
              ))}
            </nav>

            <p className="text-editorial text-sm text-black/60 max-w-sm">
              Creating invitations to the event and providing a valuable source of
              knowledge and cultural experiences.
            </p>
          </div>

          {/* Right Side */}
          <div className="flex flex-col justify-between">
            <div>
              <Link
                href="/"
                className="text-3xl font-black uppercase tracking-tight"
              >
                Berlin_Events
              </Link>
              <p className="mt-4 text-sm text-black/50 max-w-xs leading-relaxed">
                Discover amazing events in Berlin. From concerts and festivals to
                workshops and networking events.
              </p>
            </div>

            <p className="text-xs font-bold uppercase tracking-wider text-black/40 mt-12">
              &copy; {new Date().getFullYear()} Berlin_Events Platform. All rights reserved.
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
