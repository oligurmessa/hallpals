import Link from "next/link";
import Image from "next/image";

export function Logo() {
  return (
    <div className="flex items-center">
      <Link aria-label="HallPals" className="flex items-center gap-0.5" href="/">
        <div className="relative h-9 w-9">
          <Image
            src="/light_logo.png"
            alt="HallPals Logo"
            fill
            className="object-contain dark:hidden"
          />
          <Image
            src="/dark_logo.png"
            alt="HallPals Logo"
            fill
            className="object-contain hidden dark:block"
          />
        </div>
        <span className="font-bold text-lg text-black tracking-tighter transition-colors dark:text-white">
          HallPals
        </span>
      </Link>
    </div>
  );
}
