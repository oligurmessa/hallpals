"use client";

import { ArrowUpRight } from "lucide-react";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";

const CAROUSEL_INTERVAL_MS = 3000;
const PERCENTAGE_MULTIPLIER = 100;

const services = [
  {
    title: "Personal Intelligence Engine",
    description:
      "Transforms your daily reflections into structured insights—revealing patterns in your emotions, habits, and decisions over time.",
  },
  {
    title: "Life Timeline & Memory Reconstruction",
    description:
      "Rebuild any season of your life with semantic search across text, audio, and video to see how you were truly changing, not just what was happening.",
  },
  {
    title: "Emotional & Productivity Patterns",
    description:
      "Connect mood, energy, and behavior to understand what drives your best days and what consistently derails focus and momentum.",
  },
];

const projects = [
  { title: "Inline Reflection" },
  { title: "Emotion Timeline" },
  { title: "Memory Graph" },
  { title: "Productivity Lens" },
  { title: "Relationship Insights" },
  { title: "Subconscious Trends" },
];

const styles = `
@keyframes scroll-right {
  0% {
    transform: translateX(-50%);
  }
  100% {
    transform: translateX(0);
  }
}

@keyframes scroll-left {
  0% {
    transform: translateX(0);
  }
  100% {
    transform: translateX(-50%);
  }
}

.animate-scroll-right {
  animation: scroll-right 25s linear infinite;
}

.animate-scroll-left {
  animation: scroll-left 25s linear infinite;
}


`;

