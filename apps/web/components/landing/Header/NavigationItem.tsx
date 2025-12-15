"use client";

import { ChevronDown } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { NavigationMenu } from "./NavigationData";

type NavigationItemProps = {
  item: NavigationMenu;
};

export function NavigationItem({ item }: NavigationItemProps) {
  const [isOpen, setIsOpen] = useState(false);

  if (item.href) {
    return (
      <Link
        className="flex items-center gap-1 rounded-lg px-3 py-2 font-medium text-[15px] text-black/80 tracking-tighter transition-all duration-200 hover:bg-black/5 dark:text-white/80 dark:hover:bg-white/5"
        href={item.href}
      >
        {item.name}
      </Link>
    );
  }

  return (
    <DropdownMenu onOpenChange={setIsOpen} open={isOpen}>
      <DropdownMenuTrigger
        className="flex items-center gap-1 rounded-lg px-3 py-2 font-medium text-[15px] text-black/80 tracking-tighter outline-none transition-all duration-200 hover:bg-black/5 dark:text-white/80 dark:hover:bg-white/5"
        onMouseEnter={() => setIsOpen(true)}
        onMouseLeave={() => setIsOpen(false)}
      >
        {item.name}
        <ChevronDown
          className={`h-4 w-4 text-black/60 transition-transform duration-200 dark:text-white/60 ${isOpen ? "rotate-180" : ""}`}
        />
      </DropdownMenuTrigger>
      <DropdownMenuContent
        className="min-w-[200px] overflow-hidden rounded-xl border border-black/5 bg-neutral-50/80 p-1.5 shadow-lg backdrop-blur-md dark:border-white/5 dark:bg-black/80"
        onMouseEnter={() => setIsOpen(true)}
        onMouseLeave={() => setIsOpen(false)}
      >
        {item.categories
          ? item.categories.map((category, categoryIndex) => (
              <div key={category.name}>
                {categoryIndex > 0 && (
                  <DropdownMenuSeparator className="-mx-1 my-1 h-px bg-black/5 dark:bg-white/5" />
                )}
                <DropdownMenuLabel className="px-3 py-1.5 text-black/40 text-xs uppercase tracking-tighter dark:text-white/40">
                  {category.name}
                </DropdownMenuLabel>
                {category.items.map((subItem) => (
                  <DropdownMenuItem
                    asChild
                    className="group flex cursor-pointer items-center justify-between rounded-lg px-3 py-2.5 text-black/80 text-sm tracking-tight transition-all duration-200 hover:bg-black/5 focus:bg-black/5 dark:text-white/80 dark:focus:bg-white/5 dark:hover:bg-white/5"
                    key={subItem.name}
                  >
                    <Link href={subItem.href}>
                      <span>{subItem.name}</span>
                      {subItem.icon && (
                        <subItem.icon className="h-4 w-4 text-black/30 transition-colors group-hover:text-black/50 dark:text-white/30 dark:group-hover:text-white/50" />
                      )}
                    </Link>
                  </DropdownMenuItem>
                ))}
              </div>
            ))
          : item.items?.map((subItem) => (
              <DropdownMenuItem
                asChild
                className="group flex cursor-pointer items-center justify-between rounded-lg px-3 py-2.5 text-black/80 text-sm tracking-tight transition-all duration-200 hover:bg-black/5 focus:bg-black/5 dark:text-white/80 dark:focus:bg-white/5 dark:hover:bg-white/5"
                key={subItem.name}
              >
                <Link href={subItem.href}>
                  <span>{subItem.name}</span>
                  {subItem.icon && (
                    <subItem.icon className="h-4 w-4 text-black/30 transition-colors group-hover:text-black/50 dark:text-white/30 dark:group-hover:text-white/50" />
                  )}
                </Link>
              </DropdownMenuItem>
            ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
