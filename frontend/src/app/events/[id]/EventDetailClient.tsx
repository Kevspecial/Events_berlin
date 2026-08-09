"use client";

import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { useEvent } from '@/hooks/useEvents';
import { bookingService } from '@/services/bookingService';
import type { TicketType, Event as EventType } from '@/types';
import { format } from 'date-fns';
import { motion } from 'framer-motion';
import { Calendar, MapPin, ArrowLeft, Ticket, Users, CreditCard } from 'lucide-react';

type EventWithTickets = EventType & { ticket_types?: TicketType[] };

export default function EventDetailClient() {
  const params = useParams<{ id: string }>();
  const id = Number(params?.id);
  const { data: eventData, isLoading, error } = useEvent(id);
  const event = eventData as unknown as EventWithTickets | undefined;

  const [ticketTypeId, setTicketTypeId] = useState<number | null>(null);
  const [quantity, setQuantity] = useState<number>(1);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  useEffect(() => {
    if (event?.ticket_types && event.ticket_types.length > 0 && ticketTypeId == null) {
      setTicketTypeId(event.ticket_types[0].id);
    }
  }, [event?.ticket_types, ticketTypeId]);

  const totalPrice = useMemo(() => {
    if (!event?.ticket_types) return 0;
    const tt = event.ticket_types.find((t) => t.id === ticketTypeId);
    return tt ? Number(tt.price || 0) * (quantity || 0) : 0;
  }, [event?.ticket_types, ticketTypeId, quantity]);

  const handleBook = async () => {
    if (!event || ticketTypeId == null || quantity < 1) return;
    setSubmitting(true);
    setSubmitError(null);

    try {
      // Step 1: Create the booking (pending status)
      const booking = await bookingService.createBooking({
        event_id: event.id,
        ticket_type_id: ticketTypeId,
        quantity,
      });

      // Step 2: Create Stripe checkout session
      const { checkout_url } = await bookingService.createCheckoutSession(booking.id);

      // Step 3: Redirect to Stripe Checkout
      window.location.href = checkout_url;
    } catch (e) {
      const err = e as { response?: { data?: { message?: string; errors?: string[] } }; message?: string };
      setSubmitError(
        err?.response?.data?.message ||
        err?.response?.data?.errors?.[0] ||
        err?.message ||
        'Booking failed. Please try again.'
      );
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        {/* Back link */}
        <Link
          href="/events"
          className="inline-flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-black/50 hover:text-black transition-colors mb-8"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Events
        </Link>

        {isLoading ? (
          <div className="animate-pulse">
            <div className="h-10 bg-black/5 w-2/3 mb-4" />
            <div className="h-4 bg-black/5 w-1/3 mb-2" />
            <div className="h-4 bg-black/5 w-1/2 mb-8" />
            <div className="h-64 bg-black/5" />
          </div>
        ) : error ? (
          <div className="border border-black/10 p-10 max-w-md">
            <p className="text-3xl font-black mb-3">!</p>
            <h2 className="text-base font-black uppercase tracking-tight mb-2">Error loading event</h2>
            <p className="text-sm text-black/50">{(error as Error).message || 'Please try again.'}</p>
          </div>
        ) : event ? (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
            {/* Main content */}
            <motion.div
              className="lg:col-span-2"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
            >
              {/* Event image */}
              {event.image_url && (
                <div className="aspect-[16/9] bg-black/5 mb-8 overflow-hidden">
                  <img
                    src={event.image_url}
                    alt={event.name}
                    className="w-full h-full object-cover"
                  />
                </div>
              )}

              {/* Category badge */}
              {event.category && (
                <span className="inline-block bg-black text-white px-3 py-1 text-xs font-bold uppercase tracking-wider mb-4">
                  {event.category.name}
                </span>
              )}

              <h1 className="heading-display text-[clamp(2rem,5vw,3.5rem)] mb-6">
                {event.name}
              </h1>

              <div className="flex flex-wrap gap-6 mb-8 text-sm">
                <span className="flex items-center gap-2">
                  <Calendar className="w-4 h-4" />
                  {format(new Date(event.date), 'EEEE, MMMM d, yyyy • h:mm a')}
                </span>
                <span className="flex items-center gap-2">
                  <MapPin className="w-4 h-4" />
                  {event.location}
                </span>
                {event.capacity && (
                  <span className="flex items-center gap-2">
                    <Users className="w-4 h-4" />
                    {event.capacity} spots
                  </span>
                )}
              </div>

              <div className="border-t border-black/10 pt-8">
                <h2 className="text-lg font-black uppercase tracking-tight mb-4">About This Event</h2>
                <p className="text-black/70 whitespace-pre-line leading-relaxed">
                  {event.description}
                </p>
              </div>
            </motion.div>

            {/* Ticket sidebar */}
            <motion.div
              className="lg:col-span-1"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.6, delay: 0.15 }}
            >
              <div className="border border-black/10 p-6 sticky top-24">
                <div className="flex items-center gap-2 mb-6">
                  <Ticket className="w-5 h-5" />
                  <h3 className="text-lg font-black uppercase tracking-tight">Tickets</h3>
                </div>

                {event.ticket_types && event.ticket_types.length > 0 ? (
                  <div className="space-y-5">
                    <div>
                      <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                        Ticket Type
                      </label>
                      <select
                        value={ticketTypeId ?? ''}
                        onChange={(e) => setTicketTypeId(Number(e.target.value))}
                        className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                      >
                        {event.ticket_types.map((t) => (
                          <option key={t.id} value={t.id}>
                            {t.name} — €{Number(t.price).toFixed(2)}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                        Quantity
                      </label>
                      <input
                        type="number"
                        min={1}
                        value={quantity}
                        onChange={(e) => setQuantity(Number(e.target.value))}
                        className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                      />
                    </div>

                    <div className="flex items-center justify-between py-4 border-t border-black/10">
                      <span className="text-sm font-bold uppercase tracking-wide">Total</span>
                      <span className="text-2xl font-black">€{totalPrice.toFixed(2)}</span>
                    </div>

                    {submitError && (
                      <div className="text-sm text-black bg-black/5 border border-black/10 p-3">
                        {submitError}
                      </div>
                    )}

                    <button
                      onClick={handleBook}
                      disabled={submitting}
                      className="w-full bg-black text-white py-4 text-sm font-bold uppercase tracking-widest hover:bg-black/80 disabled:opacity-50 transition-colors flex items-center justify-center gap-2"
                    >
                      {submitting ? (
                        <>
                          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                          Redirecting to Checkout...
                        </>
                      ) : (
                        <>
                          <CreditCard className="w-4 h-4" />
                          Pay €{totalPrice.toFixed(2)}
                        </>
                      )}
                    </button>

                    <p className="text-xs text-black/40 text-center mt-3">
                      Secure payment powered by Stripe
                    </p>
                  </div>
                ) : (
                  <p className="text-sm text-black/50">No tickets available for this event.</p>
                )}
              </div>
            </motion.div>
          </div>
        ) : (
          <div className="text-center py-20">
            <div className="border border-black/10 p-10 max-w-md mx-auto">
              <p className="text-4xl mb-4">&#8709;</p>
              <h3 className="text-base font-black uppercase tracking-tight mb-2">Event not found</h3>
              <p className="text-sm text-black/50">It may have been removed or the link is incorrect.</p>
            </div>
          </div>
        )}
      </div>

      <Footer />
    </div>
  );
}
