'use client';

import { useAuth } from '@/providers/AuthProvider';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import Link from 'next/link';
import { useMyBookings } from '@/hooks/useBookings';
import type { Booking } from '@/types';

export default function BookingsPage() {
  const { user, isLoading: authLoading } = useAuth();
  const router = useRouter();
  const { data: bookings, isLoading: bookingsLoading } = useMyBookings();

  useEffect(() => {
    if (!authLoading && !user) {
      router.push('/login');
    }
  }, [user, authLoading, router]);

  if (authLoading || bookingsLoading) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-12 pt-24">
        <div className="animate-pulse space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-24 bg-gray-100 rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  if (!user) return null;

  return (
    <div className="max-w-3xl mx-auto px-4 py-12 pt-24">
      <div className="flex items-center gap-4 mb-8">
        <Link href="/profile" className="text-gray-500 hover:text-gray-700">
          ← Profile
        </Link>
        <h1 className="text-3xl font-bold">My Bookings</h1>
      </div>

      {!bookings || bookings.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-gray-500 mb-4">No bookings yet.</p>
          <Link
            href="/events"
            className="px-6 py-3 bg-black text-white rounded-lg font-medium hover:bg-gray-800 transition-colors"
          >
            Browse Events
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          {bookings.map((booking: Booking) => (
            <div
              key={booking.id}
              className="bg-white rounded-xl shadow p-6 flex items-center justify-between border border-black/10"
            >
              <div>
                <p className="font-semibold">{booking.event?.name ?? 'Event'}</p>
                <p className="text-sm text-gray-500">
                  {booking.event?.date
                    ? new Date(booking.event.date).toLocaleDateString('de-DE', {
                        day: 'numeric',
                        month: 'long',
                        year: 'numeric',
                      })
                    : ''}
                </p>
              </div>
              <span
                className={`px-3 py-1 rounded-full text-sm font-medium ${
                  booking.status === 'confirmed'
                    ? 'bg-green-100 text-green-800'
                    : booking.status === 'cancelled'
                    ? 'bg-red-100 text-red-800'
                    : 'bg-yellow-100 text-yellow-800'
                }`}
              >
                {booking.status}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
