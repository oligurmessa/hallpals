"use client";

import React, { useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import {
    LayoutDashboard,
    BookOpen,
    Building2,
    Calendar,
    ClipboardCheck,
    ListTodo,
    LogOut,
    ShieldAlert,
    Menu,
    X
} from "lucide-react";

const SIDEBAR_ITEMS = [
    { label: "Overview", href: "/dashboard", icon: LayoutDashboard },
    { label: "Handbook", href: "/dashboard/handbook", icon: BookOpen },
    { label: "Halls", href: "/dashboard/halls", icon: Building2 },
    { label: "Schedule", href: "/dashboard/roster", icon: Calendar },
    { label: "Rounds", href: "/dashboard/rounds", icon: ShieldAlert },
    { label: "Inspections", href: "/dashboard/inspections", icon: ClipboardCheck },
    { label: "Bulletin & Tasks", href: "/dashboard/tasks", icon: ListTodo },
];

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const { user, loading, signOut, profile } = useAuth();
    const router = useRouter();
    const pathname = usePathname();
    const [isMobileMenuOpen, setIsMobileMenuOpen] = React.useState(false);

    useEffect(() => {
        if (!loading) {
            if (!user) {
                router.push("/auth/signin");
            } else if (user) {
                // Wait for profile to load if it's not null (it might be null if fetch failed, but we handle that)
                // Actually auth context profile might be null initially even if user is there?
                // Let's rely on AuthContext's loading state generally, but we might want to check if profile is loaded or give it a moment? 
                // Since AuthContext sets profile AFTER user is set, we might have a race condition where user is set but profile is null.
                // However, AuthContext sets loading=false ONLY after onAuthStateChanged fires. 
                // But inside onAuthStateChanged, it awaits profile fetch BEFORE setting loading=false?
                // Let's double check AuthContext. 
                // Ah, in AuthContext `setLoading(false)` is at the end of the async callback. So `loading` covers profile fetch.
            }
        }
    }, [user, loading, router]);


    if (loading) {
        return (
            <div className="min-h-screen bg-zinc-950 flex items-center justify-center">
                <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
            </div>
        );
    }

    if (!user) return null;

    // ------------------------------------------------------------------
    // ACCESS CONTROL CHECK
    // ------------------------------------------------------------------
    // We access `profile` from useAuth(). To be safe, we cast it or check properties.
    // AuthContext now provides `profile`. 

    // If we have a user but no profile (yet?), or role is not staff/leadership
    // Note: If profile is failing to load for legitimate staff, they might get locked out.
    // But for now, strict check.
    const hasAccess = profile && (profile.role === 'staff' || profile.role === 'leadership');

    if (!hasAccess) {
        return (
            <div className="min-h-screen bg-zinc-950 flex flex-col items-center justify-center p-4 text-center">
                <div className="bg-red-500/10 p-4 rounded-full mb-4">
                    <ShieldAlert className="w-12 h-12 text-red-500" />
                </div>
                <h1 className="text-2xl font-bold text-white mb-2">Access Denied</h1>
                <p className="text-zinc-400 max-w-md mb-8">
                    This dashboard is restricted to Staff and Leadership members only.
                    If you believe this is an error, please contact your administrator.
                </p>
                <button
                    onClick={() => signOut()}
                    className="flex items-center gap-2 px-6 py-3 bg-zinc-900 border border-white/10 rounded-xl text-white hover:bg-zinc-800 transition-colors"
                >
                    <LogOut className="w-5 h-5" />
                    <span>Sign Out</span>
                </button>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-zinc-950 text-zinc-100 flex">
            {/* Sidebar for Desktop */}
            <aside className="hidden md:flex flex-col w-64 bg-zinc-900 border-r border-white/5 h-screen sticky top-0">
                <div className="p-6">
                    <h1 className="text-2xl font-bold bg-gradient-to-r from-purple-400 to-blue-400 bg-clip-text text-transparent">
                        HallPals
                    </h1>
                    <p className="text-xs text-zinc-500 mt-1">Staff Dashboard</p>
                </div>

                <nav className="flex-1 px-4 space-y-2 overflow-y-auto">
                    {SIDEBAR_ITEMS.map((item) => {
                        const Icon = item.icon;
                        const isActive = pathname === item.href;
                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${isActive
                                    ? "bg-purple-600/10 text-purple-400 active-shadow border border-purple-500/10"
                                    : "text-zinc-400 hover:bg-white/5 hover:text-zinc-200"
                                    }`}
                            >
                                <Icon className="w-5 h-5" />
                                <span className="font-medium text-sm">{item.label}</span>
                            </Link>
                        );
                    })}
                </nav>

                <div className="p-4 border-t border-white/5">
                    <div className="px-4 py-3 mb-2 rounded-xl bg-zinc-800/50 border border-white/5">
                        <p className="text-sm font-medium text-white truncate">{user.displayName || "Staff Member"}</p>
                        <p className="text-xs text-zinc-500 truncate">{user.email}</p>
                    </div>
                    <button
                        onClick={() => signOut()}
                        className="flex items-center gap-3 px-4 py-3 w-full rounded-xl text-zinc-400 hover:bg-red-500/10 hover:text-red-400 transition-all"
                    >
                        <LogOut className="w-5 h-5" />
                        <span className="font-medium text-sm">Sign Out</span>
                    </button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 flex flex-col min-w-0 bg-zinc-950">
                {/* Mobile Header */}
                <div className="md:hidden flex items-center justify-between p-4 bg-zinc-900 border-b border-white/5 sticky top-0 z-50">
                    <h1 className="text-xl font-bold bg-gradient-to-r from-purple-400 to-blue-400 bg-clip-text text-transparent">
                        HallPals
                    </h1>
                    <button
                        onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                        className="p-2 text-zinc-400 hover:bg-white/5 rounded-lg"
                    >
                        {isMobileMenuOpen ? <X /> : <Menu />}
                    </button>
                </div>

                {/* Mobile Menu */}
                {isMobileMenuOpen && (
                    <div className="md:hidden fixed inset-0 z-40 bg-zinc-950 pt-20 px-4 pb-6 space-y-2">
                        {SIDEBAR_ITEMS.map((item) => {
                            const Icon = item.icon;
                            const isActive = pathname === item.href;
                            return (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    onClick={() => setIsMobileMenuOpen(false)}
                                    className={`flex items-center gap-3 px-4 py-4 rounded-xl transition-all ${isActive
                                        ? "bg-purple-600/10 text-purple-400 border border-purple-500/10"
                                        : "text-zinc-400 hover:bg-white/5 hover:text-zinc-200"
                                        }`}
                                >
                                    <Icon className="w-5 h-5" />
                                    <span className="font-medium">{item.label}</span>
                                </Link>
                            );
                        })}
                        <button
                            onClick={() => { signOut(); setIsMobileMenuOpen(false); }}
                            className="flex items-center gap-3 px-4 py-4 w-full rounded-xl text-zinc-400 hover:bg-red-500/10 hover:text-red-400 transition-all mt-4 border-t border-white/5"
                        >
                            <LogOut className="w-5 h-5" />
                            <span className="font-medium">Sign Out</span>
                        </button>
                    </div>
                )}

                <div className="flex-1 overflow-y-auto p-4 md:p-8">
                    {children}
                </div>
            </main>
        </div>
    );
}
