import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, limit } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface RoundsSession {
    id: string;
    userId: string;
    raName?: string;
    raEmail?: string;
    startTime: any; // Firestore Timestamp
    endTime?: any; // Firestore Timestamp
    status: string;
    startingFloor: number;
    totalSteps: number;
    floorsVisited: number[];
    walkingTime: number; // seconds
    idleTime: number; // seconds
    isFullLoop: boolean;
    createdAt?: any;
}

export function useRounds(hallId: string | null) {
    const [sessions, setSessions] = useState<RoundsSession[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "rounds_sessions"),
            orderBy("startTime", "desc"),
            limit(50) // Limit to last 50 for performance
        );

        const unsubscribe = onSnapshot(
            q,
            (snapshot) => {
                const data = snapshot.docs.map((doc) => ({
                    id: doc.id,
                    ...doc.data(),
                })) as RoundsSession[];
                setSessions(data);
                setLoading(false);
                setError(null);
            },
            (err) => {
                setError(err.message);
                setLoading(false);
            }
        );

        return () => unsubscribe();
    }, [hallId]);

    return { sessions, loading, error };
}
