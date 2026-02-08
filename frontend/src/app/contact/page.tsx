import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function ContactPage() {
  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        <h1 className="heading-display text-[clamp(2.5rem,6vw,4.5rem)] mb-6">
          Contact
        </h1>
        <p className="text-sm font-bold uppercase tracking-wide text-black/50 mb-12">
          Get in touch with our team
        </p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-12">
          <div className="border border-black/10 p-8">
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Email Us</h2>
            <p className="text-sm text-black/60 mb-2">For general inquiries:</p>
            <a href="mailto:hello@eventlab.berlin" className="text-base font-bold hover:underline">
              hello@eventlab.berlin
            </a>
          </div>

          <div className="border border-black/10 p-8">
            <h2 className="text-lg font-black uppercase tracking-tight mb-4">Visit Us</h2>
            <p className="text-sm text-black/60">
              EventLab HQ<br />
              Kreuzberg, Berlin<br />
              Germany
            </p>
          </div>
        </div>
      </div>

      <Footer />
    </div>
  );
}
