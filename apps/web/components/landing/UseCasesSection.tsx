"use client";

import { motion } from "framer-motion";
import Image from "next/image";

type ScreenshotFrame = {
  id: string;
  image: string;
  alt: string;
};

const frames: ScreenshotFrame[] = [
  {
    id: "ra",
    image: "/screenshots/ss1.png",
    alt: "RA Duty & Rounds Interface",
  },
  {
    id: "resident",
    image: "/screenshots/ss2.png",
    alt: "Resident Living Hub Interface",
  },
  {
    id: "reslife",
    image: "/screenshots/ss3.png",
    alt: "Residence Life Operations Interface",
  },
];

function ScreenshotFrameCard({ frame }: { frame: ScreenshotFrame }) {
  return (
    <motion.div
      animate={{ opacity: 1, y: 0 }}
      className="group relative w-full rounded-3xl border border-black/5 p-2 transition-all duration-300 hover:border-violet-400/30 dark:border-white/10"
      initial={{ opacity: 0, y: 16 }}
      transition={{ duration: 0.28 }}
    >
      {/* Inner Card */}
      <div className="overflow-hidden rounded-2xl border border-black/5 bg-gray-100 transition-all duration-300 dark:border-white/10 dark:bg-white/10">
        {/* Screenshot Image */}
        <div className="relative w-full overflow-hidden bg-white dark:bg-black">
          <div className="aspect-[1284/2778] w-full relative">
            <Image
              src={frame.image}
              alt={frame.alt}
              fill
              className="object-cover"
              sizes="(max-width: 768px) 100vw, 33vw"
            />
          </div>
        </div>
      </div>
    </motion.div>
  );
}

export default function UseCasesSection() {
  return (
    <section
      className="w-full overflow-hidden bg-white pt-12 dark:bg-background md:pt-16 lg:pt-20 pb-0"
      id="use-cases"
    >
      <div className="container mx-auto px-4 md:px-6">
        {/* Section Header (HallPals-specific) */}
        <div className="mb-10 space-y-3 text-center">
          <div className="mx-auto flex w-fit items-center justify-center">
            <div className="flex items-center gap-3">
              <div className="h-px w-12 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
              <div className="flex items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 dark:border-white/10 dark:bg-white/5">
                <span className="text-xs font-medium text-black/60 dark:text-white/60">
                  HallPals
                </span>
              </div>
              <div className="h-px w-12 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
            </div>
          </div>

          <h2 className="text-3xl font-semibold tracking-tight text-neutral-900 dark:text-neutral-50 sm:text-4xl">
            Built for RAs, Residents, and Residence Life
          </h2>

          <p className="mx-auto max-w-[760px] text-sm text-neutral-500 dark:text-neutral-400">
            A hall-first platform: clearer duty execution, better resident experience, and consistent
            Residence Life operations—all in one system.
          </p>
        </div>

        {/* Three 6.5" Screenshot Frames */}
        <div className="mx-auto mb-0 grid max-w-7xl grid-cols-1 gap-6 md:grid-cols-3">
          {frames.map((frame) => (
            <ScreenshotFrameCard key={frame.id} frame={frame} />
          ))}
        </div>
      </div>
    </section>
  );
}