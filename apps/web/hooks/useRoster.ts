import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc, writeBatch } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface Resident {
    id: string;
    firstName: string;
    lastName: string;
    email: string; // For searching
    roomNumber: string;
    floor: number;
    wing?: string; // Optional wing assignment
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

        const q = query(collection(db, "halls", hallId, "residents"), orderBy("roomNumber"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as Resident[];
            setResidents(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const addResident = async (data: Omit<Resident, "id" | "hallId">) => {
        if (!hallId) return;
        const newRef = doc(collection(db, "halls", hallId, "residents"));
        await setDoc(newRef, {
            ...data,
            hallId,
            createdAt: new Date(),
            updatedAt: new Date()
        });
    };

    const updateResident = async (id: string, data: Partial<Resident>) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "residents", id), {
            ...data,
            updatedAt: new Date()
        });
    };

    const deleteResident = async (id: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "residents", id));
    }

    const addResidentsBulk = async (residentsData: Omit<Resident, "id" | "hallId">[]) => {
        if (!hallId) return;

        // Firestore batch limit is 500. We'll handle chunks of 450 to be safe.
        const chunkSize = 450;

        for (let i = 0; i < residentsData.length; i += chunkSize) {
            const chunk = residentsData.slice(i, i + chunkSize);
            const batch = writeBatch(db);

            chunk.forEach(data => {
                const ref = doc(collection(db, "halls", hallId, "residents"));
                batch.set(ref, {
                    ...data,
                    hallId,
                    wing: data.wing || null,
                    createdAt: new Date()
                });
            });
            await batch.commit();
        }
    };

    const deleteAllResidents = async () => {
        if (!hallId) return;
        // Client-side delete all: Query all docs, then batch delete.
        // Warning: Reads all docs.
        const q = query(collection(db, "halls", hallId, "residents"));
        // snapshot is already live in state, but let's query fresh to just get IDs or use state?
        // Using state 'residents' is cheaper but we need to trust it's synced.
        // Safer to use the snapshot from the hook's state if we trust it, or fetch fresh.
        // Let's iterate over `residents` state since we have it.

        const { writeBatch } = await import("firebase/firestore");
        const chunkSize = 450;
        const chunks = [];

        for (let i = 0; i < residents.length; i += chunkSize) {
            chunks.push(residents.slice(i, i + chunkSize));
        }

        for (const chunk of chunks) {
            const batch = writeBatch(db);
            chunk.forEach(r => {
                batch.delete(doc(db, "halls", hallId, "residents", r.id));
            });
            await batch.commit();
        }
    }

    return { residents, loading, addResident, updateResident, deleteResident, addResidentsBulk, deleteAllResidents };
}
