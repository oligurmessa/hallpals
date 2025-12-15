"use client";

import { Menu, X } from "lucide-react";
import { Button } from "@/components/ui/button";

interface MobileMenuButtonProps {
  isOpen: boolean;
  onToggle: () => void;
}

export function MobileMenuButton({ isOpen, onToggle }: MobileMenuButtonProps) {
  return (
    <div className="flex items-center gap-2 lg:hidden">
      <Button
        aria-expanded={isOpen}
        aria-label="Toggle mobile menu"
        className="h-10 w-10"
        onClick={onToggle}
        size="icon"
        variant="ghost"
      >
        {isOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
      </Button>
    </div>
  );
}
