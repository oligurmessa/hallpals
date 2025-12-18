"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createUserWithEmailAndPassword, updateProfile } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { auth, functions } from "@/lib/firebase";
import { Loader2 } from "lucide-react";

export default function SignUpPage() {
    const router = useRouter();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const [formData, setFormData] = useState({
        name: "",
        email: "",
        password: "",
        accessCode: "",
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        const { name, email, password, accessCode } = formData;

        if (!accessCode) {
            setError("Access code is required");
            setLoading(false);
            return;
        }

        try {
            // 1. Create Authentication User
            const userCredential = await createUserWithEmailAndPassword(auth, email, password);
            const user = userCredential.user;

            // 2. Update Profile Name
            await updateProfile(user, { displayName: name });

            // 3. Call Cloud Function to Join Hall / Assign Role
            const joinHallWithCode = httpsCallable(functions, "joinHallWithCode");
            await joinHallWithCode({ code: accessCode });

            // 4. Redirect
            router.push("/dashboard");
        } catch (err: any) {
            console.error("Signup error:", err);
            // Clean up if auth user was created but function failed? 
            // For now just show error.
            setError(err.message || "Failed to sign up");
        } finally {
            if (!error) setLoading(false); // Only unset loading if we didn't error (redirecting)
        }
    };

    return (
        <div className="min-h-screen w-full flex items-center justify-center relative bg-zinc-950">
            <div className="relative z-10 w-full max-w-md p-6">
                <div className="bg-zinc-900/50 border border-white/5 rounded-2xl p-8 shadow-none">
                    <div className="text-center mb-8">
                        <h1 className="text-3xl font-bold text-white">
                            Join HallPals
                        </h1>
                        <p className="text-zinc-400 mt-2">Create your staff account</p>
                    </div>

                    <form onSubmit={handleSubmit} className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-zinc-300 mb-1.5">
                                Full Name
                            </label>
                            <input
                                type="text"
                                required
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                className="w-full px-4 py-3 bg-zinc-900 border border-white/10 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-white transition-all"
                                placeholder="John Doe"
                            />
                        </div>

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

                        <div>
                            <label className="block text-sm font-medium text-zinc-300 mb-1.5">
                                Access Code
                            </label>
                            <input
                                type="text"
                                required
                                value={formData.accessCode}
                                onChange={(e) => setFormData({ ...formData, accessCode: e.target.value })}
                                className="w-full px-4 py-3 bg-zinc-900 border border-white/10 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-white transition-all uppercase tracking-widest"
                                placeholder="Access Code"
                            />
                            <p className="text-xs text-zinc-500 mt-1">Required for staff registration</p>
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
                            {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : "Create Account"}
                        </button>
                    </form>

                    <p className="text-center mt-6 text-zinc-500 text-sm">
                        Already have an account?{" "}
                        <Link href="/auth/signin" className="text-white hover:text-zinc-300 font-medium transition-colors">
                            Sign in
                        </Link>
                    </p>
                </div>
            </div>
        </div>
    );
}
