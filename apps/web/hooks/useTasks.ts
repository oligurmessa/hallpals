import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface BulletinTask {
    id: string;
    title: string;
    description: string;
    assignee: string; // Name or ID
    deadline: string; // ISO date string
    status: 'pending' | 'in_progress' | 'completed';
    priority: 'low' | 'medium' | 'high';
    createdAt?: any;
}

export function useTasks(hallId: string | null) {
    const [tasks, setTasks] = useState<BulletinTask[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(collection(db, "halls", hallId, "bulletin_tasks"), orderBy("createdAt", "desc"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as BulletinTask[];
            setTasks(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const addTask = async (data: Omit<BulletinTask, "id">) => {
        if (!hallId) return;
        const newRef = doc(collection(db, "halls", hallId, "bulletin_tasks"));
        await setDoc(newRef, {
            ...data,
            createdAt: new Date(),
            updatedAt: new Date()
        });
    };

    const updateTask = async (id: string, data: Partial<BulletinTask>) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "bulletin_tasks", id), {
            ...data,
            updatedAt: new Date()
        });
    };

    const deleteTask = async (id: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "bulletin_tasks", id));
    }

    return { tasks, loading, addTask, updateTask, deleteTask };
}
