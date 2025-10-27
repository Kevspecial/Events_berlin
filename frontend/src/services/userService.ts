import api from '@/lib/api';
import { User } from '@/types';

export const userService = {
  // Get user profile
  getProfile: async (): Promise<User> => {
    const response = await api.get('/users/profile');
    return response.data;
  },

  // Get user's events (created events)
  getMyEvents: async (): Promise<Event[]> => {
    const response = await api.get('/users/events');
    return response.data;
  },

  // Update user profile
  updateProfile: async (userData: Partial<User>): Promise<User> => {
    const response = await api.put('/users/profile', userData);
    return response.data;
  },
};