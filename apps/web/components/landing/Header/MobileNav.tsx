"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";

const MOBILE_LINKS = [
  { name: "Features", href: "#features" },
  { name: "How it Works", href: "#how-it-works" },
  { name: "Use Cases", href: "#use-cases" },

  { name: "FAQ", href: "#faq" },
];

type MobileNavProps = {
  onClose: () => void;
};

export function MobileNav({ onClose }: MobileNavProps) {
  const handleLinkClick = (id: string, e: React.MouseEvent) => {
    e.preventDefault();
    onClose();
    const element = document.querySelector(id);
    if (element) {
      element.scrollIntoView({ behavior: "smooth" });
    }
  };

  return (
    <div className="h-screen w-full bg-background/95 backdrop-blur-3xl border-t border-black/5 dark:border-white/10 px-4 pt-4 pb-24 flex flex-col">
      <nav className="flex flex-col gap-1">
        {MOBILE_LINKS.map((item) => (
          <a
            key={item.name}
            href={item.href}
            onClick={(e) => handleLinkClick(item.href, e)}
            className="w-full rounded-lg px-4 py-3 text-base font-medium text-muted-foreground hover:bg-accent hover:text-foreground transition-colors text-left"
          >
            {item.name}
          </a>
        ))}
      </nav>

      <div className="mt-8 px-4">
        <Button
          asChild
          className="w-full h-10 rounded-lg"
        >
          <Link href="/login" onClick={onClose}>
            Sign In
          </Link>
        </Button>
      </div>
    </div>
  );
}
