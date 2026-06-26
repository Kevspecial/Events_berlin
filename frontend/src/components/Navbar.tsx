'use client';

import Link from 'next/link';
import { useState } from 'react';
import { useAuth } from '@/providers/AuthProvider';
import { motion, AnimatePresence } from 'framer-motion';
import { Menu, X } from 'lucide-react';

const navLinks = [
  { label: 'Events', href: '/events' },
  { label: 'Create Event', href: '/events/create' },
  { label: 'About', href: '/about' },
];

export default function Navbar() {
  const { user, isAuthenticated, isLoading, logout } = useAuth();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isProfileOpen, setIsProfileOpen] = useState(false);

  const handleLogout = () => {
    logout();
    setIsMenuOpen(false);
    setIsProfileOpen(false);
  };

  return (
    <nav className="fixed top-0 w-full bg-white z-50 border-b border-black/10">
      <div className="max-w-[1400px] mx-auto px-6 lg:px-10">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <Link
            href="/"
            className="text-2xl font-black tracking-tight uppercase hover:opacity-70 transition-opacity"
          >
            Berlin_Events
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="text-sm font-bold uppercase tracking-wide text-black hover:opacity-50 transition-opacity"
              >
                {link.label}
              </Link>
            ))}
          </div>

          {/* Desktop Auth */}
          <div className="hidden md:flex items-center gap-4">
            {isLoading ? (
              <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
            ) : isAuthenticated && user ? (
              <div className="relative">
                <button
                  onClick={() => setIsProfileOpen(!isProfileOpen)}
                  className="flex items-center gap-2 text-sm font-bold uppercase tracking-wide hover:opacity-50 transition-opacity"
                >
                  <div className="w-8 h-8 bg-black text-white rounded-full flex items-center justify-center text-xs font-black">
                    {user.name.charAt(0).toUpperCase()}
                  </div>
                  <span>{user.name}</span>
                </button>

                <AnimatePresence>
                  {isProfileOpen && (
                    <motion.div
                      initial={{ opacity: 0, y: -4 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -4 }}
                      transition={{ duration: 0.15 }}
                      className="absolute right-0 mt-3 w-56 bg-white border border-black/10 shadow-lg"
                    >
                      <div className="px-4 py-3 border-b border-black/10">
                        <p className="text-xs text-black/50 uppercase tracking-wider">Signed in as</p>
                        <p className="text-sm font-bold truncate mt-1">{user.email}</p>
                      </div>
                      <Link
                        href="/profile"
                        onClick={() => setIsProfileOpen(false)}
                        className="block w-full text-left px-4 py-3 text-sm font-bold uppercase tracking-wide hover:bg-black hover:text-white transition-colors"
                      >
                        Profile
                      </Link>
                      <button
                        onClick={handleLogout}
                        className="w-full text-left px-4 py-3 text-sm font-bold uppercase tracking-wide hover:bg-black hover:text-white transition-colors"
                      >
                        Sign Out
                      </button>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            ) : (
              <>
                <Link
                  href="/login"
                  className="text-sm font-bold uppercase tracking-wide hover:opacity-50 transition-opacity"
                >
                  Log In
                </Link>
                <Link
                  href="/signup"
                  className="bg-black text-white px-5 py-2 text-sm font-bold uppercase tracking-wide hover:bg-black/80 transition-colors"
                >
                  Sign Up
                </Link>
              </>
            )}
          </div>

          {/* Mobile menu button */}
          <button
            onClick={() => setIsMenuOpen(!isMenuOpen)}
            className="md:hidden p-1 hover:opacity-50 transition-opacity"
            aria-label="Toggle navigation menu"
            aria-expanded={isMenuOpen}
          >
            {isMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </div>

      {/* Mobile Menu */}
      <AnimatePresence>
        {isMenuOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="md:hidden border-t border-black/10 bg-white overflow-hidden"
          >
            <div className="px-6 py-6 space-y-1">
              {navLinks.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="block py-3 text-lg font-black uppercase tracking-tight hover:opacity-50 transition-opacity"
                  onClick={() => setIsMenuOpen(false)}
                >
                  {link.label}
                </Link>
              ))}

              <div className="pt-4 border-t border-black/10">
                {isAuthenticated && user ? (
                  <>
                    <div className="py-3">
                      <p className="text-xs text-black/50 uppercase tracking-wider">Signed in as</p>
                      <p className="text-sm font-bold mt-1">{user.email}</p>
                    </div>
                    <Link
                      href="/profile"
                      className="block py-3 text-lg font-black uppercase tracking-tight hover:opacity-50 transition-opacity"
                      onClick={() => setIsMenuOpen(false)}
                    >
                      Profile
                    </Link>
                    <button
                      onClick={handleLogout}
                      className="block w-full text-left py-3 text-lg font-black uppercase tracking-tight hover:opacity-50 transition-opacity"
                    >
                      Sign Out
                    </button>
                  </>
                ) : (
                  <>
                    <Link
                      href="/login"
                      className="block py-3 text-lg font-black uppercase tracking-tight hover:opacity-50 transition-opacity"
                      onClick={() => setIsMenuOpen(false)}
                    >
                      Log In
                    </Link>
                    <Link
                      href="/signup"
                      className="block py-3 text-lg font-black uppercase tracking-tight hover:opacity-50 transition-opacity"
                      onClick={() => setIsMenuOpen(false)}
                    >
                      Sign Up
                    </Link>
                  </>
                )}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </nav>
  );
}
