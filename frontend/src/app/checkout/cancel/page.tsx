"use client";

import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { motion } from 'framer-motion';
import { X, ArrowLeft, RefreshCw } from 'lucide-react';

export default function CheckoutCancelPage() {
  const searchParams = useSearchParams();
  const bookingId = searchParams.get('booking_id');

  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-32 pb-20">
        <motion.div
          className="max-w-xl mx-auto text-center"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          {/* Cancel icon */}
          <motion.div
            className="w-20 h-20 border-2 border-black/20 rounded-full flex items-center justify-center mx-auto mb-8"
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: "spring", stiffness: 200, delay: 0.2 }}
          >
            <X className="w-10 h-10 text-black/40" />
          </motion.div>

          <h1 className="heading-display text-4xl md:text-5xl mb-4">
            Payment Cancelled
          </h1>
          
          <p className="text-black/60 mb-8 max-w-md mx-auto">
            Your payment was cancelled. Don't worry — your booking is still saved and you can complete the payment when you're ready.
          </p>

          <div className="border-t border-black/10 pt-8 space-y-4">
            {bookingId && (
              <Link
                href={`/profile/bookings`}
                className="inline-flex items-center justify-center gap-2 w-full sm:w-auto bg-black text-white px-8 py-4 text-sm font-bold uppercase tracking-widest hover:bg-black/80 transition-colors"
              >
                <RefreshCw className="w-4 h-4" />
                Retry Payment
              </Link>
            )}

            <div className="block sm:hidden" />

            <Link
              href="/events"
              className="inline-flex items-center justify-center gap-2 w-full sm:w-auto border border-black/10 px-8 py-4 text-sm font-bold uppercase tracking-widest hover:border-black transition-colors sm:ml-4"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to Events
            </Link>
          </div>

          <div className="mt-12 p-6 border border-black/10 text-left">
            <h3 className="text-xs font-bold uppercase tracking-wider text-black/50 mb-3">
              Need Help?
            </h3>
            <p className="text-sm text-black/60">
              If you're experiencing issues with payment, please contact our support team at{' '}
              <a href="mailto:support@eventsberlin.com" className="underline hover:no-underline">
                support@eventsberlin.com
              </a>
            </p>
          </div>
        </motion.div>
      </div>

      <Footer />
    </div>
  );
}
