"use client";

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { motion } from 'framer-motion';
import { Check, Calendar, ArrowRight } from 'lucide-react';

function SuccessContent() {
  const searchParams = useSearchParams();
  const sessionId = searchParams.get('session_id');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Simulate short loading to ensure payment is processed
    const timer = setTimeout(() => setIsLoading(false), 1500);
    return () => clearTimeout(timer);
  }, []);

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
          {isLoading ? (
            <div className="py-20">
              <div className="w-16 h-16 border-2 border-black border-t-transparent rounded-full animate-spin mx-auto mb-6" />
              <p className="text-sm font-bold uppercase tracking-wide">Processing your payment...</p>
            </div>
          ) : (
            <>
              {/* Success icon */}
              <motion.div
                className="w-20 h-20 bg-black rounded-full flex items-center justify-center mx-auto mb-8"
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ type: "spring", stiffness: 200, delay: 0.2 }}
              >
                <Check className="w-10 h-10 text-white" />
              </motion.div>

              <h1 className="heading-display text-4xl md:text-5xl mb-4">
                Payment Successful
              </h1>
              
              <p className="text-black/60 mb-8 max-w-md mx-auto">
                Your booking has been confirmed. You will receive a confirmation email shortly with all the details.
              </p>

              {sessionId && (
                <p className="text-xs text-black/40 font-mono mb-8">
                  Transaction ID: {sessionId.slice(0, 20)}...
                </p>
              )}

              <div className="border-t border-black/10 pt-8 space-y-4">
                <Link
                  href="/events"
                  className="inline-flex items-center justify-center gap-2 w-full sm:w-auto bg-black text-white px-8 py-4 text-sm font-bold uppercase tracking-widest hover:bg-black/80 transition-colors"
                >
                  <Calendar className="w-4 h-4" />
                  Browse More Events
                </Link>

                <div className="block sm:hidden" />

                <Link
                  href="/profile/bookings"
                  className="inline-flex items-center justify-center gap-2 w-full sm:w-auto border border-black/10 px-8 py-4 text-sm font-bold uppercase tracking-widest hover:border-black transition-colors sm:ml-4"
                >
                  View My Bookings
                  <ArrowRight className="w-4 h-4" />
                </Link>
              </div>
            </>
          )}
        </motion.div>
      </div>

      <Footer />
    </div>
  );
}

export default function CheckoutSuccessPage() {
  return (
    <Suspense>
      <SuccessContent />
    </Suspense>
  );
}
