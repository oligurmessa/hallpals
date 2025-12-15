"use client";

import { ArrowRight, CheckCircle2 } from "lucide-react";
import { motion } from "framer-motion";
import Image from "next/image";
import { useState } from "react";

type Step = {
  id: string;
  number: string;
  title: string;
  description: string;
  image: string;
  features: string[];
  stats: { label: string; value: string };
};

const steps: Step[] = [
  {
    id: "001",
    number: "01",
    title: "Capture Moments",
    description:
      "Start by capturing life experiences through text, photos, voice notes, and emotion tracking.",
    image: "/1212.gif",
    features: [
      "Text journaling",
      "Photo attachments",
      "Voice recordings",
    ],
    stats: { label: "Setup time", value: "<2min" },
  },
  {
    id: "002",
    number: "02",
    title: "AI Analysis",
    description:
      "Our AI processes your content to identify patterns, themes, and meaningful connections across your experiences.",
    image: "/1213.gif",
    features: ["Pattern recognition", "Emotion analysis", "Context understanding"],
    stats: { label: "Insights", value: "Real-time" },
  },
  {
    id: "003",
    number: "03",
    title: "Track Growth",
    description:
      "Receive personalized insights and track your personal development journey with AI-powered recommendations.",
    image: "/13D88BFC-BACA-4969-BF49-000F90072A32.gif",
    features: ["Growth analytics", "Personal insights", "Goal tracking"],
    stats: { label: "Progress", value: "Daily" },
  },
];

// Diagonal stripes pattern
const styles = `
  .diagonal-stripes {
    background-image: repeating-linear-gradient(
      45deg,
      rgba(0, 0, 0, 0.02),
      rgba(0, 0, 0, 0.02) 10px,
      rgba(0, 0, 0, 0.04) 10px,
      rgba(0, 0, 0, 0.04) 20px
    );
  }

  .dark .diagonal-stripes {
    background-image: repeating-linear-gradient(
      45deg,
      rgba(255, 255, 255, 0.02),
      rgba(255, 255, 255, 0.02) 10px,
      rgba(255, 255, 255, 0.05) 10px,
      rgba(255, 255, 255, 0.05) 20px
    );
  }
`;

