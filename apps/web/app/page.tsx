import { Header } from "@/components/landing/Header";
import HeroSection from "@/components/landing/HeroSection";
import FeaturesSection from "@/components/landing/Feature";
import UseCasesSection from "@/components/landing/UseCasesSection";
import FAQSection from "@/components/landing/FAQSection";
import Footer from "@/components/landing/Footer";

import { FeaturesSectionWithHoverEffects } from "@/components/landing/FeaturesHover";

export default function Home() {
  return (
    <main className="min-h-screen">
      <Header />
      <HeroSection />
      <FeaturesSection />
      <UseCasesSection />
      <FeaturesSectionWithHoverEffects />
      <FAQSection />
      <Footer />
    </main >
  );
}

