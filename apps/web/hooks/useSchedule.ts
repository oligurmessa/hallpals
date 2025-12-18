import { useState, useEffect } from "react";
import { collection, query, onSnapshot, doc, setDoc, deleteDoc, writeBatch, Timestamp, where, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface DutyShift {
    id: string;
    userId?: string;
    email: string;
    startTime: Timestamp;
    endTime: Timestamp;
    role: 'primary' | 'secondary';
    notes?: string;
    startStr?: string; // Derived YYYY-MM-DD
}

// UI Friendly Aggregated View
export interface DutySchedule {
    id: string; // YYYY-MM-DD
    date: Date;
    primaryRa?: { id?: string, name: string, email: string };
    secondaryRa?: { id?: string, name: string, email: string };
    notes?: string;
}

export function useSchedule(hallId: string | null) {
    const [schedule, setSchedule] = useState<DutySchedule[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        // Fetch all shifts
        const q = query(collection(db, "halls", hallId, "shifts"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const shifts = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            })) as DutyShift[];

            // Aggregate by Date
            const dayMap = new Map<string, DutySchedule>();

            shifts.forEach(shift => {
                const date = shift.startTime.toDate();
                const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD

                if (!dayMap.has(dateStr)) {
                    dayMap.set(dateStr, {
                        id: dateStr,
                        date: date,
                        notes: shift.notes
                    });
                }
                const day = dayMap.get(dateStr)!;
                const raInfo = {
                    id: shift.userId,
                    email: shift.email,
                    // Name is not strictly stored in shift, but we might want to store it for easier UI
                    // or fetch it. For now, use email as fallback name
                    name: shift.email.split('@')[0]
                };

                if (shift.role === 'primary') {
                    day.primaryRa = raInfo;
                } else {
                    day.secondaryRa = raInfo;
                }
                if (shift.notes) day.notes = shift.notes;
            });

            const aggregated = Array.from(dayMap.values()).sort((a, b) => a.id.localeCompare(b.id));
            setSchedule(aggregated);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const importSchedule = async (items: { dateStr: string, primary?: any, secondary?: any, notes?: string }[]) => {
        if (!hallId) return;
        const batch = writeBatch(db);

        // We generate IDs based on Date + Role to avoid duplicates/easy overwrite
        // e.g. 2024-01-01_primary

        items.forEach(item => {
            const dateParts = item.dateStr.split('-');
            const year = parseInt(dateParts[0]);
            const month = parseInt(dateParts[1]) - 1;
            const day = parseInt(dateParts[2]);

            // Default Duty: 4:30 PM to 8:00 AM next day
            const start = new Date(year, month, day, 16, 30, 0);
            const end = new Date(year, month, day + 1, 8, 0, 0);

            if (item.primary) {
                const ref = doc(db, "halls", hallId, "shifts", `${item.dateStr}_primary`);
                batch.set(ref, {
                    userId: item.primary.id || null,
                    email: item.primary.email,
                    displayName: item.primary.name, // Store name for UI
                    startTime: Timestamp.fromDate(start),
                    endTime: Timestamp.fromDate(end),
                    role: 'primary',
                    notes: item.notes || "",
                    updatedAt: new Date()
                });
            }

            if (item.secondary) {
                const ref = doc(db, "halls", hallId, "shifts", `${item.dateStr}_secondary`);
                batch.set(ref, {
                    userId: item.secondary.id || null,
                    email: item.secondary.email,
                    displayName: item.secondary.name,
                    startTime: Timestamp.fromDate(start),
                    endTime: Timestamp.fromDate(end),
                    role: 'secondary',
                    notes: item.notes || "",
                    updatedAt: new Date()
                });
            }
        });

        await batch.commit();
    };

    const deleteDuty = async (dateStr: string) => {
        if (!hallId) return;
        const batch = writeBatch(db);
        const primaryRef = doc(db, "halls", hallId, "shifts", `${dateStr}_primary`);
        const secondaryRef = doc(db, "halls", hallId, "shifts", `${dateStr}_secondary`);

        batch.delete(primaryRef);
        batch.delete(secondaryRef);

        await batch.commit();
    };

    const addDuty = async (dateStr: string, primary: any, secondary: any, notes: string) => {
        return importSchedule([{ dateStr, primary, secondary, notes }]);
    };

    return { schedule, loading, importSchedule, addDuty, deleteDuty };
}
