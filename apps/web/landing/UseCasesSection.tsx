"use client";

import { Clock, ListFilter } from "lucide-react";
import { motion } from "framer-motion";
import Image from "next/image";
import { FeaturesSectionWithHoverEffects } from "./FeaturesHover";
import { OptimizedVideoPlayer } from "@/components/ui/OptimizedVideoPlayer";

type UseCase = {
  id: string;
  title: string;
  industry?: string;
  hideFeaturedLabel?: boolean;
  description: string;
  image: string;
  video?: string;
  featured?: boolean;
  largeFeatured?: boolean;
  category: string;
  duration: string;
};

const useCases: UseCase[] = [
  {
    id: "001",
    title: "Capture Moments",
    industry: "Logging",
    description:
      "Frictionless, multi-modal logging—text, audio, video, images—so memories are captured as life happens.",
    image: "/flower.png",
    video: "/1210.mov",
    featured: true,
    category: "Capture",
    duration: "Real-time",
  },
  {
    id: "004",
    title: "Safe Personal Intelligence",
    description:
      "Private AI analysis using open-source, highly capable models on protected infrastructure.",
    image: "/koko.png",
    video: "/1209.mov",
    featured: true,
    largeFeatured: true,
    hideFeaturedLabel: true,
    category: "Intelligence",
    duration: "Secure",
  },
  {
    id: "006",
    title: "Self-Assess & Self-Growth",
    description:
      "Guided reflections, assessments, and feedback loops that translate insight into measurable progress.",
    image: "/bg-glass.png",
    video: "/1207.mov",
    featured: true,
    largeFeatured: true,
    hideFeaturedLabel: true,
    category: "Evolution",
    duration: "Ongoing",
  },
];

