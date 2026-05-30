import { Nav } from "@/components/nav";
import { Hero } from "@/components/hero";
import { Marquee } from "@/components/marquee";
import { Features } from "@/components/features";
import { HowItWorks } from "@/components/how-it-works";
import { DayTimeline } from "@/components/day-timeline";
import { Pricing } from "@/components/pricing";
import { ApiSection } from "@/components/api-section";
import { Cta } from "@/components/cta";
import { Footer } from "@/components/footer";
import { RevealOnScroll } from "@/components/reveal-on-scroll";

export default function Home() {
  return (
    <>
      <RevealOnScroll />
      <Nav />
      <Hero />
      <Marquee />
      <Features />
      <HowItWorks />
      <DayTimeline />
      <Pricing />
      <div className="mx-auto w-[min(1200px,100%-48px)]">
        <ApiSection />
      </div>
      <section className="mx-auto w-[min(1200px,100%-48px)]">
        <Cta />
        <Footer />
      </section>
    </>
  );
}
