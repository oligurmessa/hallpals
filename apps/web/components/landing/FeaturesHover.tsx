import React from "react";
import { BarChart, Brain, Crosshair, FileText, Lock, History } from "lucide-react";
import { cn } from "@/lib/utils";

interface FeatureProps {
    title: string;
    description: string;
    icon: React.ReactNode;
    index: number;
}

export function FeaturesSectionWithHoverEffects() {
    const features = [
        {
            title: "Documenting Your Life",
            description: "Organize and preserve an authentic life archive with timelines, tags, and verified timestamps.",
            icon: <FileText className="w-8 h-8" />,
        },
        {
            title: "Security of Your Personal Data",
            description: "All AI processing runs through a private, access-controlled endpoint inside our cloud environment. Your data is isolated, encrypted, and never shared.",
            icon: <Lock className="w-8 h-8" />,
        },
        {
            title: "Relive & Re-Experience",
            description: "High-fidelity recall and immersive playback to re-experience meaningful moments—not just remember them.",
            icon: <History className="w-8 h-8" />,
        },
    ];

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 relative z-10 py-10 max-w-7xl mx-auto">
            {features.map((feature, index) => (
                <Feature key={feature.title} {...feature} index={index} />
            ))}
        </div>
    );
}

const Feature = ({
    title,
    description,
    icon,
    index,
}: FeatureProps) => {
    return (
        <div
            className={cn(
                "flex flex-col lg:border-r py-10 relative group/feature dark:border-neutral-800",
                // Add left border for the first item
                index === 0 && "lg:border-l dark:border-neutral-800",
                // Add bottom border for all items since it's a single row
                "lg:border-b dark:border-neutral-800",
                // Add top border for all items
                "lg:border-t"
            )}
        >
            {/* Top gradient on hover */}
            <div className="opacity-0 group-hover/feature:opacity-100 transition duration-200 absolute inset-0 h-full w-full bg-gradient-to-t from-neutral-100 dark:from-neutral-800 to-transparent pointer-events-none" />

            {/* Bottom gradient on hover */}
            <div className="opacity-0 group-hover/feature:opacity-100 transition duration-200 absolute inset-0 h-full w-full bg-gradient-to-b from-neutral-100 dark:from-neutral-800 to-transparent pointer-events-none" />

            <div className="mb-4 relative z-10 px-10 text-neutral-600 dark:text-neutral-400">
                {icon}
            </div>
            <div className="text-lg font-bold mb-2 relative z-10 px-10">
                <div className="absolute left-0 inset-y-0 h-6 group-hover/feature:h-8 w-1 rounded-tr-full rounded-br-full bg-neutral-300 dark:bg-neutral-700 group-hover/feature:bg-orange-500 transition-all duration-200 origin-center" />
                <span className="group-hover/feature:translate-x-2 transition duration-200 inline-block text-neutral-800 dark:text-neutral-100">
                    {title}
                </span>
            </div>
            <p className="text-sm text-neutral-600 dark:text-neutral-300 max-w-xs relative z-10 px-10">
                {description}
            </p>
        </div>
    );
};
