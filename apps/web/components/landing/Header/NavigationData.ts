import type { LucideIcon } from "lucide-react";
import { Sparkles, Users } from "lucide-react";

export type NavigationItem = {
  name: string;
  href: string;
  icon?: LucideIcon;
};

export type NavigationCategory = {
  name: string;
  items: NavigationItem[];
};

export type NavigationMenu = {
  name: string;
  href?: string;
  items?: NavigationItem[];
  categories?: NavigationCategory[];
};

export const NAVIGATION_ITEMS: NavigationMenu[] = [
  {
    name: "Future of Human",
    categories: [
      {
        name: "Computer Brain",
        items: [
          { name: "Voice Synthesis", href: "/#features", icon: Users },
          { name: "Neuralink", href: "/#features", icon: Sparkles },
        ],
      },
      {
        name: "Human Enhancement",
        items: [
          { name: "Memory Augmentation", href: "/#features" },
          { name: "Memory Search", href: "/#features" },
        ],
      },
    ],
  },
  {
    name: "Company",
    categories: [
      {
        name: "About",
        items: [
          { name: "About Us", href: "/about" },
          { name: "Careers", href: "/careers" },
        ],
      },
      {
        name: "Content",
        items: [
          { name: "Blog", href: "/blog" },
          { name: "Contact", href: "/contact" },
        ],
      },
    ],
  },
  {
    name: "Pricing",
    href: "/#pricing",
  },
];