export default function HowItWorksSection() {
  const [hoveredStep, setHoveredStep] = useState<string | null>(null);

  return (
    <>
      <style>{styles}</style>
      <section className="w-full overflow-hidden bg-white pt-12 pb-8 md:pt-16 md:pb-10 lg:pt-20 lg:pb-12 dark:bg-background" id="how-it-works">
        <div className="container mx-auto px-4 md:px-6">
          {/* Section Header */}
          <div className="mb-10 space-y-3 text-center">
            <div className="mx-auto flex w-fit items-center justify-center">
              <div className="flex items-center gap-3">
                <div className="h-px w-12 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
                <div className="flex items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 dark:border-white/10 dark:bg-white/5">
                  <span className="font-medium text-black/60 text-xs dark:text-white/60">
                    How it works
                  </span>
                </div>
                <div className="h-px w-12 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
              </div>
            </div>
            <h2 className="font-semibold text-3xl text-neutral-900 tracking-tight sm:text-4xl dark:text-neutral-50">
              Transform your growth
            </h2>
            <p className="mx-auto max-w-[500px] text-neutral-500 text-sm dark:text-neutral-400">
              Three simple steps to unlock AI-powered personal development
            </p>
          </div>

          {/* Bento Grid Layout */}
          <div className="mx-auto max-w-4xl">
            <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
              {steps.map((step, index) => {
                const isHovered = hoveredStep === step.id;

                return (
                  <motion.div
                    animate={{ opacity: 1, y: 0 }}
                    className="group relative rounded-2xl border border-black/5 border-dashed p-2 transition-all hover:border-blue-400/30 dark:border-white/10"
                    initial={{ opacity: 0, y: 20 }}
                    key={step.id}
                    onMouseEnter={() => setHoveredStep(step.id)}
                    onMouseLeave={() => setHoveredStep(null)}
                    transition={{
                      delay: 0.05 + index * 0.05,
                      duration: 0.3,
                    }}
                  >
                    {/* Connection Line */}
                    {index < steps.length - 1 && (
                      <div className="-right-[13px] -translate-y-1/2 absolute top-1/2 z-10 hidden lg:block">
                        <div className="flex items-center gap-1">
                          <div
                            className={`h-px w-6 transition-all duration-300 ${isHovered
                              ? "bg-blue-400/50"
                              : "bg-black/10 dark:bg-white/10"
                              }`}
                          />
                          <ArrowRight
                            className={`h-3 w-3 transition-all duration-300 ${isHovered
                              ? "translate-x-0.5 text-blue-400"
                              : "text-black/20 dark:text-white/20"
                              }`}
                          />
                        </div>
                      </div>
                    )}

                    {/* Inner Card */}
                    <div className="flex h-full flex-col overflow-hidden rounded-xl border border-black/5 bg-gray-100 dark:border-white/10 dark:bg-white/10">
                      {/* Image Section with Overlay */}
                      <div className="diagonal-stripes relative aspect-video overflow-hidden border-black/5 border-b p-2 dark:border-white/10">
                        <div className="relative h-full w-full overflow-hidden rounded-lg">
                          <Image
                            alt={step.title}
                            className="h-full w-full object-cover transition-all duration-500 group-hover:scale-105 group-hover:brightness-110"
                            height={300}
                            src={step.image}
                            width={400}
                            unoptimized
                          />
                          {/* Gradient Overlay */}
                          <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100" />

                          {/* Floating Stat Badge */}
                          <motion.div
                            animate={{
                              opacity: isHovered ? 1 : 0,
                              y: isHovered ? 0 : 10,
                            }}
                            className="absolute top-2 right-2 rounded-lg border border-blue-400/20 bg-blue-400/90 px-2 py-1 backdrop-blur-sm"
                            transition={{ duration: 0.2 }}
                          >
                            <p className="text-[10px] text-black/60 tracking-tighter">
                              {step.stats.label}
                            </p>
                            <p className="font-semibold text-black text-xs tracking-tighter">
                              {step.stats.value}
                            </p>
                          </motion.div>
                        </div>
                      </div>

                      {/* Content Section */}
                      <div className="flex flex-1 flex-col p-4">
                        {/* Step Number & Icon Row */}
                        <div className="mb-3 flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-[10px] text-black/40 tracking-tighter dark:text-white/40">
                              {step.number}
                            </span>
                            <div className="h-px w-4 bg-blue-400/30" />
                          </div>
                        </div>

                        {/* Title */}
                        <h3 className="mb-1.5 font-semibold text-base text-black/80 tracking-tighter dark:text-white/80">
                          {step.title}
                        </h3>

                        {/* Description */}
                        <p className="mb-3 text-[11px] text-black/60 leading-relaxed tracking-tighter dark:text-white/60">
                          {step.description}
                        </p>

                        {/* Features List */}
                        <div className="mt-auto space-y-1.5">
                          {step.features.map((feature, idx) => (
                            <motion.div
                              animate={{
                                opacity: isHovered ? 1 : 0.7,
                                x: isHovered ? 0 : -2,
                              }}
                              className="flex items-center gap-1.5"
                              key={`${step.id}-feature-${idx}`}
                              transition={{ delay: idx * 0.05 }}
                            >
                              <CheckCircle2 className="h-2.5 w-2.5 shrink-0 text-blue-400" />
                              <span className="text-[10px] text-black/60 tracking-tighter dark:text-white/60">
                                {feature}
                              </span>
                            </motion.div>
                          ))}
                        </div>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>

            {/* Progress Indicator */}
            <div className="mt-6 flex items-center justify-center gap-2">
              {steps.map((step, index) => (
                <div
                  className="flex items-center gap-2"
                  key={`progress-${step.id}`}
                >
                  <div
                    className={`h-1.5 rounded-full transition-all duration-300 ${hoveredStep === step.id
                      ? "w-8 bg-blue-400"
                      : "w-1.5 bg-black/10 dark:bg-white/10"
                      }`}
                  />
                  {index < steps.length - 1 && (
                    <div className="h-px w-4 bg-black/5 dark:bg-white/5" />
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Bottom CTA */}
          <div className="mx-auto mt-10 text-center">
            <button
              className="group inline-flex items-center gap-2 rounded-lg border border-blue-400 border-dashed bg-blue-400/10 px-4 py-2 transition-all hover:scale-[1.02] hover:bg-blue-400/20"
              type="button"
            >
              <span className="font-medium text-black/80 text-sm tracking-tighter dark:text-white/80">
                Ready to grow?
              </span>
              <ArrowRight className="h-3.5 w-3.5 text-blue-400 transition-transform group-hover:translate-x-0.5" />
            </button>
          </div>
        </div>
      </section>
    </>
  );
}
