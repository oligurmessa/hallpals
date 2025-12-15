import Link from "next/link";
import { Button } from "@/components/ui/button";

export function CTAButtons() {
  return (
    <Button className="group h-9 w-fit rounded-lg bg-[#A8F1F7] px-3 font-medium text-neutral-900 text-sm shadow-sm transition-all duration-200 hover:scale-[1.02] hover:bg-[#A8F1F7]/80 hover:shadow-md dark:bg-[#A8F1F7] dark:text-neutral-900 dark:hover:bg-[#A8F1F7]/80">
      <Link href="/login">Get Started</Link>
    </Button>
  );
}
