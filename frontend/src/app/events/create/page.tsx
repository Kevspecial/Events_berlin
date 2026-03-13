"use client";

import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/providers/AuthProvider';
import { eventService } from '@/services/eventService';
import type { CreateEventForm } from '@/types';
import { motion } from 'framer-motion';
import { Upload, Check } from 'lucide-react';

export default function CreateEventPage() {
  const { user, isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && (!isAuthenticated || (user?.role !== 'organizer' && user?.role !== 'admin'))) {
      router.replace('/events');
    }
  }, [isLoading, isAuthenticated, user, router]);

  if (isLoading || !isAuthenticated || (user?.role !== 'organizer' && user?.role !== 'admin')) {
    return null;
  }
  const [form, setForm] = useState<CreateEventForm>({
    name: '',
    description: '',
    location: '',
    date: '',
    private: false,
  });
  const [image, setImage] = useState<File | undefined>(undefined);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<boolean>(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    setSuccess(false);
    try {
      await eventService.createEvent({ ...form, image });
      setSuccess(true);
      setForm({ name: '', description: '', location: '', date: '', private: false });
      setImage(undefined);
    } catch (err) {
      const e = err as { response?: { data?: { message?: string } }; message?: string };
      setError(e?.response?.data?.message || e?.message || 'Failed to create event');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-3xl mx-auto px-6 lg:px-10 pt-24 pb-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h1 className="heading-display text-[clamp(2rem,5vw,3rem)] mb-3">
            Create Event
          </h1>
          <p className="text-sm font-bold uppercase tracking-wide text-black/50 mb-10">
            Share your event with the community
          </p>

          <form onSubmit={handleSubmit} className="border border-black/10 p-6 lg:p-8 space-y-6">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                Event Name
              </label>
              <input
                required
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                placeholder="Enter event name"
              />
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                Description
              </label>
              <textarea
                required
                value={form.description}
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent min-h-[150px] resize-y"
                placeholder="Describe your event"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                  Location
                </label>
                <input
                  required
                  value={form.location}
                  onChange={(e) => setForm((f) => ({ ...f, location: e.target.value }))}
                  className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                  placeholder="Event location"
                />
              </div>
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                  Date & Time
                </label>
                <input
                  required
                  type="datetime-local"
                  value={form.date}
                  onChange={(e) => setForm((f) => ({ ...f, date: e.target.value }))}
                  className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                  Price (EUR)
                </label>
                <input
                  type="number"
                  min={0}
                  step="0.01"
                  value={form.price ?? ''}
                  onChange={(e) => setForm((f) => ({ ...f, price: Number(e.target.value) }))}
                  className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                  placeholder="0.00"
                />
              </div>
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                  Capacity
                </label>
                <input
                  type="number"
                  min={0}
                  step="1"
                  value={form.capacity ?? ''}
                  onChange={(e) => setForm((f) => ({ ...f, capacity: Number(e.target.value) }))}
                  className="w-full border border-black/10 px-4 py-3 text-sm font-medium focus:outline-none focus:border-black transition-colors bg-transparent"
                  placeholder="Max attendees"
                />
              </div>
            </div>

            <div className="flex items-center gap-3">
              <input
                id="private"
                type="checkbox"
                checked={form.private}
                onChange={(e) => setForm((f) => ({ ...f, private: e.target.checked }))}
                className="w-5 h-5 border border-black/20 checked:bg-black"
              />
              <label htmlFor="private" className="text-sm font-bold uppercase tracking-wide">
                Private Event
              </label>
            </div>

            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-black/50 mb-2">
                Event Image
              </label>
              <div className="border border-black/10 p-4">
                <label className="flex items-center gap-3 cursor-pointer">
                  <Upload className="w-5 h-5 text-black/40" />
                  <span className="text-sm font-medium text-black/60">
                    {image ? image.name : 'Choose an image'}
                  </span>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => setImage(e.target.files?.[0])}
                    className="hidden"
                  />
                </label>
              </div>
            </div>

            {error && (
              <div className="text-sm font-bold border border-black/20 p-4">
                {error}
              </div>
            )}

            {success && (
              <div className="flex items-center gap-3 bg-black text-white p-4">
                <Check className="w-5 h-5" />
                <span className="text-sm font-bold uppercase tracking-wide">Event created successfully!</span>
              </div>
            )}

            <button
              type="submit"
              disabled={submitting}
              className="w-full bg-black text-white py-4 text-sm font-bold uppercase tracking-widest hover:bg-black/80 disabled:opacity-50 transition-colors"
            >
              {submitting ? 'Creating...' : 'Create Event'}
            </button>
          </form>
        </motion.div>
      </div>

      <Footer />
    </div>
  );
}
