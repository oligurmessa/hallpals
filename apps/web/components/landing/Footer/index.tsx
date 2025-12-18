"use client";

import { ArrowRight, Instagram, Linkedin } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";


const footerLinks = [
  {
    title: "Product",
    links: [
      { name: "Features", href: "/#features" },
      { name: "Use Cases", href: "/#use-cases" },
      { name: "Request Demo", href: "/demo" },
      { name: "Download App", href: "/download" },
    ],
  },
  {
    title: "Company",
    links: [
      { name: "About", href: "/demo" },
      { name: "Privacy", href: "/privacy" },
      { name: "Terms", href: "/terms" },
      { name: "Contact", href: "/demo" },
    ],
  },
];

export default function Footer() {
  const currentYear = new Date().getFullYear();

  const handleEmailSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    // Form submission disabled - integrate with your email service when ready
  };

  return (
    <footer className="w-full overflow-hidden bg-white py-12 md:py-16 dark:bg-background">
      <div className="container mx-auto px-4 md:px-6">
        {/* Main Footer Content */}
        <div className="mx-auto max-w-7xl rounded-2xl border border-black/5 border-dashed p-2 dark:border-white/10">
          <div className="rounded-xl border border-black/5 bg-gray-100 p-6 md:p-8 dark:border-white/10 dark:bg-white/10">
            <div className="grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-4">
              {/* Brand Section */}
              <div className="space-y-3 lg:col-span-2">
                <Link
                  className="flex items-center gap-1.5 font-semibold text-2xl text-black/80 tracking-tighter transition-opacity hover:opacity-80 dark:text-white/80"
                  href="/"
                >
                  <div className="relative h-10 w-10">
                    <Image src="/light_logo.png" alt="HallPals Logo" fill className="object-contain dark:hidden" />
                    <Image src="/dark_logo.png" alt="HallPals Logo" fill className="object-contain hidden dark:block" />
                  </div>
                  <span className="font-bold text-2xl text-black tracking-tighter transition-colors dark:text-white translate-y-[2px]">
                    HallPals
                  </span>
                </Link>
                <div className="flex gap-4 pt-2">
                  <Link
                    className="text-black/40 transition-colors hover:text-black dark:text-white/40 dark:hover:text-white"
                    href="https://x.com"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <svg
                      className="h-4 w-4"
                      fill="currentColor"
                      role="img"
                      viewBox="0 0 24 24"
                      xmlns="http://www.w3.org/2000/svg"
                    >
                      <title>X</title>
                      <path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z" />
                    </svg>
                  </Link>
                  <Link
                    className="text-black/40 transition-colors hover:text-[#E4405F] dark:text-white/40 dark:hover:text-[#E4405F]"
                    href="https://instagram.com"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <Instagram className="h-4 w-4" />
                  </Link>
                  <Link
                    className="text-black/40 transition-colors hover:text-[#0077B5] dark:text-white/40 dark:hover:text-[#0077B5]"
                    href="https://linkedin.com"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <Linkedin className="h-4 w-4" />
                  </Link>
                </div>

              </div>


              {/* Links Sections */}
              {footerLinks.map((section) => (
                <div className="space-y-3" key={section.title}>
                  <h3 className="font-medium text-black/80 text-sm tracking-tighter dark:text-white/80">
                    {section.title}
                  </h3>
                  <ul className="space-y-2">
                    {section.links.map((link) => (
                      <li key={link.name}>
                        <Link
                          className="text-black/60 text-sm tracking-tighter transition-colors hover:text-black/80 dark:text-white/60 dark:hover:text-white/80"
                          href={link.href}
                        >
                          {link.name}
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>

            {/* Newsletter Section */}
            <div className="mt-8 border-black/5 border-t pt-6 dark:border-white/10">
              <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
                <div className="space-y-2">
                  <h3 className="font-medium text-black/80 text-sm tracking-tighter dark:text-white/80">
                    Join the HallPals Community
                  </h3>
                  <p className="text-black/60 text-xs tracking-tighter dark:text-white/60">
                    Stay updated with HallPals features and Residence Life operational tips.
                  </p>
                </div>
                <form className="space-y-2" onSubmit={handleEmailSubmit}>
                  <div className="flex gap-2">
                    <Input
                      autoComplete="off"
                      className="h-9 flex-1 rounded-lg border-black/10 bg-black/5 px-3 text-xs tracking-tighter placeholder:text-black/40 focus:border-black/20 focus:ring-1 focus:ring-black/20 dark:border-white/10 dark:bg-white/5 dark:focus:border-white/20 dark:focus:ring-white/20 dark:placeholder:text-white/40"
                      name="email"
                      placeholder="Enter your email"
                      required
                      type="email"
                    />
                    <Button
                      className="group h-9 w-9 rounded-lg border border-black/10 border-dashed bg-black/5 p-0 text-black/80 transition-all hover:bg-black/10 dark:border-white/10 dark:bg-white/5 dark:text-white/80 dark:hover:bg-white/10"
                      type="submit"
                    >
                      <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
                    </Button>
                  </div>
                  <p className="text-black/40 text-xs tracking-tighter dark:text-white/40">
                    Join thousands growing with AI insights.
                  </p>
                </form>
              </div>
            </div>

            {/* Bottom Bar */}
            <div className="mt-6 flex flex-col justify-between gap-3 border-black/5 border-t pt-6 text-black/50 text-xs tracking-tighter sm:flex-row sm:items-center dark:border-white/10 dark:text-white/50">
              <p>© {currentYear} HallPals.</p>
              <div className="flex gap-4">
                <Link
                  className="transition-colors hover:text-black/70 dark:hover:text-white/70"
                  href="#"
                >
                  Terms
                </Link>
                <Link
                  className="transition-colors hover:text-black/70 dark:hover:text-white/70"
                  href="#"
                >
                  Privacy
                </Link>
                <Link
                  className="transition-colors hover:text-black/70 dark:hover:text-white/70"
                  href="#"
                >
                  Cookies
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </footer >
  );
}
