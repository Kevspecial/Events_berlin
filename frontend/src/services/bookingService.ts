import api from '@/lib/api';
import { Booking, CreateBookingForm } from '@/types';

export interface CheckoutSession {
  checkout_url: string;
  session_id: string;
}

export const bookingService = {
  // Get user's bookings
  getMyBookings: async (): Promise<Booking[]> => {
    const response = await api.get('/users/bookings');
    return response.data;
  },

  // Create booking
  createBooking: async (bookingData: CreateBookingForm): Promise<Booking> => {
    const response = await api.post(`/events/${bookingData.event_id}/bookings`, bookingData);
    return response.data;
  },

  // Create checkout session for a booking
  createCheckoutSession: async (bookingId: number): Promise<CheckoutSession> => {
    const response = await api.post('/checkout/sessions', { booking_id: bookingId });
    return response.data;
  },

  // Get booking details
  getBooking: async (id: number): Promise<Booking> => {
    const response = await api.get(`/bookings/${id}`);
    return response.data;
  },

  // Update booking
  updateBooking: async (id: number, status: string): Promise<Booking> => {
    const response = await api.put(`/bookings/${id}`, { status });
    return response.data;
  },

  // Cancel booking
  cancelBooking: async (id: number): Promise<Booking> => {
    const response = await api.patch(`/bookings/${id}/cancel`);
    return response.data;
  },
};