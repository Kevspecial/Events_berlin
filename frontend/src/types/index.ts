// User types
export interface User {
  id: number;
  email: string;
  role: 'attendee' | 'organizer' | 'admin';
  created_at: string;
  updated_at: string;
}

// Category types
export interface Category {
  id: number;
  name: string;
  description: string;
  created_at: string;
  updated_at: string;
}

// Venue types
export interface Venue {
  id: number;
  name: string;
  address: string;
  city?: string;
  capacity?: number;
  description?: string;
  created_at: string;
  updated_at: string;
}

// Event types
export interface Event {
  id: number;
  name: string;
  description: string;
  location: string;
  date: string;
  price?: number;
  capacity?: number;
  private: boolean;
  creator_id: number;
  category_id?: number;
  venue_id?: number;
  created_at: string;
  updated_at: string;
  creator?: User;
  category?: Category;
  venue?: Venue;
  image_url?: string;
}

// Ticket Type
export interface TicketType {
  id: number;
  name: string;
  price: number;
  quantity: number;
  event_id: number;
  created_at: string;
  updated_at: string;
}

// Booking types
export interface Booking {
  id: number;
  user_id: number;
  event_id: number;
  ticket_type_id: number;
  quantity: number;
  total_price: number;
  status: 'pending' | 'confirmed' | 'cancelled';
  created_at: string;
  updated_at: string;
  user?: User;
  event?: Event;
  ticket_type?: TicketType;
}

// API Response types
export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

// Form types
export interface CreateEventForm {
  name: string;
  description: string;
  location: string;
  date: string;
  price?: number;
  capacity?: number;
  private: boolean;
  category_id?: number;
  venue_id?: number;
  image?: File;
}

export interface CreateBookingForm {
  event_id: number;
  ticket_type_id: number;
  quantity: number;
}