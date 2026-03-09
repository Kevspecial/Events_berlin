import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import TextBlock from '@/components/TextBlock';

export default function AboutPage() {
  return (
    <div className="min-h-screen bg-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 lg:px-10 pt-24 pb-16">
        <h1 className="heading-display text-[clamp(2.5rem,6vw,4.5rem)] mb-6">
          About Us
        </h1>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 lg:gap-20 mt-12">
          <div>
            <h2 className="text-rotated heading-section text-3xl mb-6">Our Story</h2>
            <TextBlock
              content="Berlin_Events is Berlin's premier event discovery platform. We connect communities through curated cultural experiences, from art exhibitions to live performances."
              isUppercase
              isTight
              className="text-black/70 mb-6"
            />
            <TextBlock
              content="Founded in 2022, we believe in the power of shared experiences to bring people together and create lasting memories."
              isUppercase
              isTight
              className="text-black/40"
            />
          </div>

          <div className="border border-black/10 p-8">
            <h3 className="text-lg font-black uppercase tracking-tight mb-6">Our Mission</h3>
            <p className="text-sm text-black/60 leading-relaxed mb-4">
              To democratize event discovery and make cultural experiences accessible to everyone in Berlin.
            </p>
            <p className="text-sm text-black/60 leading-relaxed">
              We work with local venues, artists, and organizers to bring you the best events the city has to offer.
            </p>
          </div>
        </div>
      </div>

      <Footer />
    </div>
  );
}
