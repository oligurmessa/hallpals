import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface DocMeta {
    id: string; // slug
    title: string;
    category: string;
    isPublished: boolean;
    updatedAt?: any;
    entryCount?: number;
}

export function useDocs() {
    const [docs, setDocs] = useState<DocMeta[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const q = query(collection(db, "docs"), orderBy("title"));
        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as DocMeta[];
            setDocs(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const createDoc = async (slug: string, data: Partial<DocMeta>) => {
        await setDoc(doc(db, "docs", slug), {
            ...data,
            slug,
            createdAt: new Date(),
            updatedAt: new Date(),
            entryCount: 0
        });
    };

    const updateDocMeta = async (docId: string, data: Partial<DocMeta>) => {
        await setDoc(doc(db, "docs", docId), {
            ...data,
            updatedAt: new Date()
        }, { merge: true });
    };

    return { docs, loading, createDoc, updateDocMeta };
}

export interface DocEntry {
    id: string;
    order: number;
    text: string;
    section: string;
    topic?: string;
    updatedAt?: any;
}

export function useDoc(slug: string) {
    const [docMeta, setDocMeta] = useState<DocMeta | null>(null);
    const [entries, setEntries] = useState<DocEntry[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!slug) return;

        // Doc Meta Listener
        const unsubMeta = onSnapshot(doc(db, "docs", slug), (docSnap) => {
            if (docSnap.exists()) {
                setDocMeta({ id: docSnap.id, ...docSnap.data() } as DocMeta);
            } else {
                setDocMeta(null);
            }
        });

        // Entries Listener
        const q = query(collection(db, "docs", slug, "entries"), orderBy("order"));
        const unsubEntries = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((d) => ({
                id: d.id,
                ...d.data(),
            })) as DocEntry[];
            setEntries(data);
            setLoading(false);
        });

        return () => {
            unsubMeta();
            unsubEntries();
        };
    }, [slug]);

    const updateEntry = async (entryId: string, text: string) => {
        await setDoc(doc(db, "docs", slug, "entries", entryId), {
            text,
            updatedAt: new Date()
        }, { merge: true });
    };

    const addEntry = async (section: string, text: string) => {
        // Simple Append
        const newOrder = entries.length > 0 ? entries[entries.length - 1].order + 1 : 1;
        const newRef = doc(collection(db, "docs", slug, "entries"));
        await setDoc(newRef, {
            order: newOrder,
            section,
            text,
            topic: docMeta?.title || "",
            createdAt: new Date(),
            updatedAt: new Date()
        });
    };

    const deleteEntry = async (entryId: string) => {
        await deleteDoc(doc(db, "docs", slug, "entries", entryId));
    };

    const togglePublish = async () => {
        if (!docMeta) return;
        await setDoc(doc(db, "docs", slug), {
            isPublished: !docMeta.isPublished,
            updatedAt: new Date()
        }, { merge: true });
    };

    return { docMeta, entries, loading, updateEntry, addEntry, deleteEntry, togglePublish };
}
