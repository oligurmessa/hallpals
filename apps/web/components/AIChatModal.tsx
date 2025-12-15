"use client";

import { useState, useRef, useEffect } from "react";
import { useAI } from "@/hooks/useAI";
import { X, Send, Bot, Sparkles, User, RefreshCw, AlertCircle } from "lucide-react";

interface AIChatModalProps {
    isOpen: boolean;
    onClose: () => void;
}

interface Message {
    id: string;
    text: string;
    sender: 'user' | 'ai';
    createdAt: Date;
}

export default function AIChatModal({ isOpen, onClose }: AIChatModalProps) {
    const [input, setInput] = useState("");
    const [messages, setMessages] = useState<Message[]>([]);
    const { askAI, loading, error } = useAI();
    const messagesEndRef = useRef<HTMLDivElement>(null);

    // Initial greeting
    useEffect(() => {
        if (isOpen && messages.length === 0) {
            setMessages([{
                id: 'welcome',
                text: "Hi! I'm the HallPals AI Assistant. I can help you find information in the Handbook, suggest Roster tips, or answer general Residence Life questions. How can I help?",
                sender: 'ai',
                createdAt: new Date()
            }]);
        }
    }, [isOpen]);

    // Auto-scroll
    useEffect(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [messages, loading]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!input.trim() || loading) return;

        const userMsg: Message = { id: Date.now().toString(), text: input, sender: 'user', createdAt: new Date() };
        setMessages(prev => [...prev, userMsg]);
        setInput("");

        try {
            const response = await askAI(userMsg.text);
            const aiMsg: Message = { id: (Date.now() + 1).toString(), text: response.response, sender: 'ai', createdAt: new Date() };
            setMessages(prev => [...prev, aiMsg]);
        } catch (err) {
            // Error is handled by hook but we can show inline
            // No need to duplicate error state in messages, we display 'error' from hook below input
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className="bg-zinc-900 border border-white/10 rounded-2xl w-full max-w-2xl h-[600px] shadow-2xl flex flex-col overflow-hidden animate-in fade-in zoom-in duration-200">
                {/* Header */}
                <div className="p-4 border-b border-white/10 flex items-center justify-between bg-zinc-900">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center shadow-lg shadow-purple-500/20">
                            <Bot className="w-5 h-5 text-white" />
                        </div>
                        <div>
                            <h2 className="text-lg font-bold text-white flex items-center gap-2">
                                HallPals Assistant <Sparkles className="w-3 h-3 text-yellow-400" />
                            </h2>
                            <p className="text-xs text-zinc-400">Powered by Gemini Pro</p>
                        </div>
                    </div>
                    <button
                        onClick={onClose}
                        className="p-2 hover:bg-white/10 rounded-full text-zinc-400 hover:text-white transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Messages Area */}
                <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-zinc-950/50">
                    {messages.map((msg) => (
                        <div key={msg.id} className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}>
                            <div className={`flex gap-3 max-w-[80%] ${msg.sender === 'user' ? 'flex-row-reverse' : 'flex-row'}`}>
                                <div className={`w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center ${msg.sender === 'user' ? 'bg-zinc-800' : 'bg-indigo-600'}`}>
                                    {msg.sender === 'user' ? <User className="w-4 h-4 text-zinc-400" /> : <Bot className="w-4 h-4 text-white" />}
                                </div>
                                <div className={`p-3 rounded-2xl text-sm leading-relaxed ${msg.sender === 'user'
                                        ? 'bg-zinc-800 text-white rounded-tr-none'
                                        : 'bg-white/5 border border-white/10 text-zinc-200 rounded-tl-none'
                                    }`}>
                                    {msg.text}
                                </div>
                            </div>
                        </div>
                    ))}
                    {loading && (
                        <div className="flex justify-start">
                            <div className="flex gap-3 max-w-[80%]">
                                <div className="w-8 h-8 rounded-full bg-indigo-600 flex-shrink-0 flex items-center justify-center">
                                    <RefreshCw className="w-4 h-4 text-white animate-spin" />
                                </div>
                                <div className="p-3 rounded-2xl rounded-tl-none bg-white/5 border border-white/10 flex items-center gap-2">
                                    <span className="w-2 h-2 bg-zinc-400 rounded-full animate-bounce" />
                                    <span className="w-2 h-2 bg-zinc-400 rounded-full animate-bounce delay-100" />
                                    <span className="w-2 h-2 bg-zinc-400 rounded-full animate-bounce delay-200" />
                                </div>
                            </div>
                        </div>
                    )}
                    <div ref={messagesEndRef} />
                </div>

                {/* Input Area */}
                <div className="p-4 bg-zinc-900 border-t border-white/10">
                    {error && (
                        <div className="mb-2 p-2 bg-red-500/10 border border-red-500/20 rounded-lg flex items-center gap-2 text-xs text-red-400">
                            <AlertCircle className="w-3 h-3" />
                            {error}
                        </div>
                    )}
                    <form onSubmit={handleSubmit} className="flex gap-2">
                        <input
                            type="text"
                            value={input}
                            onChange={(e) => setInput(e.target.value)}
                            placeholder="Ask about policies, procedures, or advice..."
                            className="flex-1 bg-zinc-950 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                            disabled={loading}
                        />
                        <button
                            type="submit"
                            disabled={loading || !input.trim()}
                            className="p-3 bg-purple-600 hover:bg-purple-500 disabled:opacity-50 disabled:hover:bg-purple-600 text-white rounded-xl transition-colors shadow-lg shadow-purple-500/20"
                        >
                            <Send className="w-5 h-5" />
                        </button>
                    </form>
                </div>
            </div>
        </div>
    );
}
