"use client"

import * as React from "react"
import { Moon, Sun } from "lucide-react"
import { useTheme } from "next-themes"

import { Button } from "@/components/ui/button"

export function ThemeToggle() {
    const { setTheme, theme } = useTheme()
    const [mounted, setMounted] = React.useState(false)

    React.useEffect(() => {
        setMounted(true)
    }, [])

    if (!mounted) {
        return (
            <Button
                variant="outline"
                size="icon"
                className="h-8 w-8 rounded-full border-black/10 bg-black/5 text-black/40 dark:border-white/10 dark:bg-white/5 dark:text-white/40"
            >
                <span className="h-4 w-4" />
                <span className="sr-only">Toggle theme</span>
            </Button>
        )
    }

    return (
        <Button
            variant="outline"
            size="sm"
            className="h-8 gap-2 rounded-full border-black/10 bg-black/5 px-3 text-xs font-medium text-black/60 hover:bg-black/10 hover:text-black dark:border-white/10 dark:bg-white/5 dark:text-white/60 dark:hover:bg-white/10 dark:hover:text-white transition-all"
            onClick={() => setTheme(theme === "light" ? "dark" : "light")}
        >
            <Sun className="h-3.5 w-3.5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
            <Moon className="absolute h-3.5 w-3.5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
            <span className="ml-5">Theme</span>
            <span className="sr-only">Toggle theme</span>
        </Button>
    )
}
