"use client";

import { Minus, Plus } from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";
import { useState } from "react";

type Service = {
  id: string;
  title: string;
  description: string;
};

const services: Service[] = [
  {
    id: "001",
    title: "Is my personal data safe and private?",
    description:
      "Yes, absolutely. Your personal moments and data are protected with end-to-end encryption and stored securely. We never share, sell, or access your personal content. You maintain complete control and ownership of your data, and can export or delete it anytime. All AI processing happens in a secure, private environment.",
  },
  {
    id: "002",
    title: "How does the AI understand my personal experiences?",
    description:
      "Our AI uses advanced natural language processing and pattern recognition to understand context, emotions, and themes in your entries. It analyzes text, photos, voice notes, and emotional data to provide meaningful insights. The AI learns your unique patterns while keeping all analysis completely private and personalized to you.",
  },
  {
    id: "003",
    title: "Can I use soulspect on multiple devices?",
    description:
      "Yes! soulspect works seamlessly across all your devices - phone, tablet, and web. Your data syncs securely in real-time, so you can capture moments anywhere and access your insights from any device. All your progress and AI insights are always available wherever you are.",
  },
  {
    id: "004",
    title: "How quickly will I see insights and growth patterns?",
    description:
      "You'll start seeing basic insights within your first week of consistent use. As you capture more moments, the AI identifies deeper patterns and provides increasingly personalized recommendations. Most users report meaningful insights within 2-3 weeks, with significant pattern recognition emerging after a month of regular use.",
  },
  {
    id: "005",
    title: "What types of moments can I capture?",
    description:
      "soulspect supports all types of life experiences - daily reflections, emotional moments, achievements, challenges, relationships, work experiences, and personal growth milestones. You can log through text, voice notes, photos, and structured emotion tracking. The more diverse your captures, the richer your insights become.",
  },
  {
    id: "006",
    title: "How do I get started and what's included in the free plan?",
    description:
      "Getting started takes just 2 minutes! Create an account, add your first moment, and start receiving insights immediately. The free plan includes unlimited moment capture, basic AI insights, 7-day memory search, and access across all devices. You can upgrade anytime for advanced features like unlimited search and deeper analytics.",
  },
];

export default function FAQSection() {
  const [expandedService, setExpandedService] = useState<string>("001");

  return (
    <section
      className="w-full overflow-hidden bg-white pt-12 pb-24 md:pt-16 md:pb-32 lg:pt-20 lg:pb-40 dark:bg-background"
      id="faq"
    >
      <div className="container mx-auto px-4 md:px-6">
        {/* Section Header */}
        <div className="mb-12 space-y-3 text-center">
          <div className="mx-auto flex w-fit items-center justify-center">
            <div className="flex items-center gap-3">
              <div className="h-px w-12 bg-gradient-to-r from-transparent to-black/10 dark:to-white/10" />
              <div className="flex items-center gap-2 rounded-lg border border-black/5 bg-black/2 px-3 py-1.5 dark:border-white/10 dark:bg-white/5">
                <span className="font-medium text-black/60 text-xs dark:text-white/60">
                  FAQ
                </span>
              </div>
              <div className="h-px w-12 bg-gradient-to-l from-transparent to-black/10 dark:to-white/10" />
            </div>
          </div>
          <h2 className="font-semibold text-3xl text-neutral-900 tracking-tight sm:text-4xl dark:text-neutral-50">
            Frequently asked questions
          </h2>
          <p className="mx-auto max-w-[500px] text-neutral-500 text-sm dark:text-neutral-400">
            Can't find the answer you're looking for?{" "}
            <button
              className="font-medium text-black/80 underline underline-offset-2 transition-colors hover:text-black/70 dark:text-white/80 dark:hover:text-white/70"
              type="button"
            >
              Get in touch
            </button>
          </p>
        </div>

        {/* FAQ Items */}
        <div className="mx-auto max-w-4xl space-y-3">
          {services.map((service, index) => (
            <motion.div
              animate={{ opacity: 1, y: 0 }}
              className="group rounded-2xl border border-black/5 border-dashed p-2 transition-all hover:border-neutral-300 dark:border-white/10 dark:bg-white/3"
              initial={{ opacity: 0, y: 20 }}
              key={service.id}
              transition={{
                delay: 0.05 * index,
                duration: 0.3,
              }}
              viewport={{ once: true }}
            >
              {/* Inner Card */}
              <div className="overflow-hidden rounded-xl border border-black/5 bg-gray-100 dark:border-white/10 dark:bg-white/10">
                {/* Clickable Header */}
                <button
                  aria-expanded={expandedService === service.id}
                  aria-label={
                    expandedService === service.id ? "Show less" : "Show more"
                  }
                  className="relative flex w-full items-center justify-between gap-4 p-5 text-left transition-colors"
                  onClick={() =>
                    setExpandedService(
                      expandedService === service.id ? "" : service.id
                    )
                  }
                  type="button"
                >
                  <div className="flex flex-1 items-start gap-3">

                    <h3 className="flex-1 font-medium text-black/80 text-sm tracking-tighter sm:text-base dark:text-white/80">
                      {service.title}
                    </h3>
                  </div>
                  <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-black/5 transition-colors group-hover:bg-black/10 dark:bg-white/5 dark:group-hover:bg-white/10">
                    {expandedService === service.id ? (
                      <Minus className="h-3.5 w-3.5 text-black/60 dark:text-white/60" />
                    ) : (
                      <Plus className="h-3.5 w-3.5 text-black/60 dark:text-white/60" />
                    )}
                  </div>
                </button>

                {/* Expanded Content */}
                <AnimatePresence>
                  {expandedService === service.id && (
                    <motion.div
                      animate={{ height: "auto", opacity: 1 }}
                      className="overflow-hidden"
                      exit={{ height: 0, opacity: 0 }}
                      initial={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3, ease: "easeInOut" }}
                    >
                      <div className="border-black/5 border-t px-5 pt-3 pb-5 dark:border-white/10">
                        <motion.p
                          animate={{ opacity: 1 }}
                          className="text-black/60 text-sm leading-relaxed tracking-tighter dark:text-white/60"
                          initial={{ opacity: 0 }}
                          transition={{ delay: 0.1 }}
                        >
                          {service.description}
                        </motion.p>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
