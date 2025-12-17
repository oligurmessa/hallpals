import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc, where } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface Resident {
    id: string; // This is the email (doc ID)
    firstName: string;
    lastName: string;
    email: string;
    roomNumber: string;
    floor: number;
    wing?: string;
    hallId: string;
    status: 'active' | 'inactive';
    createdAt?: any;
    updatedAt?: any;
}

export function useRoster(hallId: string | null) {
    const [residents, setResidents] = useState<Resident[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "roster"),
            where("role", "==", "resident")
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => {
                const d = doc.data();
                return {
                    id: doc.id,
                    ...d,
                    hallId,
                    // Ensure required fields exist
                    firstName: d.firstName || "",
                    lastName: d.lastName || "",
                    email: d.email || doc.id,
                    roomNumber: d.roomNumber || "",
                    floor: d.floor || 1,
                    status: d.status || 'active'
                };
            }) as Resident[];

            // Sort by room number locally since Firestore query checks equality on role first
            data.sort((a, b) => {
                // Try numeric sort for room numbers if possible
                const rA = parseInt(a.roomNumber) || 0;
                const rB = parseInt(b.roomNumber) || 0;
                if (rA !== rB) return rA - rB;
                return a.roomNumber.localeCompare(b.roomNumber);
            });

            setResidents(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const addResident = async (data: Omit<Resident, "id" | "hallId">) => {
        if (!hallId || !data.email) return;
        const emailLower = data.email.toLowerCase();
        const newRef = doc(db, "halls", hallId, "roster", emailLower);
        await setDoc(newRef, {
            ...data,
            role: 'resident',
            hallId,
            createdAt: new Date(),
            updatedAt: new Date()
        });
    };

    const updateResident = async (id: string, data: Partial<Resident>) => {
        if (!hallId) return;
        // id is email
        await updateDoc(doc(db, "halls", hallId, "roster", id), {
            ...data,
            updatedAt: new Date()
        });
    };

    const deleteResident = async (id: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "roster", id));
    }

    return { residents, loading, addResident, updateResident, deleteResident };
}
