// Frontend authentication service - syncs with Rails backend
import api from '@/lib/api';
import { AuthUser, SignupData, LoginData } from '@/types/auth';

const CURRENT_USER_KEY = 'evently_current_user';

export const authService = {
  // Get current user from localStorage
  getCurrentUser: (): AuthUser | null => {
    if (typeof window === 'undefined') return null;
    const user = localStorage.getItem(CURRENT_USER_KEY);
    return user ? JSON.parse(user) : null;
  },

  // Save current user to localStorage
  setCurrentUser: (user: AuthUser | null): void => {
    if (typeof window === 'undefined') return;
    if (user) {
      localStorage.setItem(CURRENT_USER_KEY, JSON.stringify(user));
    } else {
      localStorage.removeItem(CURRENT_USER_KEY);
    }
  },

  // Sign up a new user - creates user in backend
  signup: async (data: SignupData): Promise<{ success: boolean; user?: AuthUser; error?: string }> => {
    const { name, email, password, confirmPassword } = data;

    // Client-side validation
    if (!name || !email || !password) {
      return { success: false, error: 'All fields are required' };
    }

    if (password !== confirmPassword) {
      return { success: false, error: 'Passwords do not match' };
    }

    if (password.length < 6) {
      return { success: false, error: 'Password must be at least 6 characters' };
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return { success: false, error: 'Invalid email format' };
    }

    try {
      const response = await api.post('/signup', {
        user: {
          email: email.toLowerCase(),
          password,
          password_confirmation: confirmPassword,
        },
      });

      const backendUser = response.data;
      
      // Create AuthUser with name (stored locally since backend doesn't have name field)
      const authUser: AuthUser = {
        id: String(backendUser.id),
        email: backendUser.email,
        name, // Keep name locally
        role: backendUser.role || 'attendee',
        createdAt: backendUser.created_at,
      };

      authService.setCurrentUser(authUser);
      return { success: true, user: authUser };
    } catch (error: unknown) {
      const err = error as { response?: { data?: { errors?: string[]; error?: string } }; message?: string };
      const errorMessage = err.response?.data?.errors?.[0] || err.response?.data?.error || err.message || 'Signup failed';
      return { success: false, error: errorMessage };
    }
  },

  // Login user - authenticates with backend
  login: async (data: LoginData): Promise<{ success: boolean; user?: AuthUser; error?: string }> => {
    const { email, password } = data;

    if (!email || !password) {
      return { success: false, error: 'Email and password are required' };
    }

    try {
      const response = await api.post('/login', {
        email: email.toLowerCase(),
        password,
      });

      const { token, user: backendUser } = response.data;

      // Store JWT token so api.ts interceptor sends Authorization: Bearer <token>
      if (typeof window !== 'undefined' && token) {
        localStorage.setItem('authToken', token);
      }

      // Create AuthUser (name will be empty for backend-only users)
      const authUser: AuthUser = {
        id: String(backendUser.id),
        email: backendUser.email,
        name: backendUser.email.split('@')[0], // Use email prefix as display name
        role: backendUser.role || 'attendee',
        createdAt: backendUser.created_at,
      };

      authService.setCurrentUser(authUser);
      return { success: true, user: authUser };
    } catch (error: unknown) {
      const err = error as { response?: { data?: { error?: string } }; message?: string };
      const errorMessage = err.response?.data?.error || err.message || 'Invalid email or password';
      return { success: false, error: errorMessage };
    }
  },

  // Logout user
  logout: async (): Promise<void> => {
    try {
      await api.delete('/logout');
    } catch {
      // Ignore logout errors
    }
    if (typeof window !== 'undefined') {
      localStorage.removeItem('authToken');
    }
    authService.setCurrentUser(null);
  },

  // Check if user is authenticated
  isAuthenticated: (): boolean => {
    return authService.getCurrentUser() !== null;
  },
};
