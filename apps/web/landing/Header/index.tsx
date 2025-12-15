"use client";

import { useState } from "react";
import { DesktopNavigation } from "./DesktopNavigation";
import { HeaderActions } from "./HeaderActions";
import { Logo } from "./Logo";
import { MobileMenuButton } from "./MobileMenuButton";
import { MobileNav } from "./MobileNav";
import { ScrollHandler } from "./ScrollHandler";

export function Header() {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const handleToggleMenu = () => {
    setIsMobileMenuOpen(!isMobileMenuOpen);
  };

  const handleCloseMobileMenu = () => {
    setIsMobileMenuOpen(false);
  };

  return (
    <div className="fixed top-0 right-0 left-0 z-50 w-full">
      <ScrollHandler>
        <div className="relative mx-auto max-w-7xl px-6">
          <div className="flex h-16 items-center justify-between gap-8">
            {/* Left section: Logo */}
            <Logo />

            {/* Right section: Desktop Navigation with Dropdowns */}
            <div className="hidden items-center gap-1 lg:flex">
              <DesktopNavigation />
              <HeaderActions />
            </div>

            {/* Mobile Menu Button */}
            <MobileMenuButton
              isOpen={isMobileMenuOpen}
              onToggle={handleToggleMenu}
            />
          </div>

          {/* Mobile Menu */}
          {isMobileMenuOpen && <MobileNav onClose={handleCloseMobileMenu} />}
        </div>
      </ScrollHandler>
    </div>
  );
}
