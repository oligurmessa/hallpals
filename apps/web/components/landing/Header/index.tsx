"use client"

import { useState, useRef, useEffect } from "react"
import Link from "next/link"
import { Logo } from "@/components/landing/Header/Logo"
import { Button } from "@/components/ui/button"
import { MobileMenuButton } from "@/components/landing/Header/MobileMenuButton"
import { MobileNav } from "@/components/landing/Header/MobileNav"

const tabs = [
  { name: "Dashboard", href: "/dashboard" },
  { name: "Features", id: "features" },
  { name: "Use Cases", id: "use-cases" },
  { name: "FAQ", id: "faq" },
]

export function Header() {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null)
  const [activeIndex, setActiveIndex] = useState(0)
  const [hoverStyle, setHoverStyle] = useState({})
  const [activeStyle, setActiveStyle] = useState({ left: "0px", width: "0px" })
  const tabRefs = useRef<(HTMLAnchorElement | null)[]>([])
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)

  useEffect(() => {
    requestAnimationFrame(() => {
      const activeElement = tabRefs.current[activeIndex]
      if (activeElement) {
        setActiveStyle({
          left: `${activeElement.offsetLeft}px`,
          width: `${activeElement.offsetWidth}px`,
        })
      }
    })
  }, [activeIndex])

  useEffect(() => {
    if (hoveredIndex !== null) {
      const hoveredElement = tabRefs.current[hoveredIndex]
      if (hoveredElement) {
        setHoverStyle({
          left: `${hoveredElement.offsetLeft}px`,
          width: `${hoveredElement.offsetWidth}px`,
        })
      }
    }
  }, [hoveredIndex])

  const handleTabClick = (index: number, id: string) => {
    setActiveIndex(index)
    const element = document.getElementById(id)
    if (element) {
      element.scrollIntoView({ behavior: "smooth" })
    }
  }

  return (
    <>
      <header className={`fixed z-50 transition-all duration-300 ${
        // Mobile: Fixed top, full width
        "top-0 left-0 right-0 w-full"
        } ${
        // Desktop: Floating island top-6
        "md:top-6 md:w-auto md:pointer-events-none md:flex md:justify-center md:px-4"
        }`}>
        <div className={`
          pointer-events-auto flex items-center justify-between transition-all duration-300
          bg-white/80 dark:bg-black/80 backdrop-blur-xl border-black/5 dark:border-white/10
          ${
          // Mobile Styles: Full width, square corners (or slightly rounded bottom?), border-b, padding
          "w-full px-4 py-3 border-b md:border-b-0 md:active:border-none"
          }
          ${
          // Desktop Styles: Island (rounded-2xl), border, shadow, compact padding
          "md:w-auto md:rounded-lg md:border md:shadow-lg md:shadow-black/5 md:p-1 md:gap-3"
          }
        `}>

          {/* Logo Section */}
          <div className="md:pl-4 md:pr-1">
            <Logo />
          </div>

          {/* Divider (Desktop Only) */}
          <div className="hidden md:block h-6 w-px bg-black/5 dark:bg-white/10" />

          {/* Navigation Tabs (Desktop Only) */}
          <nav className="relative hidden md:flex items-center">
            {/* Hover Background */}
            <div
              className="absolute h-[34px] transition-all duration-300 ease-out bg-black/5 dark:bg-white/10 rounded-lg flex items-center"
              style={{
                ...hoverStyle,
                opacity: hoveredIndex !== null ? 1 : 0,
              }}
            />

            {/* Active Indicator */}
            <div
              className="absolute bottom-0 h-[2px] bg-black dark:bg-white transition-all duration-300 ease-out rounded-full"
              style={{
                ...activeStyle,
                bottom: "-6px",
                opacity: 0
              }}
            />

            {tabs.map((tab, index) => (
              <Link
                key={tab.name}
                ref={(el) => { tabRefs.current[index] = el as any }}
                className={`
                  relative px-4 py-1.5 cursor-pointer text-sm font-medium transition-colors duration-300 select-none
                  ${index === activeIndex ? "text-black dark:text-white" : "text-black/60 dark:text-white/60 hover:text-black/80 dark:hover:text-white/80"}
                `}
                onMouseEnter={() => setHoveredIndex(index)}
                onMouseLeave={() => setHoveredIndex(null)}
                onClick={(e) => {
                  if (tab.id) {
                    e.preventDefault()
                    handleTabClick(index, tab.id)
                  }
                }}
                href={tab.href || `#${tab.id}`}
              >
                {tab.name}
              </Link>
            ))}
          </nav>

          {/* Divider (Desktop Only) */}
          <div className="hidden md:block h-6 w-px bg-black/5 dark:bg-white/10" />

          {/* Action Buttons */}
          <div className="flex items-center gap-4">
            {/* Desktop Sign In */}
            <div className="hidden md:block pr-1.5 pl-1">
              <Button
                variant="default"
                size="sm"
                className="h-8 rounded-lg border border-black/5 bg-black/5 px-4 text-sm font-medium text-black/80 hover:bg-black/10 dark:border-white/10 dark:bg-white/5 dark:text-white/80 dark:hover:bg-white/10"
                asChild
              >
                <Link href="/auth/signin">Sign In</Link>
              </Button>
            </div>

            {/* Mobile Menu Toggle */}
            <div className="md:hidden">
              <MobileMenuButton
                isOpen={isMobileMenuOpen}
                onToggle={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              />
            </div>
          </div>
        </div>
      </header>

      {/* Mobile Menu Dropdown (Outside Header Flow) */}
      {isMobileMenuOpen && (
        <div className="fixed top-[60px] left-0 right-0 z-40 md:hidden">
          <MobileNav onClose={() => setIsMobileMenuOpen(false)} />
        </div>
      )}
    </>
  )
}
