import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface InspectionTemplate {
    id: string;
    name: string;
    items: string[];
    createdAt?: any;
}

export function useInspectionTemplates(hallId: string | null) {
    const [templates, setTemplates] = useState<InspectionTemplate[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(collection(db, "halls", hallId, "inspection_templates"), orderBy("name"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as InspectionTemplate[];
            setTemplates(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const addTemplate = async (data: Omit<InspectionTemplate, "id">) => {
        if (!hallId) return;
        const newRef = doc(collection(db, "halls", hallId, "inspection_templates"));
        await setDoc(newRef, {
            ...data,
            createdAt: new Date(),
            updatedAt: new Date()
        });
    };

    const updateTemplate = async (id: string, data: Partial<InspectionTemplate>) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "inspection_templates", id), {
            ...data,
            updatedAt: new Date()
        });
    };

    const deleteTemplate = async (id: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "inspection_templates", id));
    }

    return { templates, loading, addTemplate, updateTemplate, deleteTemplate };
}
