// Auth-specific types for frontend-only authentication

export interface AuthUser {
  id: string;
  email: string;
  name: string;
  role: 'attendee' | 'organizer' | 'admin';
  createdAt: string;
}

export interface SignupData {
  name: string;
  email: string;
  password: string;
  confirmPassword: string;
}

export interface LoginData {
  email: string;
  password: string;
}

export interface StoredUser extends AuthUser {
  passwordHash: string;
}

export interface AuthState {
  user: AuthUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}
