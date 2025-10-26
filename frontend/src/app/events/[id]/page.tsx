"use client";

import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import Navbar from '@/components/Navbar';
import { useEvent } from '@/hooks/useEvents';
import { bookingService } from '@/services/bookingService';
import type { TicketType, Event as EventType } from '@/types';
import { format } from 'date-fns';

type EventWithTickets = EventType & { ticket_types?: TicketType[] };

export default function EventDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params?.id);
  const { data: eventData, isLoading, error } = useEvent(id);
  const event = eventData as unknown as EventWithTickets | undefined;

  const [ticketTypeId, setTicketTypeId] = useState<number | null>(null);
  const [quantity, setQuantity] = useState<number>(1);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submitSuccess, setSubmitSuccess] = useState<boolean>(false);

  useEffect(() => {
    if (event?.ticket_types && event.ticket_types.length > 0 && ticketTypeId == null) {
      setTicketTypeId(event.ticket_types[0].id);
    }
  }, [event?.ticket_types, ticketTypeId]);

  const totalPrice = useMemo(() => {
    if (!event?.ticket_types) return 0;
    const tt = event.ticket_types.find((t) => t.id === ticketTypeId);
    return tt ? (tt.price || 0) * (quantity || 0) : 0;
  }, [event?.ticket_types, ticketTypeId, quantity]);

  const handleBook = async () => {
  if (!event || ticketTypeId == null || quantity < 1) return;
    setSubmitting(true);
    setSubmitError(null);
    setSubmitSuccess(false);
    try {
      await bookingService.createBooking({
        event_id: event.id,
        ticket_type_id: ticketTypeId,
        quantity,
      });
      setSubmitSuccess(true);
      // Optional: navigate to a bookings page if available
      // router.push(`/bookings/${booking.id}`);
    } catch (e) {
      const err = e as { response?: { data?: { message?: string } } ; message?: string };
      setSubmitError(err?.response?.data?.message || err?.message || 'Booking failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {isLoading ? (
          <div className="animate-pulse">
            <div className="h-8 bg-gray-200 w-2/3 mb-4 rounded" />
            <div className="h-4 bg-gray-200 w-1/3 mb-2 rounded" />
            <div className="h-4 bg-gray-200 w-1/2 mb-8 rounded" />
            <div className="h-48 bg-gray-200 rounded" />
          </div>
        ) : error ? (
          <div className="bg-red-50 border border-red-200 rounded-lg p-6">
            <div className="text-red-500 text-3xl mb-2">⚠️</div>
            <h2 className="text-lg font-semibold text-red-900 mb-1">Error loading event</h2>
            <p className="text-red-700">{(error as Error).message || 'Please try again.'}</p>
          </div>
        ) : event ? (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <div className="lg:col-span-2">
              <h1 className="text-3xl font-bold text-gray-900 mb-2">{event.name}</h1>
              <p className="text-gray-600 mb-1">{format(new Date(event.date), 'PPpp')}</p>
              <p className="text-gray-600 mb-6">{event.location}</p>
              <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <h2 className="text-xl font-semibold text-gray-900 mb-4">About this event</h2>
                <p className="text-gray-700 whitespace-pre-line">{event.description}</p>
              </div>
            </div>
            <div className="lg:col-span-1">
              <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Tickets</h3>
                {event.ticket_types && event.ticket_types.length > 0 ? (
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Ticket Type</label>
                      <select
                        value={ticketTypeId ?? ''}
                        onChange={(e) => setTicketTypeId(Number(e.target.value))}
                        className="w-full border border-gray-300 rounded-lg px-3 py-2"
                      >
                        {event.ticket_types.map((t) => (
                          <option key={t.id} value={t.id}>
                            {t.name} — €{t.price.toFixed(2)}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Quantity</label>
                      <input
                        type="number"
                        min={1}
                        value={quantity}
                        onChange={(e) => setQuantity(Number(e.target.value))}
                        className="w-full border border-gray-300 rounded-lg px-3 py-2"
                      />
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-gray-700 font-medium">Total</span>
                      <span className="text-gray-900 font-semibold">€{totalPrice.toFixed(2)}</span>
                    </div>
                    {submitError && (
                      <div className="text-sm text-red-700 bg-red-50 border border-red-200 rounded p-2">{submitError}</div>
                    )}
                    {submitSuccess && (
                      <div className="text-sm text-green-700 bg-green-50 border border-green-200 rounded p-2">Booking created!</div>
                    )}
                    <button
                      onClick={handleBook}
                      disabled={submitting}
                      className="w-full bg-orange-600 hover:bg-orange-700 text-white px-4 py-2 rounded-lg font-medium disabled:opacity-50"
                    >
                      {submitting ? 'Processing...' : 'Book Now'}
                    </button>
                  </div>
                ) : (
                  <p className="text-gray-600">No tickets available for this event.</p>
                )}
              </div>
            </div>
          </div>
        ) : (
          <div className="text-center py-12">
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 max-w-md mx-auto">
              <div className="text-gray-400 text-4xl mb-4">🔍</div>
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Event not found</h3>
              <p className="text-gray-600">It may have been removed or the link is incorrect.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
