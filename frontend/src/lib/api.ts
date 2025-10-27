import axios, { AxiosHeaders, type AxiosRequestHeaders } from 'axios';

// API base URL - adjust according to your Rails server
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1';

// Create axios instance with default config
export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token if available
api.interceptors.request.use(
  (config) => {
    const isBrowser = typeof window !== 'undefined';
    if (isBrowser) {
      const token = window.localStorage.getItem('authToken');
      if (token) {
        if (config.headers instanceof AxiosHeaders) {
          config.headers.set('Authorization', `Bearer ${token}`);
        } else {
          const headers = (config.headers ?? {}) as AxiosRequestHeaders;
          (headers as Record<string, unknown>)['Authorization'] = `Bearer ${token}`;
          config.headers = headers;
        }
      }
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    const isBrowser = typeof window !== 'undefined';
    if (error.response && error.response.status === 401) {
      if (isBrowser) {
        window.localStorage.removeItem('authToken');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;