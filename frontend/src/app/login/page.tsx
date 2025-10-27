"use client";

import Link from 'next/link';
import { WEB_ORIGIN } from '@/lib/config';

export default function LoginPage() {
  const loginUrl = `${WEB_ORIGIN}/users/sign_in`;
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <div className="w-full max-w-md bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Log in</h1>
        <p className="text-gray-600 mb-6">You’ll be redirected to our secure login page.</p>

        <a
          href={loginUrl}
          className="w-full inline-flex items-center justify-center px-4 py-3 bg-orange-600 hover:bg-orange-700 text-white font-medium rounded-lg transition-colors"
        >
          Continue to Login
        </a>

        <p className="mt-6 text-sm text-gray-600">
          Don’t have an account?{' '}
          <Link href="/signup" className="text-orange-600 hover:text-orange-700 font-medium">
            Sign up
          </Link>
        </p>
      </div>
    </div>
  );
}
