import { useState } from "react";
import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";

interface AIResponse {
    response: string;
    model: string;
}

export function useAI() {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [result, setResult] = useState<AIResponse | null>(null);

    const askAI = async (prompt: string, model?: string) => {
        setLoading(true);
        setError(null);
        try {
            const askAIFn = httpsCallable<{ prompt: string; model?: string }, AIResponse>(
                functions,
                "askAI"
            );
            const { data } = await askAIFn({ prompt, model });
            setResult(data);
            return data;
        } catch (err: any) {
            console.error("AI Error:", err);
            setError(err.message || "Failed to contact AI");
            throw err;
        } finally {
            setLoading(false);
        }
    };

    return { askAI, loading, error, result, reset: () => { setResult(null); setError(null); } };
}
