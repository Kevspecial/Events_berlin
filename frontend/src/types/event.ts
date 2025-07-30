export interface Event {
  id: number;
  name: string;
  description: string;
  date: string;
  location: string;
  private: boolean;
  creator_id: number;
  creator: {
    id: number;
    email: string;
  };
  attendees_count: number;
  is_attending: boolean;
  can_edit: boolean;
  created_at: string;
  updated_at: string;
}

export interface EventFormData {
  name: string;
  description: string;
  date: string;
  location: string;
  private: boolean;
}

export interface Invitation {
  id: number;
  event_id: number;
  inviter_id: number;
  invitee_id: number;
  event: Event;
  created_at: string;
}