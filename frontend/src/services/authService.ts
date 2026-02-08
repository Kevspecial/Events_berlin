// Frontend-only authentication service using localStorage
import { AuthUser, SignupData, LoginData, StoredUser } from '@/types/auth';

const USERS_STORAGE_KEY = 'evently_users';
const CURRENT_USER_KEY = 'evently_current_user';

// Simple hash function for demo purposes (NOT secure for production)
const simpleHash = (str: string): string => {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash.toString(36);
};

// Generate a simple UUID
const generateId = (): string => {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
};

export const authService = {
  // Get all stored users
  getStoredUsers: (): StoredUser[] => {
    if (typeof window === 'undefined') return [];
    const users = localStorage.getItem(USERS_STORAGE_KEY);
    return users ? JSON.parse(users) : [];
  },

  // Save users to storage
  saveUsers: (users: StoredUser[]): void => {
    if (typeof window === 'undefined') return;
    localStorage.setItem(USERS_STORAGE_KEY, JSON.stringify(users));
  },

  // Get current user
  getCurrentUser: (): AuthUser | null => {
    if (typeof window === 'undefined') return null;
    const user = localStorage.getItem(CURRENT_USER_KEY);
    return user ? JSON.parse(user) : null;
  },

  // Save current user
  setCurrentUser: (user: AuthUser | null): void => {
    if (typeof window === 'undefined') return;
    if (user) {
      localStorage.setItem(CURRENT_USER_KEY, JSON.stringify(user));
    } else {
      localStorage.removeItem(CURRENT_USER_KEY);
    }
  },

  // Sign up a new user
  signup: (data: SignupData): { success: boolean; user?: AuthUser; error?: string } => {
    const { name, email, password, confirmPassword } = data;

    // Validation
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

    // Check if user already exists
    const users = authService.getStoredUsers();
    const existingUser = users.find(u => u.email.toLowerCase() === email.toLowerCase());
    if (existingUser) {
      return { success: false, error: 'An account with this email already exists' };
    }

    // Create new user
    const newUser: StoredUser = {
      id: generateId(),
      email: email.toLowerCase(),
      name,
      role: 'attendee',
      createdAt: new Date().toISOString(),
      passwordHash: simpleHash(password),
    };

    // Save user
    users.push(newUser);
    authService.saveUsers(users);

    // Return user without password hash
    const authUser: AuthUser = {
      id: newUser.id,
      email: newUser.email,
      name: newUser.name,
      role: newUser.role,
      createdAt: newUser.createdAt,
    };

    // Auto-login after signup
    authService.setCurrentUser(authUser);

    return { success: true, user: authUser };
  },

  // Login user
  login: (data: LoginData): { success: boolean; user?: AuthUser; error?: string } => {
    const { email, password } = data;

    if (!email || !password) {
      return { success: false, error: 'Email and password are required' };
    }

    const users = authService.getStoredUsers();
    const user = users.find(u => u.email.toLowerCase() === email.toLowerCase());

    if (!user) {
      return { success: false, error: 'Invalid email or password' };
    }

    if (user.passwordHash !== simpleHash(password)) {
      return { success: false, error: 'Invalid email or password' };
    }

    // Return user without password hash
    const authUser: AuthUser = {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      createdAt: user.createdAt,
    };

    authService.setCurrentUser(authUser);

    return { success: true, user: authUser };
  },

  // Logout user
  logout: (): void => {
    authService.setCurrentUser(null);
  },

  // Check if user is authenticated
  isAuthenticated: (): boolean => {
    return authService.getCurrentUser() !== null;
  },
};
