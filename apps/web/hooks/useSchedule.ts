import { useState, useEffect } from "react";
import { collection, query, where, onSnapshot, doc, setDoc, deleteDoc, writeBatch, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface DutySchedule {
    id: string; // YYYY-MM-DD
    date: any; // Firestore Timestamp
    primaryRa: { id: string, name: string, email: string };
    secondaryRa?: { id: string, name: string, email: string };
    notes?: string;
    updatedAt?: any;
}

export function useSchedule(hallId: string | null) {
    const [schedule, setSchedule] = useState<DutySchedule[]>([]);
    const [loading, setLoading] = useState(true);

    // Fetch all for now (optimize to monthly later if needed)
    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(collection(db, "halls", hallId, "schedule"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            })) as DutySchedule[];
            // Sort by date string id (YYYY-MM-DD) which sorts chronologically
            data.sort((a, b) => a.id.localeCompare(b.id));
            setSchedule(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const addDuty = async (dateStr: string, primaryRa: any, secondaryRa?: any, notes?: string) => {
        if (!hallId) return;
        const ref = doc(db, "halls", hallId, "schedule", dateStr);
        await setDoc(ref, {
            date: Timestamp.fromDate(new Date(dateStr + "T12:00:00")), // Noon to avoid timezone edge cases
            primaryRa,
            secondaryRa: secondaryRa || null,
            notes: notes || "",
            updatedAt: new Date()
        });
    };

    const deleteDuty = async (dateStr: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "schedule", dateStr));
    };

    const importSchedule = async (items: any[]) => {
        if (!hallId) return;
        const batch = writeBatch(db);

        items.forEach(item => {
            const ref = doc(db, "halls", hallId, "schedule", item.id);
            batch.set(ref, {
                ...item,
                updatedAt: new Date()
            });
        });

        await batch.commit();
    };

    return { schedule, loading, addDuty, deleteDuty, importSchedule };
}
