"use client";

import { useEffect, useState } from "react";

const SCROLL_DELAY_MS = 100;

export function ScrollHandler({ children }: { children: React.ReactNode }) {
  const [isScrolled, setIsScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 10);
    };

    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    const hash = window.location.hash;

    if (!hash) {
      return;
    }

    const timeoutId = setTimeout(() => {
      const element = document.querySelector(hash);
      if (element) {
        element.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    }, SCROLL_DELAY_MS);

    return () => clearTimeout(timeoutId);
  }, []);

  return (
    <header
      className={`relative z-50 w-full tracking-tighter transition-all duration-300 ${
        isScrolled
          ? "border-black/5 border-b bg-neutral-50/80 backdrop-blur-md dark:border-white/5 dark:bg-black/80"
          : "bg-transparent"
      }`}
    >
      {children}
    </header>
  );
}
