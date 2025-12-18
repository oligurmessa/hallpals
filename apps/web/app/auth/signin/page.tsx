"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { Loader2 } from "lucide-react";

export default function SignInPage() {
    const router = useRouter();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const [formData, setFormData] = useState({
        email: "",
        password: "",
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        const { email, password } = formData;

        try {
            await signInWithEmailAndPassword(auth, email, password);
            router.push("/dashboard");
        } catch (err: any) {
            console.error("Login error:", err);
            // Common error codes mapping could be added here
            setError("Invalid email or password.");
        } finally {
            if (!error) setLoading(false);
        }
    };

    return (
        <div className="min-h-screen w-full flex items-center justify-center relative bg-zinc-950">
            <div className="relative z-10 w-full max-w-md p-6">
                <div className="bg-zinc-900/50 border border-white/5 rounded-2xl p-8 shadow-none">
                    <div className="text-center mb-8">
                        <h1 className="text-3xl font-bold text-white">
                            Welcome Back
                        </h1>
                        <p className="text-zinc-400 mt-2">Sign in to HallPals Dashboard</p>
                    </div>

                    <form onSubmit={handleSubmit} className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-zinc-300 mb-1.5">
                                Email Address
                            </label>
                            <input
                                type="email"
                                required
                                value={formData.email}
                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                className="w-full px-4 py-3 bg-zinc-900 border border-white/10 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-white transition-all"
                                placeholder="john@example.com"
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-zinc-300 mb-1.5">
                                Password
                            </label>
                            <input
                                type="password"
                                required
                                value={formData.password}
                                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                                className="w-full px-4 py-3 bg-zinc-900 border border-white/10 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-white transition-all"
                                placeholder="••••••••"
                            />
                        </div>

                        {error && (
                            <div className="p-3 bg-red-950/20 border border-red-500/20 rounded-lg text-red-500 text-sm">
                                {error}
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full py-4 bg-white rounded-lg text-black font-medium hover:bg-zinc-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                        >
                            {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : "Sign In"}
                        </button>
                    </form>

                    <p className="text-center mt-6 text-zinc-500 text-sm">
                        Don&apos;t have an account?{" "}
                        <Link href="/auth/signup" className="text-white hover:text-zinc-300 font-medium transition-colors">
                            Join with Code
                        </Link>
                    </p>
                </div>
            </div>
        </div>
    );
}
