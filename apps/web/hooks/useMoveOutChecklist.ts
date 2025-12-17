import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc, serverTimestamp, where } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface ChecklistItem {
    id: string;
    text: string;
    order: number;
    isRequired: boolean;
}

export interface MoveOutChecklist {
    id: string;
    title: string;
    description: string;
    items: ChecklistItem[];
    isPublished: boolean;
    publishedAt?: any;
    createdAt?: any;
    updatedAt?: any;
}

export interface ResidentChecklist {
    id: string;
    residentId: string;
    residentName: string;
    roomNumber: string;
    checklistId: string;
    completedItems: string[]; // Array of item IDs that are completed
    isComplete: boolean;
    completedAt?: any;
    createdAt?: any;
    updatedAt?: any;
}

export function useMoveOutChecklists(hallId: string) {
    const [checklists, setChecklists] = useState<MoveOutChecklist[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setChecklists([]);
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "move_out_templates"),
            orderBy("createdAt", "desc")
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as MoveOutChecklist[];
            setChecklists(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const createChecklist = async (data: Partial<MoveOutChecklist>) => {
        if (!hallId) return;
        const newRef = doc(collection(db, "halls", hallId, "move_out_templates"));
        await setDoc(newRef, {
            ...data,
            items: data.items || [],
            isPublished: false,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp()
        });
        return newRef.id;
    };

    const updateChecklist = async (checklistId: string, data: Partial<MoveOutChecklist>) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "move_out_templates", checklistId), {
            ...data,
            updatedAt: serverTimestamp()
        });
    };

    const publishChecklist = async (checklistId: string) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "move_out_templates", checklistId), {
            isPublished: true,
            publishedAt: serverTimestamp(),
            updatedAt: serverTimestamp()
        });
    };

    const unpublishChecklist = async (checklistId: string) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "move_out_templates", checklistId), {
            isPublished: false,
            updatedAt: serverTimestamp()
        });
    };

    const deleteChecklist = async (checklistId: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "move_out_templates", checklistId));
    };

    return {
        checklists,
        loading,
        createChecklist,
        updateChecklist,
        publishChecklist,
        unpublishChecklist,
        deleteChecklist
    };
}

// Hook for viewing resident progress on checklists
export function useResidentChecklists(hallId: string) {
    const [residentChecklists, setResidentChecklists] = useState<ResidentChecklist[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setResidentChecklists([]);
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "move_out_checklists"),
            orderBy("createdAt", "desc")
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as ResidentChecklist[];
            setResidentChecklists(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    return { residentChecklists, loading };
}
