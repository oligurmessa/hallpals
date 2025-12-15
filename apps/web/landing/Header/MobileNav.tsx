"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";

const MOBILE_LINKS = [
  { name: "Features", href: "#features" },
  { name: "How it Works", href: "#how-it-works" },
  { name: "Use Cases", href: "#use-cases" },
  { name: "Pricing", href: "#pricing" },
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
    <div className="h-screen w-full bg-background border-t border-white/10 px-4 pt-4 pb-24 flex flex-col">
      <nav className="flex flex-col gap-1">
        {MOBILE_LINKS.map((item) => (
          <a
            key={item.name}
            href={item.href}
            onClick={(e) => handleLinkClick(item.href, e)}
            className="w-full rounded-lg px-4 py-3 text-base font-medium text-white/70 hover:bg-white/5 hover:text-white transition-colors text-left"
          >
            {item.name}
          </a>
        ))}
      </nav>

      <div className="mt-8 px-4">
        <Button
          asChild
          className="w-full h-10 rounded-lg bg-white text-black font-medium hover:bg-white/90"
        >
          <Link href="/login" onClick={onClose}>
            Sign In
          </Link>
        </Button>
      </div>
    </div>
  );
}
