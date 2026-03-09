import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        <h1 className="heading-display text-[clamp(2.5rem,6vw,4.5rem)] mb-6">
          Privacy Policy
        </h1>
        <p className="text-sm font-bold uppercase tracking-wide text-black/50 mb-12">
          Last updated: February 2026
        </p>

        <div className="max-w-2xl space-y-8">
          <section>
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Data Collection</h2>
            <p className="text-sm text-black/60 leading-relaxed">
              We collect only the information necessary to provide our services, including your name, email, and booking history.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Data Usage</h2>
            <p className="text-sm text-black/60 leading-relaxed">
              Your data is used solely for account management, booking confirmations, and service improvements. We never sell your data to third parties.
            </p>
          </section>

          <section>
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Your Rights</h2>
            <p className="text-sm text-black/60 leading-relaxed">
              You may request access to, correction of, or deletion of your personal data at any time by contacting us.
            </p>
          </section>
        </div>
      </div>

      <Footer />
    </div>
  );
}
