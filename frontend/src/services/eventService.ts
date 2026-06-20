import api from '@/lib/api';
import { Event, Category, Venue, CreateEventForm, PaginatedResponse, ApiResponse } from '@/types';

export const eventService = {
  // Get all events
  getEvents: async (params?: {
    page?: number;
    per_page?: number;
    search?: string;
    category?: string;
  }): Promise<PaginatedResponse<Event>> => {
    const response = await api.get('/events', { params });
    // Handle the case where the API returns just an array of events
    if (Array.isArray(response.data)) {
      return {
        data: response.data,
        meta: {
          current_page: 1,
          total_pages: 1,
          total_count: response.data.length,
          per_page: response.data.length,
        },
      };
    }
    return response.data;
  },

  // Get single event
  getEvent: async (id: number): Promise<Event> => {
    const response = await api.get(`/events/${id}`);
    return response.data;
  },

  // Create event
  createEvent: async (eventData: CreateEventForm): Promise<Event> => {
    const formData = new FormData();
    
    Object.entries(eventData).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        if (key === 'image' && value instanceof File) {
          formData.append(`event[${key}]`, value);
        } else {
          formData.append(`event[${key}]`, value.toString());
        }
      }
    });

    const response = await api.post('/events', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },

  // Update event
  updateEvent: async (id: number, eventData: Partial<CreateEventForm>): Promise<Event> => {
    const response = await api.put(`/events/${id}`, eventData);
    return response.data;
  },

  // Delete event
  deleteEvent: async (id: number): Promise<void> => {
    await api.delete(`/events/${id}`);
  },

  // Get events by category
  getEventsByCategory: async (categoryId: number): Promise<Event[]> => {
    const response = await api.get(`/events?category_id=${categoryId}`);
    return response.data;
  },

  // Search events
  searchEvents: async (query: string): Promise<Event[]> => {
    const response = await api.get(`/events?search=${encodeURIComponent(query)}`);
    return response.data;
  },

  // Get all categories
  getCategories: async (): Promise<Category[]> => {
    const response = await api.get('/categories');
    return response.data;
  },

  // Get all venues
  getVenues: async (): Promise<Venue[]> => {
    const response = await api.get('/venues');
    return response.data;
  },
};