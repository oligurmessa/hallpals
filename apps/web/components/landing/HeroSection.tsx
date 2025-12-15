"use client";

import { Outfit } from "next/font/google";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { OptimizedVideoPlayer } from "@/components/ui/OptimizedVideoPlayer";

const titleFont = Outfit({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-title",
});

export default function HeroSection() {
  return (
    <>
      <section className="relative w-full overflow-hidden bg-white py-12 pt-32 md:py-20 md:pt-40 lg:py-24 lg:pt-48 dark:bg-background">
        <div className="container relative mx-auto px-4 md:px-6">
          {/* Hero Content */}
          <div className="flex flex-col items-center justify-center gap-6 text-center">
            <div className="flex max-w-6xl flex-col items-center justify-center space-y-4">
              <div className="flex w-fit items-center justify-center">
                <div className="flex items-center gap-3">
                  <div className="h-px w-16 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
                  <div className="group flex items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 transition-all duration-200 hover:border-black/10 hover:bg-black/5 dark:border-white/10 dark:bg-white/5 dark:hover:border-white/15 dark:hover:bg-white/8">
                    <span className="font-medium text-black/60 text-xs transition-colors group-hover:text-black/80 dark:text-white/60 dark:group-hover:text-white/80">
                      The future is now
                    </span>
                  </div>
                  <div className="h-px w-16 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
                </div>
              </div>

              <div className="space-y-2.5">
                <h1
                  className={cn(
                    "text-4xl font-semibold tracking-tight text-neutral-900 sm:text-5xl md:text-7xl lg:text-8xl dark:text-neutral-50",
                    titleFont.className
                  )}
                  style={{ lineHeight: 1.15 }}
                >
                  Personal memory.
                  <br />
                  Private intelligence.
                </h1>
                <p className="mx-auto max-w-[600px] text-neutral-500 text-sm leading-relaxed md:text-base dark:text-neutral-400">
                  Capture life moments and let AI provide meaningful insights
                  for your personal development.
                </p>
              </div>

              <div className="flex flex-col gap-2 pt-2 min-[400px]:flex-row">
                <Button
                  asChild
                  className="group h-9 w-fit rounded-lg bg-black px-3 font-medium text-white text-sm shadow-sm transition-all duration-200 hover:scale-[1.02] hover:bg-black/80 hover:shadow-md dark:bg-white dark:text-black dark:hover:bg-white/90"
                >
                  <Link href="/login">Start Journey</Link>
                </Button>
                <Button
                  asChild
                  className="h-9 w-fit rounded-lg border border-black/10 border-dashed bg-black/5 px-3 font-medium text-black/80 text-sm transition-all duration-200 hover:scale-[1.02] hover:border-black/20 hover:bg-black/10 dark:border-white/10 dark:bg-white/5 dark:text-white/80 dark:hover:bg-white/10"
                  variant="outline"
                >
                  <Link href="#features">Learn More</Link>
                </Button>
              </div>
            </div>
          </div>
        </div>

        {/* Large Featured Video */}
        <div className="container mx-auto px-4 pt-6 md:px-6 mt-12 md:mt-16">
          <div className="relative mx-auto aspect-video max-w-5xl overflow-hidden rounded-lg bg-black/5 dark:bg-white/5">
            <OptimizedVideoPlayer src="/1208.mov" />
          </div>
        </div>

        {/* Transition Element to Features Section */}
        <div className="container relative mx-auto mt-12 px-4 md:mt-16 md:px-6">
          <div className="mx-auto flex max-w-5xl items-center justify-center">
            <div className="flex items-center gap-3">
              <div className="h-px w-16 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
              <div className="group flex cursor-pointer items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 transition-all duration-200 hover:scale-105 hover:border-black/10 hover:bg-black/5 hover:shadow-sm dark:border-white/10 dark:bg-white/5 dark:hover:border-white/15 dark:hover:bg-white/8">
                <span className="font-medium text-black/60 text-xs transition-colors group-hover:text-black/80 dark:text-white/60 dark:group-hover:text-white/80">
                  Discover Capabilities
                </span>
              </div>
              <div className="h-px w-16 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
