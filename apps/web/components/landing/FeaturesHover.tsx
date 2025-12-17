import React from "react";
import {
    ShieldCheck,
    Users,
    Building2,
    ClipboardList,
    Lock,
    Bell,
} from "lucide-react";
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
            title: "RA Duty & Rounds",
            description:
                "Run duty with clarity: on-duty status, rounds tracking, incident logging, and required workflows in one place.",
            icon: <ShieldCheck className="w-8 h-8" />,
        },
        {
            title: "Resident Living Hub",
            description:
                "A single home for residents to access chat, updates, resources, and requests without friction or confusion.",
            icon: <Users className="w-8 h-8" />,
        },
        {
            title: "Residence Life Operations",
            description:
                "Centralized coordination for staff: announcements, policies, and consistency across halls and shifts.",
            icon: <Building2 className="w-8 h-8" />,
        },
        {
            title: "Structured Reporting",
            description:
                "Standardized incident and noise reports with timestamps and context to reduce follow-ups and ambiguity.",
            icon: <ClipboardList className="w-8 h-8" />,
        },
        {
            title: "Role-Based Security",
            description:
                "Access is strictly controlled by role. RAs, residents, and staff only see what they are authorized to see.",
            icon: <Lock className="w-8 h-8" />,
        },
        {
            title: "Reliable Notifications",
            description:
                "Critical updates reach the right people at the right time without noise or missed messages.",
            icon: <Bell className="w-8 h-8" />,
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
                index === 0 && "lg:border-l dark:border-neutral-800",
                "lg:border-b dark:border-neutral-800",
                "lg:border-t"
            )}
        >
            {/* Hover gradients */}
            <div className="opacity-0 group-hover/feature:opacity-100 transition duration-200 absolute inset-0 h-full w-full bg-gradient-to-t from-violet-50 dark:from-violet-950/40 to-transparent pointer-events-none" />
            <div className="opacity-0 group-hover/feature:opacity-100 transition duration-200 absolute inset-0 h-full w-full bg-gradient-to-b from-violet-50 dark:from-violet-950/40 to-transparent pointer-events-none" />

            {/* Icon */}
            <div className="mb-4 relative z-10 px-10 text-neutral-500 dark:text-neutral-400">
                {icon}
            </div>

            {/* Title with accent bar */}
            <div className="text-lg font-semibold mb-2 relative z-10 px-10">
                <div className="absolute left-0 inset-y-0 h-6 group-hover/feature:h-8 w-1 rounded-tr-full rounded-br-full bg-violet-300 dark:bg-violet-700 group-hover/feature:bg-violet-500 transition-all duration-200 origin-center" />
                <span className="group-hover/feature:translate-x-2 transition duration-200 inline-block text-neutral-800 dark:text-neutral-100">
                    {title}
                </span>
            </div>

            {/* Description */}
            <p className="text-sm text-neutral-600 dark:text-neutral-300 max-w-xs relative z-10 px-10">
                {description}
            </p>
        </div>
    );
};
