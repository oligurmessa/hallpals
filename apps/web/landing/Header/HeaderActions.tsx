import ThemeToggle from "@/lib/theme-toggle";
import { CTAButtons } from "./CTAButtons";

export function HeaderActions() {
  return (
    <>
      <div className="mx-3 h-4 w-px bg-black/10 dark:bg-white/10" />
      <ThemeToggle />
      <CTAButtons />
    </>
  );
}
