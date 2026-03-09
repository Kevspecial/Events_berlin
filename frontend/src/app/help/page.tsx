import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function HelpPage() {
  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        <h1 className="heading-display text-[clamp(2.5rem,6vw,4.5rem)] mb-6">
          Help Center
        </h1>
        <p className="text-sm font-bold uppercase tracking-wide text-black/50 mb-12">
          Find answers to common questions
        </p>

        <div className="space-y-6 max-w-2xl">
          <div className="border border-black/10 p-6">
            <h3 className="text-base font-black uppercase tracking-tight mb-3">How do I book an event?</h3>
            <p className="text-sm text-black/60">Browse events, select tickets, and complete your booking through our secure checkout.</p>
          </div>

          <div className="border border-black/10 p-6">
            <h3 className="text-base font-black uppercase tracking-tight mb-3">Can I cancel my booking?</h3>
            <p className="text-sm text-black/60">Yes, bookings can be cancelled up to 24 hours before the event start time.</p>
          </div>

          <div className="border border-black/10 p-6">
            <h3 className="text-base font-black uppercase tracking-tight mb-3">How do I create an event?</h3>
            <p className="text-sm text-black/60">Sign up as an organizer and use the Create Event page to list your event.</p>
          </div>
        </div>
      </div>

      <Footer />
    </div>
  );
}
