"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import {
    onAuthStateChanged,
    User,
    signInWithEmailAndPassword,
    createUserWithEmailAndPassword,
    signOut as firebaseSignOut,
    updateProfile,
    OAuthProvider,
    signInWithPopup,
    sendEmailVerification
} from "firebase/auth";
import { auth } from "@/lib/firebase";

interface AuthContextType {
    user: User | null;
    profile: any; // Using any for simplicity for now, essentially UserProfile
    loading: boolean;
    signIn: (email: string, password: string) => Promise<void>;
    signUp: (email: string, password: string, displayName: string) => Promise<void>;
    signOut: () => Promise<void>;
    signInWithMicrosoft: () => Promise<void>;
    sendVerification: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
    user: null,
    profile: null,
    loading: true,
    signIn: async () => { },
    signUp: async () => { },
    signOut: async () => { },
    signInWithMicrosoft: async () => { },
    sendVerification: async () => { },
});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
    const [user, setUser] = useState<User | null>(null);
    const [profile, setProfile] = useState<any>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (user) => {
            setUser(user);
            if (user) {
                // Fetch User Profile
                // We use dynamic import to avoid circular dependency if needed, but here simple fetch is fine.
                // Assuming standard firestore usage
                try {
                    const { doc, getDoc } = await import("firebase/firestore");
                    const { db } = await import("@/lib/firebase");
                    const userDoc = await getDoc(doc(db, "users", user.uid));
                    if (userDoc.exists()) {
                        setProfile(userDoc.data());
                    } else {
                        setProfile(null);
                    }
                } catch (e) {
                    console.error("Failed to fetch profile", e);
                }
            } else {
                setProfile(null);
            }
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const signIn = async (email: string, password: string) => {
        await signInWithEmailAndPassword(auth, email, password);
    };

    const signUp = async (email: string, password: string, displayName: string) => {
        const userCredential = await createUserWithEmailAndPassword(auth, email, password);
        await updateProfile(userCredential.user, { displayName });
    };

    const signOut = async () => {
        await firebaseSignOut(auth);
    };

    const signInWithMicrosoft = async () => {
        const provider = new OAuthProvider('microsoft.com');
        provider.setCustomParameters({
            // Optional: Add tenant parameter if needed, e.g., tenant: 'YOUR_TENANT_ID'
            prompt: 'select_account'
        });
        await signInWithPopup(auth, provider);
    };

    const sendVerification = async () => {
        if (auth.currentUser) {
            await sendEmailVerification(auth.currentUser);
        }
    };

    return (
        <AuthContext.Provider value={{ user, profile, loading, signIn, signUp, signOut, signInWithMicrosoft, sendVerification }}>
            {children}
        </AuthContext.Provider>
    );
};
