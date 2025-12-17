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
    name: "Dashboard",
    href: "/dashboard",
  },
  {
    name: "Features",
    href: "/#features",
  },
  {
    name: "Use Cases",
    href: "/#use-cases",
  },
  {
    name: "Demo",
    href: "/demo",
  },
  {
    name: "Download",
    href: "/download",
  },
];
