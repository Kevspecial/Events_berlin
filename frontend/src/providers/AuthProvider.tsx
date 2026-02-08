'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { AuthUser, AuthState, SignupData, LoginData } from '@/types/auth';
import { authService } from '@/services/authService';

interface AuthContextType extends AuthState {
  login: (data: LoginData) => Promise<{ success: boolean; error?: string }>;
  signup: (data: SignupData) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null,
    isAuthenticated: false,
    isLoading: true,
  });

  // Initialize auth state from localStorage
  useEffect(() => {
    const user = authService.getCurrentUser();
    setState({
      user,
      isAuthenticated: !!user,
      isLoading: false,
    });
  }, []);

  const login = useCallback(async (data: LoginData) => {
    const result = await authService.login(data);
    if (result.success && result.user) {
      setState({
        user: result.user,
        isAuthenticated: true,
        isLoading: false,
      });
    }
    return { success: result.success, error: result.error };
  }, []);

  const signup = useCallback(async (data: SignupData) => {
    const result = await authService.signup(data);
    if (result.success && result.user) {
      setState({
        user: result.user,
        isAuthenticated: true,
        isLoading: false,
      });
    }
    return { success: result.success, error: result.error };
  }, []);

  const logout = useCallback(async () => {
    await authService.logout();
    setState({
      user: null,
      isAuthenticated: false,
      isLoading: false,
    });
  }, []);

  return (
    <AuthContext.Provider value={{ ...state, login, signup, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
