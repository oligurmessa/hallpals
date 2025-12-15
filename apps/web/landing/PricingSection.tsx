"use client";

import { Check } from "lucide-react";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";

const ANIMATION_DELAY_BASE = 0.1;
const ANIMATION_DELAY_INCREMENT = 0.05;
const ANIMATION_DURATION = 0.4;

const pricingPlans = [
  {
    name: "Personal",
    price: 0,
    period: "/month",
    description: "Essential tools for your daily mindfulness journey",
    features: [
      "Daily moment capture",
      "Basic AI patterns",
      "7-day memory retention",
      "Mood tracking",
      "Daily reflection prompts",
      "Standard support",
    ],
    highlighted: false,
    buttonText: "Start Journey",
    buttonActive: true,
  },
  {
    name: "Pro",
    price: 12,
    period: "/month",
    description: "Deep intelligence for accelerated personal growth",
    features: [
      "Unlimited moment capture",
      "Advanced AI analysis",
      "Unlimited memory search",
      "Voice & Audio journals",
      "Cognitive insights",
      "Pattern recognition",
      "Export capabilities",
      "Priority support",
    ],
    highlighted: true, // Keep highlighted logic for border/bg if desired, or set false for pure uniformity
    badge: "Most Popular",
    buttonText: "Coming Soon",
    buttonActive: false,
  },
  {
    name: "Pro Yearly",
    price: 99,
    period: "/year",
    description: "Commit to a full year of transformation",
    features: [
      "Unlimited moment capture",
      "Advanced AI analysis",
      "Unlimited memory search",
      "Voice & Audio journals",
      "Cognitive insights",
      "Pattern recognition",
      "Export capabilities",
      "Priority support",
      "2 months free",
    ],
    highlighted: false,
    badge: "Save 30%",
    buttonText: "Coming Soon",
    buttonActive: false,
  },
];

export default function PricingSection() {
  return (
    <section
      className="w-full overflow-hidden bg-white py-12 pb-12 md:pt-16 md:pb-16 lg:pt-20 lg:pb-20 dark:bg-background"
      id="pricing"
    >
      <div className="container mx-auto px-4 md:px-6">
        {/* Section Header */}
        <div className="mb-12 space-y-3 text-center">
          <div className="mx-auto flex w-fit items-center justify-center">
            <div className="flex items-center gap-3">
              <div className="h-px w-12 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
              <div className="flex items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 dark:border-white/10 dark:bg-white/5">
                <span className="font-medium text-black/60 text-xs dark:text-white/60">
                  Growth Plans
                </span>
              </div>
              <div className="h-px w-12 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
            </div>
          </div>
          <h2 className="font-semibold text-3xl text-neutral-900 tracking-tight sm:text-4xl dark:text-neutral-50">
            Choose your path
          </h2>
          <p className="mx-auto max-w-[500px] text-neutral-500 text-sm dark:text-neutral-400">
            Select the plan that best fits your journey. Start for free and upgrade as you grow.
          </p>
        </div>

        {/* Pricing Cards Grid */}
        <div className="mx-auto grid max-w-5xl grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {pricingPlans.map((plan, planIndex) => (
            <motion.div
              animate={{ opacity: 1, y: 0 }}
              className={`group relative rounded-2xl border border-dashed p-2 transition-all hover:border-neutral-300 ${plan.highlighted
                ? "border-blue-400/50 bg-blue-50/50 dark:border-blue-400/30 dark:bg-blue-500/10"
                : "border-black/5 bg-black/1 dark:border-white/10 dark:bg-white/3"
                }`}
              initial={{ opacity: 0, y: 20 }}
              key={plan.name}
              transition={{
                delay:
                  ANIMATION_DELAY_BASE + planIndex * ANIMATION_DELAY_INCREMENT,
                duration: ANIMATION_DURATION,
              }}
            >
              {/* Badge positioned absolute top-right */}
              {plan.badge && (
                <div className="absolute top-4 right-4 z-10">
                  <span className="inline-block rounded-full border border-blue-400 border-dashed bg-blue-100 px-2.5 py-0.5 font-medium text-blue-900 text-xs dark:border-blue-500 dark:bg-blue-500/20 dark:text-blue-200">
                    {plan.badge}
                  </span>
                </div>
              )}

              {/* Inner Card */}
              <div className="flex h-full flex-col rounded-xl border border-black/5 bg-gray-100 p-5 dark:border-white/10 dark:bg-white/10">
                {/* Plan Header */}
                <div className="mb-4 pr-8"> {/* Added padding right to prevent overlap with badge if text is long */}
                  <h3 className="mb-1.5 font-semibold text-black/80 text-xl tracking-tighter dark:text-white/80">
                    {plan.name}
                  </h3>
                  <p className="text-black/60 text-xs tracking-tighter dark:text-white/60">
                    {plan.description}
                  </p>
                </div>

                {/* Price */}
                <div className="mb-4">
                  <div className="flex items-end gap-1">
                    <span className="font-semibold text-4xl text-black/80 tracking-tighter dark:text-white/80">
                      ${plan.price}
                    </span>
                    <span className="mb-1 text-black/60 text-xs tracking-tighter dark:text-white/60">
                      {plan.period}
                    </span>
                  </div>
                </div>

                {/* CTA Button */}
                <Button
                  className={`mb-4 h-9 w-full rounded-lg font-medium text-xs tracking-tighter transition-all ${plan.highlighted
                    ? "border border-blue-400 border-dashed bg-blue-100 text-blue-900 hover:bg-blue-200 dark:bg-blue-500/20 dark:text-blue-200 dark:hover:bg-blue-500/30"
                    : "border border-black/5 border-dashed bg-black/5 text-black/80 hover:bg-black/10 dark:border-white/10 dark:bg-white/5 dark:text-white/80 dark:hover:bg-white/10"
                    }`}
                  disabled={!plan.buttonActive}
                >
                  {plan.buttonText}
                </Button>

                {/* Features List */}
                <div className="flex-1 space-y-2">
                  <p className="mb-3 font-medium text-black/80 text-xs tracking-tighter dark:text-white/80">
                    What's included:
                  </p>
                  {plan.features.map((feature) => (
                    <div className="flex items-start gap-2" key={feature}>
                      <div className="mt-0.5 flex h-3.5 w-3.5 shrink-0 items-center justify-center rounded-full bg-black/10 dark:bg-white/10">
                        <Check className="h-2 w-2 text-black/70 dark:text-white/70" />
                      </div>
                      <span className="text-black/60 text-xs leading-tight tracking-tighter dark:text-white/60">
                        {feature}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          ))}
        </div>

        {/* Bottom Info */}
        <div className="mx-auto mt-12 max-w-2xl text-center">
          <p className="text-black/60 text-xs tracking-tighter dark:text-white/60">
            Questions about our plans? <br className="hidden sm:block" />
            Check out our FAQ or{' '}
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
  );
}