export default function FeaturesSection() {
  const [currentIndex, setCurrentIndex] = useState(0);
  const carouselRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % services.length);
    }, CAROUSEL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (carouselRef.current) {
      carouselRef.current.style.transform = `translateX(-${currentIndex * (PERCENTAGE_MULTIPLIER / services.length)
        }%)`;
    }
  }, [currentIndex]);

  return (
    <>
      <style>{styles}</style>
      <section
        className="w-full overflow-hidden bg-white pt-12 pb-8 md:pt-16 md:pb-10 lg:pt-20 lg:pb-12 dark:bg-background"
        id="features"
      >
        <div className="container mx-auto px-4 md:px-6">
          <div className="mx-auto grid max-w-7xl grid-cols-1 gap-3 md:grid-cols-6 lg:gap-3">

            {/* Tall Feature Carousel - Spans 2 rows */}
            <div className="group relative min-h-[500px] rounded-2xl border border-black/5 border-dashed p-2 transition-all hover:border-blue-400/30 dark:border-white/10 md:col-span-2 md:row-span-2">
              <div className="flex h-full flex-col overflow-hidden rounded-xl border border-black/5 bg-gray-100 dark:border-white/10 dark:bg-white/10">
                <div className="relative flex h-full flex-col justify-center p-6">

                  <div className="absolute inset-0 z-10 flex scale-95 items-center justify-center opacity-0 transition-all duration-500 ease-out group-hover:scale-100 group-hover:opacity-100">
                    <div className="text-center">
                      <span className="font-semibold text-2xl text-black/80 tracking-tighter dark:text-white/80">
                        Core Features
                      </span>
                      <div className="mt-3 flex justify-center gap-2">
                        {services.map((_, idx) => (
                          <div
                            key={idx}
                            className={`h-1 rounded-full transition-all ${idx === currentIndex
                              ? "w-6 bg-blue-400"
                              : "w-1 bg-black/20 dark:bg-white/20"
                              }`}
                          />
                        ))}
                      </div>
                    </div>
                  </div>

                  <div className="relative h-full w-full overflow-hidden transition-all duration-500 group-hover:scale-95 group-hover:opacity-0 group-hover:blur-sm">
                    <div
                      className="flex h-full transition-transform duration-500 ease-in-out"
                      ref={carouselRef}
                      style={{
                        width: `${services.length * PERCENTAGE_MULTIPLIER}%`,
                      }}
                    >
                      {services.map((service, idx) => (
                        <div
                          className="flex h-full min-w-0 flex-col justify-center gap-3 px-2"
                          key={service.title}
                          style={{
                            width: `${PERCENTAGE_MULTIPLIER / services.length}%`,
                          }}
                        >
                          <div className="mb-2 flex h-10 w-10 items-center justify-center rounded-lg border border-black/5 bg-white/50 dark:border-white/10 dark:bg-black/20">
                            <span className="font-semibold text-lg text-black/60 tracking-tighter dark:text-white/60">
                              {idx + 1}
                            </span>
                          </div>
                          <h3 className="font-semibold text-lg text-black/80 tracking-tighter dark:text-white/80">
                            {service.title}
                          </h3>
                          <p className="text-[11px] text-black/60 leading-relaxed tracking-tighter dark:text-white/60">
                            {service.description}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Hero Image Card - Wide */}
            <div className="group relative min-h-[300px] rounded-2xl border border-black/5 border-dashed p-2 transition-all hover:border-blue-400/30 dark:border-white/10 md:col-span-4">
              <div className="flex h-full overflow-hidden rounded-xl border border-black/5 bg-gray-100 dark:border-white/10 dark:bg-white/10">
                <div className="relative flex h-full w-full flex-col overflow-hidden p-4">
                  <div className="absolute left-6 top-6 z-20 flex flex-col gap-2">
                    <div className="flex items-center gap-2">
                      <div className="h-1.5 w-1.5 rounded-full bg-blue-400" />
                      <span className="font-medium text-[10px] text-black/60 uppercase tracking-wider dark:text-white/60">
                        Secure System
                      </span>
                    </div>
                    <h3 className="max-w-md font-semibold text-2xl text-black/80 tracking-tighter dark:text-white/80 lg:text-3xl">
                      Private Memory,
                      <br />
                      Personal Intelligence
                    </h3>
                  </div>

                  <div className="relative mt-auto flex flex-1 items-end justify-end">
                    <div className="relative h-[250px] w-[250px] overflow-hidden rounded-2xl lg:h-[280px] lg:w-[280px]">
                      <Image
                        alt="SoulSpect concept"
                        className="h-full w-full object-cover transition-all duration-500 group-hover:scale-105 group-hover:brightness-110"
                        height={400}
                        src="/IMG_5606.jpeg"
                        width={400}
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Compact Stats/Info Card */}
            <div className="group relative min-h-[180px] rounded-2xl border border-black/5 border-dashed p-2 transition-all hover:border-blue-400/30 dark:border-white/10 md:col-span-2">
              <div className="flex h-full flex-col justify-between overflow-hidden rounded-xl border border-black/5 bg-gray-100 p-4 dark:border-white/10 dark:bg-white/10">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="font-medium text-[10px] text-black/40 uppercase tracking-widest dark:text-white/40">
                      Data Privacy
                    </p>
                    <p className="mt-1.5 font-semibold text-3xl text-black/80 tracking-tighter dark:text-white/80">
                      100%
                    </p>
                  </div>
                </div>
                <p className="text-[11px] text-black/60 leading-relaxed tracking-tighter dark:text-white/60">
                  Your personal intelligence is private, encrypted, and yours alone. We use only secure open weight models.
                </p>
              </div>
            </div>

            {/* Interactive Projects Showcase */}
            <button
              aria-label="See soulspect in Action"
              className="group relative min-h-[180px] rounded-2xl border border-black/5 border-dashed p-2 transition-all hover:border-blue-400/30 dark:border-white/10 md:col-span-2"
              type="button"
            >
              <div className="flex h-full overflow-hidden rounded-xl border border-black/5 bg-gray-100 dark:border-white/10 dark:bg-white/10">
                <div className="flex h-full w-full flex-1 items-center justify-center gap-2 opacity-100 transition-opacity duration-500 group-hover:opacity-0">
                  <span className="font-semibold text-base text-black/80 tracking-tighter dark:text-white/80">
                    Explore Features
                  </span>
                  <ArrowUpRight className="h-4 w-4 text-black/60 transition-transform duration-500 group-hover:-translate-y-1 group-hover:translate-x-1 dark:text-white/60" />
                </div>

                {/* Animated hover state */}
                <div className="pointer-events-none absolute inset-0 flex flex-col justify-center gap-2 p-4 opacity-0 transition-opacity duration-500 group-hover:opacity-100">
                  <div className="relative w-full flex-1 overflow-hidden rounded-lg">
                    <div className="flex h-full animate-scroll-right gap-2">
                      {[...projects, ...projects].map((project, index) => (
                        <div
                          className="flex aspect-square h-full shrink-0 items-center justify-center rounded-lg border border-black/5 bg-white/50 p-2 dark:border-white/10 dark:bg-black/20"
                          key={`row1-${project.title}-${index}`}
                        >
                          <span className="text-center font-medium text-[10px] text-black/70 tracking-tighter dark:text-white/70">
                            {project.title}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                  <div className="relative w-full flex-1 overflow-hidden rounded-lg">
                    <div className="flex h-full animate-scroll-left gap-2">
                      {[...projects, ...projects].map((project, index) => (
                        <div
                          className="flex aspect-square h-full shrink-0 items-center justify-center rounded-lg border border-black/5 bg-white/50 p-2 dark:border-white/10 dark:bg-black/20"
                          key={`row2-${project.title}-${index}`}
                        >
                          <span className="text-center font-medium text-[10px] text-black/70 tracking-tighter dark:text-white/70">
                            {project.title}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </button>

          </div>
        </div>
      </section>
    </>
  );
}