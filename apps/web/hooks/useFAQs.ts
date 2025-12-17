import { useState, useEffect } from "react";
import { collection, query, orderBy, onSnapshot, doc, setDoc, deleteDoc, updateDoc, serverTimestamp, writeBatch } from "firebase/firestore";
import { db } from "@/lib/firebase";

export interface FAQ {
    id: string;
    question: string;
    answer: string;
    category: string;
    order: number;
    isPublished: boolean;
    createdAt?: any;
    updatedAt?: any;
}

export const FAQ_CATEGORIES = [
    "General",
    "Move-In/Move-Out",
    "Maintenance",
    "Safety & Security",
    "Policies",
    "Amenities",
    "Roommates",
    "Events",
    "Other"
];

export function useFAQs(hallId: string) {
    const [faqs, setFaqs] = useState<FAQ[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!hallId) {
            setFaqs([]);
            setLoading(false);
            return;
        }

        const q = query(
            collection(db, "halls", hallId, "faqs"),
            orderBy("order", "asc")
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const data = snapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data(),
            })) as FAQ[];
            setFaqs(data);
            setLoading(false);
        });

        return () => unsubscribe();
    }, [hallId]);

    const createFAQ = async (data: Partial<FAQ>) => {
        if (!hallId) return;
        const newRef = doc(collection(db, "halls", hallId, "faqs"));
        const maxOrder = faqs.length > 0 ? Math.max(...faqs.map(f => f.order)) + 1 : 0;
        await setDoc(newRef, {
            question: data.question || "",
            answer: data.answer || "",
            category: data.category || "General",
            order: data.order ?? maxOrder,
            isPublished: data.isPublished ?? true,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp()
        });
        return newRef.id;
    };

    const updateFAQ = async (faqId: string, data: Partial<FAQ>) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "faqs", faqId), {
            ...data,
            updatedAt: serverTimestamp()
        });
    };

    const deleteFAQ = async (faqId: string) => {
        if (!hallId) return;
        await deleteDoc(doc(db, "halls", hallId, "faqs", faqId));
    };

    const publishFAQ = async (faqId: string) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "faqs", faqId), {
            isPublished: true,
            updatedAt: serverTimestamp()
        });
    };

    const unpublishFAQ = async (faqId: string) => {
        if (!hallId) return;
        await updateDoc(doc(db, "halls", hallId, "faqs", faqId), {
            isPublished: false,
            updatedAt: serverTimestamp()
        });
    };

    const reorderFAQs = async (reorderedFaqs: FAQ[]) => {
        if (!hallId) return;
        const batch = writeBatch(db);
        reorderedFaqs.forEach((faq, index) => {
            const faqRef = doc(db, "halls", hallId, "faqs", faq.id);
            batch.update(faqRef, { order: index, updatedAt: serverTimestamp() });
        });
        await batch.commit();
    };

    // Filter published FAQs
    const publishedFAQs = faqs.filter(f => f.isPublished);
    const draftFAQs = faqs.filter(f => !f.isPublished);

    // Group FAQs by category
    const faqsByCategory = faqs.reduce((acc, faq) => {
        const cat = faq.category || "General";
        if (!acc[cat]) acc[cat] = [];
        acc[cat].push(faq);
        return acc;
    }, {} as Record<string, FAQ[]>);

    return {
        faqs,
        publishedFAQs,
        draftFAQs,
        faqsByCategory,
        loading,
        createFAQ,
        updateFAQ,
        deleteFAQ,
        publishFAQ,
        unpublishFAQ,
        reorderFAQs
    };
}
