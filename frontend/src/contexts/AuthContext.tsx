import React, { createContext, useContext, useEffect, useState } from 'react';
import { api } from '@/lib/api';

export interface User {
  id: number;
  email: string;
  name: string;
  avatar_url?: string;
}

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  signup: (email: string, password: string, name: string) => Promise<void>;
  loading: boolean;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check if user is logged in on app start
    const token = localStorage.getItem('auth_token');
    if (token) {
      checkCurrentUser();
    } else {
      setLoading(false);
    }
  }, []);

  const checkCurrentUser = async () => {
    try {
      const userData = await api.get('/api/current_user');
      setUser(userData);
    } catch (error) {
      localStorage.removeItem('auth_token');
    } finally {
      setLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    const response = await api.post('/api/auth/login', {
      user: { email, password }
    });
    
    localStorage.setItem('auth_token', response.token);
    setUser(response.user);
  };

  const logout = async () => {
    try {
      await api.delete('/api/auth/logout');
    } catch (error) {
      // Continue with logout even if request fails
    } finally {
      localStorage.removeItem('auth_token');
      setUser(null);
    }
  };

  const signup = async (email: string, password: string, name: string) => {
    const response = await api.post('/api/auth/signup', {
      user: { email, password, name }
    });
    
    localStorage.setItem('auth_token', response.token);
    setUser(response.user);
  };

  const value = {
    user,
    login,
    logout,
    signup,
    loading,
    isAuthenticated: !!user,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};