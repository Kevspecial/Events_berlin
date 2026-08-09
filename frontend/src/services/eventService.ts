import api from '@/lib/api';
import { Event, CreateEventForm, PaginatedResponse, ApiResponse } from '@/types';

export const eventService = {
  // Get all events
  getEvents: async (params?: {
    page?: number;
    per_page?: number;
    search?: string;
    category?: string;
  }): Promise<PaginatedResponse<Event>> => {
    const response = await api.get('/events', { params });
    // Handle the case where the API returns just an array of events (legacy)
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
    // Handle pagy paginated response: { events: [...], meta: { page, pages, count, limit, ... } }
    const { events, meta: pagyMeta } = response.data;
    return {
      data: events,
      meta: {
        current_page: pagyMeta.page ?? 1,
        total_pages: pagyMeta.pages ?? 1,
        total_count: pagyMeta.count ?? 0,
        per_page: pagyMeta.limit ?? 20,
      },
    };
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
          formData.append(key, value);
        } else {
          formData.append(key, value.toString());
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
    return Array.isArray(response.data) ? response.data : response.data.events;
  },

  // Search events
  searchEvents: async (query: string): Promise<Event[]> => {
    const response = await api.get(`/events?search=${encodeURIComponent(query)}`);
    return Array.isArray(response.data) ? response.data : response.data.events;
  },
};