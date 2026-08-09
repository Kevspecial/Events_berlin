'use client';

import { useAuth } from '@/providers/AuthProvider';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import Link from 'next/link';

export default function ProfilePage() {
  const { user, logout, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
    }
  }, [user, isLoading, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p>Loading...</p>
      </div>
    );
  }

  if (!user) return null;

  return (
    <div className="max-w-2xl mx-auto px-4 py-12 pt-24">
      <h1 className="text-3xl font-bold mb-8">My Profile</h1>
      <div className="bg-white rounded-xl shadow p-6 mb-6 border border-black/10">
        <p className="text-gray-600 text-sm mb-1">Name</p>
        <p className="font-medium">{user.name}</p>
        <p className="text-gray-600 text-sm mt-4 mb-1">Email</p>
        <p className="font-medium">{user.email}</p>
        <p className="text-gray-600 text-sm mt-4 mb-1">Role</p>
        <p className="font-medium capitalize">{user.role}</p>
      </div>
      <div className="flex gap-4">
        <Link
          href="/profile/bookings"
          className="px-6 py-3 bg-black text-white rounded-lg font-medium hover:bg-gray-800 transition-colors"
        >
          My Bookings
        </Link>
        <button
          onClick={logout}
          className="px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
        >
          Sign Out
        </button>
      </div>
    </div>
  );
}
