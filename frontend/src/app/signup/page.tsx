"use client";

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/providers/AuthProvider';
import { motion } from 'framer-motion';

export default function SignupPage() {
  const router = useRouter();
  const { signup } = useAuth();
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value,
    }));
    setError('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    const result = await signup(formData);
    
    if (result.success) {
      router.push('/');
    } else {
      setError(result.error || 'Signup failed');
    }
    
    setIsLoading(false);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-white p-6">
      <motion.div
        className="w-full max-w-md"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <Link href="/" className="block text-2xl font-black uppercase tracking-tight mb-12 hover:opacity-50 transition-opacity">
          Berlin_Events
        </Link>

        <h1 className="heading-section text-4xl mb-2">Sign Up</h1>
        <p className="text-sm font-bold uppercase tracking-wide text-black/50 mb-8">
          Join Berlin_Events to discover amazing events.
        </p>

        {error && (
          <div className="mb-6 p-4 border border-black/20 text-sm font-bold">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label htmlFor="name" className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
              Full Name
            </label>
            <input
              type="text"
              id="name"
              name="name"
              value={formData.name}
              onChange={handleChange}
              required
              className="w-full px-4 py-3 border border-black/10 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
              placeholder="Enter your full name"
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
              Email
            </label>
            <input
              type="email"
              id="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              required
              className="w-full px-4 py-3 border border-black/10 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
              placeholder="Enter your email"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
              Password
            </label>
            <input
              type="password"
              id="password"
              name="password"
              value={formData.password}
              onChange={handleChange}
              required
              minLength={6}
              className="w-full px-4 py-3 border border-black/10 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
              placeholder="Create a password (min 6 characters)"
            />
          </div>

          <div>
            <label htmlFor="confirmPassword" className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
              Confirm Password
            </label>
            <input
              type="password"
              id="confirmPassword"
              name="confirmPassword"
              value={formData.confirmPassword}
              onChange={handleChange}
              required
              className="w-full px-4 py-3 border border-black/10 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
              placeholder="Confirm your password"
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full px-4 py-4 bg-black hover:bg-black/80 disabled:bg-black/30 text-white text-sm font-bold uppercase tracking-widest transition-colors"
          >
            {isLoading ? 'Creating account...' : 'Sign Up'}
          </button>
        </form>

        <p className="mt-8 text-sm font-bold text-center">
          Already have an account?{' '}
          <Link href="/login" className="underline decoration-2 underline-offset-4 hover:opacity-50 transition-opacity">
            Log in
          </Link>
        </p>
      </motion.div>
    </div>
  );
}
