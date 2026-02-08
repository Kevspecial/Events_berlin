import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        <h1 className="heading-display text-[clamp(2.5rem,6vw,4.5rem)] mb-6">
          Terms of Service
        </h1>
        <p className="text-sm font-bold uppercase tracking-wide text-black/50 mb-12">
          Last updated: February 2026
        </p>

        <div className="max-w-2xl space-y-8">
          <section>
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Acceptance of Terms</h2>
            <p className="text-sm text-black/60 leading-relaxed">
              By accessing or using EventLab, you agree to be bound by these Terms of Service and all applicable laws and regulations.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">User Accounts</h2>
            <p className="text-sm text-black/60 leading-relaxed">
              You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Event Bookings</h2>
            <p className="text-sm text-black/60 leading-relaxed">
              All bookings are subject to availability. EventLab acts as a platform connecting event organizers with attendees.
            </p>
          </section>
        </div>
      </div>

      <Footer />
    </div>
  );
}
