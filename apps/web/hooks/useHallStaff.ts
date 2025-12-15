import { useState, useEffect } from "react";
import { collection, query, onSnapshot, doc, setDoc, deleteDoc, updateDoc, where, writeBatch } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface HallStaff {
    id: string; // User ID
    firstName?: string; // Optional, might need to fetch from user profile if not denormalized
    lastName?: string;
    email: string;
    role: 'ra' | 'staff' | 'admin';
    floor?: number; // Optional floor assignment for RAs
    wing?: string;
    createdAt?: any;
}

export function useHallStaff(hallId: string | null) {
    const [staff, setStaff] = useState<HallStaff[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setLoading(false);
            return;
        }

        // We fetch from halls/{hallId}/staff which contains the "manifested" staff/RAs
        const q = query(collection(db, "halls", hallId, "staff"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as HallStaff[];
            setStaff(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const addStaff = async (email: string, role: 'ra' | 'staff', floor?: number, wing?: string) => {
        if (!hallId) return;

        // Note: In a real app, we'd probably want to look up the UID by email via a Cloud Function
        // or require the UI to provide the UID (e.g. searching users).
        // For this MVP, we might create a placeholder or assume the UI handles user lookup.
        // Wait, the prompt says "manifest residents". For staff, we likely want to manifest them too.
        // If we only have email, we might just store the email invite.
        // BUT, for RAs to log in, they need a UID.
        // Let's implement a simple "Invite by Email" doc for now, OR valid user lookup.
        // To keep it simple and consistent with "manifest", we will just store the email and role
        // and assume a backend process (like ensureUserDoc or a join trigger) links them.
        // However, for immediate display, we'll store basic info.

        // Actually, let's assume we are just adding a "Staff Manifest" entry similar to existing code.
        // Just storing email is safer if we don't have UID.
        // But the type expects ID. We can use email as ID for the manifest if UID unknown.

        // Let's rely on a proper document structure:
        // docId could be email (sanitized) or auto-id.
        const staffRef = doc(collection(db, "halls", hallId, "staff"));
        // We'll trust the user provides an email.

        await setDoc(staffRef, {
            email,
            role,
            floor: floor || null,
            wing: wing || null,
            createdAt: new Date(),
            // Placeholders until they join
            firstName: "Invited",
            lastName: "User"
        });

    };

    const removeStaff = async (staffId: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "staff", staffId));
    };

    const addStaffBulk = async (staffList: { email: string; role: 'ra' | 'staff', wing?: string, floor?: number }[]) => {
        if (!hallId) return;

        const { writeBatch } = await import("firebase/firestore");
        const chunkSize = 450;

        for (let i = 0; i < staffList.length; i += chunkSize) {
            const chunk = staffList.slice(i, i + chunkSize);
            const batch = writeBatch(db);

            chunk.forEach(({ email, role, wing, floor }) => {
                const ref = doc(collection(db, "halls", hallId, "staff"));
                batch.set(ref, {
                    email,
                    role,
                    wing: wing || null,
                    floor: floor || null,
                    createdAt: new Date(),
                    firstName: "Invited",
                    lastName: "User"
                });
            });
            await batch.commit();
        }
    };

    const deleteAllStaff = async () => {
        if (!hallId) return;
        const { writeBatch } = await import("firebase/firestore");
        const chunkSize = 450;
        const chunks = [];

        for (let i = 0; i < staff.length; i += chunkSize) {
            chunks.push(staff.slice(i, i + chunkSize));
        }

        for (const chunk of chunks) {
            const batch = writeBatch(db);
            chunk.forEach(s => {
                batch.delete(doc(db, "halls", hallId, "staff", s.id));
            });
            await batch.commit();
        }
    }

    return { staff, loading, addStaff, removeStaff, addStaffBulk, deleteAllStaff };
}
