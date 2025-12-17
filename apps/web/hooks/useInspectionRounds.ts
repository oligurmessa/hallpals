import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface RoomInspection {
    roomNumber: string;
    status: 'pending' | 'completed';
    checklist: { id: string; name: string; isChecked: boolean }[];
    notes: string;
    completedAt?: any;
    completedBy?: string;
}

export interface InspectionRound {
    id: string;
    name: string;
    templateId: string;
    templateName?: string;
    dueDate: string; // ISO date string YYYY-MM-DD
    status: 'active' | 'completed';
    rooms: RoomInspection[];
    createdAt?: any;
    updatedAt?: any;
}

export function useInspectionRounds(hallId: string | null) {
    const [rounds, setRounds] = useState<InspectionRound[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "inspection_rounds"),
            orderBy("createdAt", "desc")
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as InspectionRound[];
            setRounds(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    // Create a new inspection round
    const createRound = async (data: {
        name: string;
        templateId: string;
        dueDate: string;
        roomNumbers: string[];
    }) => {
        if (!hallId) return;

        // Fetch the template to get checklist items
        const templateRef = doc(db, "halls", hallId, "inspection_templates", data.templateId);
        const templateSnap = await getDoc(templateRef);

        if (!templateSnap.exists()) {
            throw new Error("Template not found");
        }

        const template = templateSnap.data();
        const checklistItems = (template.items as string[]).map((item, index) => ({
            id: `item-${index}`,
            name: item,
            isChecked: false
        }));

        // Create rooms array with template checklist
        const rooms: RoomInspection[] = data.roomNumbers.map(roomNumber => ({
            roomNumber,
            status: 'pending',
            checklist: checklistItems.map(item => ({ ...item })), // Clone checklist for each room
            notes: ''
        }));

        const newRef = doc(collection(db, "halls", hallId, "inspection_rounds"));
        await setDoc(newRef, {
            name: data.name,
            templateId: data.templateId,
            templateName: template.name,
            dueDate: data.dueDate,
            status: 'active',
            rooms,
            createdAt: new Date(),
            updatedAt: new Date()
        });

        return newRef.id;
    };

    // Update round status
    const updateRoundStatus = async (roundId: string, status: 'active' | 'completed') => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "inspection_rounds", roundId), {
            status,
            updatedAt: new Date()
        });
    };

    // Delete a round
    const deleteRound = async (roundId: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "inspection_rounds", roundId));
    };

    // Get stats
    const activeRounds = rounds.filter(r => r.status === 'active');
    const completedRounds = rounds.filter(r => r.status === 'completed');

    return {
        rounds,
        activeRounds,
        completedRounds,
        loading,
        createRound,
        updateRoundStatus,
        deleteRound
    };
}
