import { useState, useEffect } from "react";
import { collection, query, onSnapshot, where } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface HallStaff {
    id: string; // This will be the email (doc ID) for roster entries
    firstName?: string;
    lastName?: string;
    email: string;
    role: 'ra' | 'staff' | 'admin';
    floor?: number;
    wing?: string;
    createdAt?: any;
    uid?: string; // If they have joined, maybe we store uid here? Or we need to join with profiles?
    // For now, roster entry is the source of truth for "Assignment".
}

export function useHallStaff(hallId: string | null) {
    const [staff, setStaff] = useState<HallStaff[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        // Read from the "roster" collection (the whitelist)
        const q = query(
            collection(db, "halls", hallId, "roster"),
            where("role", "in", ["ra", "staff", "admin"])
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => {
                const d = doc.data();
                return {
                    id: doc.id,
                    email: d.email || doc.id, // Doc ID is emailLower
                    role: d.role,
                    firstName: d.firstName,
                    lastName: d.lastName,
                    floor: d.floor,
                    wing: d.wing,
                    roomNumber: d.roomNumber
                };
            }) as HallStaff[];
            setStaff(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    return { staff, loading };
}
