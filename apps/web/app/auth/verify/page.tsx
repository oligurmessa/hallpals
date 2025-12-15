"use client";

import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useRouter } from "next/navigation";

export default function VerifyEmail() {
    const { user, sendVerification, signOut } = useAuth();
    const [sent, setSent] = useState(false);
    const [error, setError] = useState("");
    const router = useRouter();

    if (!user) {
        router.push("/auth/signin");
        return null;
    }

    const handleSend = async () => {
        setError("");
        try {
            await sendVerification();
            setSent(true);
        } catch (err: any) {
            setError(err.message);
        }
    };

    return (
        <div className="flex min-h-screen items-center justify-center bg-gray-50">
            <div className="w-full max-w-md p-8 bg-white rounded-lg shadow border text-center">
                <h2 className="text-2xl font-bold mb-4">Verify your email</h2>
                <p className="text-gray-600 mb-6">
                    We need to verify your email address <strong>{user.email}</strong> before you can continue.
                </p>

                {error && <div className="text-red-500 text-sm mb-4">{error}</div>}

                {sent ? (
                    <div className="bg-green-50 text-green-800 p-4 rounded mb-6">
                        Verification link sent! Please check your inbox (and spam folder) and click the link to verify.
                        <br />
                        <button
                            onClick={() => window.location.reload()}
                            className="mt-2 text-green-700 underline text-sm"
                        >
                            I have verified, refresh page
                        </button>
                    </div>
                ) : (
                    <button
                        onClick={handleSend}
                        className="w-full py-2 px-4 bg-indigo-600 text-white rounded hover:bg-indigo-700 transition"
                    >
                        Send Verification Email
                    </button>
                )}

                <div className="mt-6 border-t pt-4">
                    <button
                        onClick={() => signOut()}
                        className="text-sm text-gray-500 hover:text-gray-700 underline"
                    >
                        Sign Out
                    </button>
                </div>
            </div>
        </div>
    );
}