export default function UseCasesSection() {
  // Separate content types
  const largeFeaturedItems = useCases.filter((item) => item.largeFeatured);
  const captureMoments = useCases.find((item) => item.id === "001");

  return (
    <>
      <section
        className="w-full overflow-hidden bg-white pt-12 pb-8 md:pt-16 md:pb-10 lg:pt-20 lg:pb-12 dark:bg-background"
        id="use-cases"
      >
        <div className="container mx-auto px-4 md:px-6">
          {/* Section Header */}
          <div className="mb-10 space-y-3 text-center">
            <div className="mx-auto flex w-fit items-center justify-center">
              <div className="flex items-center gap-3">
                <div className="h-px w-12 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
                <div className="flex items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 dark:border-white/10 dark:bg-white/5">
                  <span className="font-medium text-black/60 text-xs dark:text-white/60">
                    Capabilities
                  </span>
                </div>
                <div className="h-px w-12 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
              </div>
            </div>
            <h2 className="font-semibold text-3xl text-neutral-900 tracking-tight sm:text-4xl dark:text-neutral-50">
              Personal Intelligence Stack
            </h2>
            <p className="mx-auto max-w-[700px] text-neutral-500 text-sm dark:text-neutral-400">
              The AI app for your mind and memories, built to preserve your life experiences, protect your data, enhance your self-understanding, and turn reflection into growth.
            </p>
          </div>

          {/* New Hybrid Layout */}
          <div className="mx-auto max-w-7xl mb-16 space-y-12">

            {/* 1. Capture Moments - Featured Section Loop Wrapper (To maintain consistent styling if needed) or Just Render 001 */}
            {captureMoments && (
              <motion.div
                animate={{ opacity: 1, y: 0 }}
                className="group relative mx-auto w-full max-w-4xl rounded-2xl border border-black/5 border-dashed p-2 transition-all duration-300 hover:border-violet-400/30 dark:border-white/10"
                initial={{ opacity: 0, y: 20 }}
                transition={{ duration: 0.3 }}
              >
                {/* Featured Badge */}
                <div className="absolute top-4 right-4 z-20 rounded-full border border-violet-200 border-dashed bg-violet-50/90 px-2 py-0.5 backdrop-blur-sm dark:border-violet-800 dark:bg-violet-900/50">
                  <span className="font-medium text-[10px] text-violet-900 tracking-tighter dark:text-violet-100">
                    Core Feature
                  </span>
                </div>

                {/* Inner Card */}
                <div className="flex flex-col overflow-hidden rounded-xl border border-black/5 bg-gray-100 transition-all duration-300 dark:border-white/10 dark:bg-white/10">
                  <div className="relative aspect-video w-full overflow-hidden border-black/5 border-b p-2 dark:border-white/10">
                    <div className="relative h-full w-full overflow-hidden rounded-lg">
                      {captureMoments.video ? (
                        <OptimizedVideoPlayer src={captureMoments.video} />
                      ) : (
                        <Image
                          alt={captureMoments.title}
                          className="h-full w-full object-cover"
                          height={400}
                          src={captureMoments.image}
                          width={600}
                        />
                      )}

                      {captureMoments.industry && (
                        <div className="absolute top-2 left-2 z-20 rounded-lg border border-white/10 bg-black/60 px-2 py-1 backdrop-blur-sm">
                          <p className="font-medium text-[10px] text-white tracking-tighter">
                            {captureMoments.industry}
                          </p>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex flex-col justify-between p-4 md:p-6 text-center md:text-left">
                    <div className="flex flex-col md:flex-row items-center justify-between gap-4">
                      <div>
                        <h3 className="mb-2 font-semibold text-lg text-black/80 tracking-tighter dark:text-white/80">
                          {captureMoments.title}
                        </h3>
                        <p className="max-w-xl text-xs text-black/60 leading-relaxed tracking-tighter dark:text-white/60">
                          {captureMoments.description}
                        </p>
                      </div>

                      <div className="flex items-center gap-2">
                        <div className="flex items-center gap-1.5 rounded-lg border border-black/5 bg-white/50 px-2 py-1 dark:border-white/10 dark:bg-black/20">
                          <ListFilter className="h-3 w-3 text-black/60 dark:text-white/60" />
                          <span className="text-[10px] text-black/60 tracking-tighter dark:text-white/60">
                            {captureMoments.category}
                          </span>
                        </div>
                        <div className="flex items-center gap-1.5 rounded-lg border border-black/5 bg-white/50 px-2 py-1 dark:border-white/10 dark:bg-black/20">
                          <Clock className="h-3 w-3 text-black/60 dark:text-white/60" />
                          <span className="text-[10px] text-black/60 tracking-tighter dark:text-white/60">
                            {captureMoments.duration}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}

            {/* 2. Features Hover Section (Replaces the 3 small cards) */}
            <div className="pt-8 pb-8">
              <FeaturesSectionWithHoverEffects />
            </div>

          </div>

          {/* Large Video Sections */}
          <div className="flex flex-col gap-16 md:gap-24">
            {largeFeaturedItems.map((useCase, index) => (
              <div key={useCase.id} className="mx-auto w-full max-w-5xl">
                {/* Hero-style Video Container */}
                <div className="relative mx-auto aspect-video w-full overflow-hidden rounded-lg bg-black/5 dark:bg-white/5">
                  {useCase.video && <OptimizedVideoPlayer src={useCase.video} />}
                </div>

                {/* Text Content Below */}
                <div className="mt-6 flex flex-col items-center text-center">
                  <div className="flex items-center gap-2 mb-3">
                    <span className="rounded-full bg-violet-100 px-3 py-1 text-[10px] font-semibold text-violet-600 dark:bg-violet-900/30 dark:text-violet-300">
                      {useCase.title}
                    </span>
                  </div>
                  <h3 className="font-semibold text-2xl text-black/90 md:text-3xl dark:text-white/90 tracking-tight">
                    {useCase.description}
                  </h3>
                </div>
              </div>
            ))}
          </div>

          {/* Bottom CTA */}
          <div className="mx-auto mt-20 text-center">
            <p className="mb-3 text-black/60 text-xs tracking-tighter dark:text-white/60">
              Need custom integrations?{" "}
              <button
                className="font-medium text-black/80 underline underline-offset-2 transition-colors hover:text-black/70 dark:text-white/80 dark:hover:text-white/70"
                type="button"
              >
                Contact Support
              </button>
            </p>
          </div>
        </div>
      </section>
    </>
  );
}