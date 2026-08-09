import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4">
      <p className="text-6xl font-bold text-gray-200 mb-4">404</p>
      <h1 className="text-2xl font-bold mb-2">Page not found</h1>
      <p className="text-gray-500 mb-8">The page you&apos;re looking for doesn&apos;t exist.</p>
      <Link
        href="/"
        className="px-6 py-3 bg-black text-white rounded-lg font-medium hover:bg-gray-800 transition-colors"
      >
        Back to Home
      </Link>
    </div>
  );
}
