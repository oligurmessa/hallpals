import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "@/lib/firebase"; // Import initialized functions

export interface Hall {
    id: string; // usually 'hall-xyz' or auto
    name: string;
    shortName: string;
    floors: number[];
    wings?: string[];
    isActive: boolean;
    createdAt?: any;
}

export function useHalls() {
    const [halls, setHalls] = useState<Hall[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const q = query(collection(db, "halls"), orderBy("name"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const hallsData: Hall[] = [];
            snapshot.forEach((doc) => {
                hallsData.push({ id: doc.id, ...doc.data() } as Hall);
            });
            setHalls(hallsData);
            setLoading(false);
        }, (error) => {
            console.error("Error fetching halls:", error);
            setLoading(false);
        });
        return () => unsubscribe();
    }, []);

    const createHall = async (id: string, data: Omit<Hall, "id">) => {
        const requestHallChange = httpsCallable(functions, 'requestHallChange');

        // Ensure id is provided appropriately for the function
        const hallId = id.trim() || doc(collection(db, "halls")).id;

        await requestHallChange({
            action: 'create',
            hallId: hallId,
            hallData: {
                name: data.name,
                shortName: data.shortName,
                floors: data.floors,
                wings: data.wings || [],
                isActive: data.isActive
            }
        });
    };

    const updateHall = async (id: string, data: Partial<Hall>) => {
        const requestHallChange = httpsCallable(functions, 'requestHallChange');

        await requestHallChange({
            action: 'update',
            hallId: id,
            hallData: {
                ...(data.name && { name: data.name }),
                ...(data.shortName && { shortName: data.shortName }),
                ...(data.floors && { floors: data.floors }),
                ...(data.wings && { wings: data.wings }),
                ...(data.isActive !== undefined && { isActive: data.isActive })
            }
        });
    };

    return { halls, loading, createHall, updateHall };
}
