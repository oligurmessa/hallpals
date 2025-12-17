"use client";

import React, { useState, useEffect } from "react";
import { useFAQs, FAQ, FAQ_CATEGORIES } from "@/hooks/useFAQs";
import { useAuth } from "@/context/AuthContext";
import { useHalls } from "@/hooks/useHalls";
import { Plus, Trash2, Edit2, Eye, EyeOff, HelpCircle, ChevronDown, ChevronUp, GripVertical, Building2 } from "lucide-react";

export default function FAQsPage() {
    const { profile } = useAuth();
    const { halls } = useHalls();
    const [selectedHallId, setSelectedHallId] = useState<string | null>(null);

    // Initialize selection once profile is loaded
    useEffect(() => {
        if (!selectedHallId && profile?.hallId) {
            setSelectedHallId(profile.hallId);
        } else if (!selectedHallId && halls.length > 0) {
            setSelectedHallId(halls[0].id);
        }
    }, [profile, halls, selectedHallId]);

    const hallId = selectedHallId || "";
    const { faqs, faqsByCategory, loading, createFAQ, updateFAQ, deleteFAQ, publishFAQ, unpublishFAQ } = useFAQs(hallId);

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingFAQ, setEditingFAQ] = useState<FAQ | null>(null);
    const [formData, setFormData] = useState({
        question: "",
        answer: "",
        category: "General",
        isPublished: true
    });
    const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set(FAQ_CATEGORIES));
    const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);

    const resetForm = () => {
        setFormData({
            question: "",
            answer: "",
            category: "General",
            isPublished: true
        });
        setEditingFAQ(null);
    };

    const openCreateModal = () => {
        resetForm();
        setIsModalOpen(true);
    };

    const openEditModal = (faq: FAQ) => {
        setFormData({
            question: faq.question,
            answer: faq.answer,
            category: faq.category,
            isPublished: faq.isPublished
        });
        setEditingFAQ(faq);
        setIsModalOpen(true);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!formData.question.trim() || !formData.answer.trim()) return;

        if (editingFAQ) {
            await updateFAQ(editingFAQ.id, formData);
        } else {
            await createFAQ(formData);
        }
        setIsModalOpen(false);
        resetForm();
    };

    const handleDelete = async (faqId: string) => {
        await deleteFAQ(faqId);
        setDeleteConfirm(null);
    };

    const togglePublish = async (faq: FAQ) => {
        if (faq.isPublished) {
            await unpublishFAQ(faq.id);
        } else {
            await publishFAQ(faq.id);
        }
    };

    const toggleCategory = (category: string) => {
        setExpandedCategories(prev => {
            const newSet = new Set(prev);
            if (newSet.has(category)) {
                newSet.delete(category);
            } else {
                newSet.add(category);
            }
            return newSet;
        });
    };

    // Stats
    const publishedCount = faqs.filter(f => f.isPublished).length;
    const draftCount = faqs.filter(f => !f.isPublished).length;

    // Hall selector for header
    const hallSelector = halls.length > 1 ? (
        <select
            value={selectedHallId || ""}
            onChange={(e) => setSelectedHallId(e.target.value)}
            className="px-3 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/50"
        >
            {halls.map((hall) => (
                <option key={hall.id} value={hall.id}>{hall.name}</option>
            ))}
        </select>
    ) : null;

    if (!hallId) {
        return (
            <div className="max-w-7xl mx-auto">
                <div className="text-center py-20">
                    <HelpCircle className="w-16 h-16 text-zinc-600 mx-auto mb-4" />
                    <h2 className="text-xl font-semibold text-white mb-2">Select a Hall</h2>
                    <p className="text-zinc-400">Please select a hall to manage FAQs.</p>
                    {halls.length > 0 && (
                        <select
                            value=""
                            onChange={(e) => setSelectedHallId(e.target.value)}
                            className="mt-4 px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                        >
                            <option value="" disabled>Select a hall...</option>
                            {halls.map((hall) => (
                                <option key={hall.id} value={hall.id}>{hall.name}</option>
                            ))}
                        </select>
                    )}
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-7xl mx-auto">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Hall FAQs</h1>
                    <p className="text-zinc-400 mt-1">Create and publish frequently asked questions for residents.</p>
                </div>

                <div className="flex items-center gap-3">
                    {hallSelector}
                    <button
                        onClick={openCreateModal}
                        className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-sm font-medium transition-colors"
                    >
                        <Plus className="w-4 h-4" />
                        Add FAQ
                    </button>
                </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
                <div className="bg-zinc-900 border border-white/5 rounded-2xl p-4">
                    <p className="text-zinc-400 text-sm">Total FAQs</p>
                    <p className="text-2xl font-bold text-white mt-1">{faqs.length}</p>
                </div>
                <div className="bg-zinc-900 border border-white/5 rounded-2xl p-4">
                    <p className="text-zinc-400 text-sm">Published</p>
                    <p className="text-2xl font-bold text-green-400 mt-1">{publishedCount}</p>
                </div>
                <div className="bg-zinc-900 border border-white/5 rounded-2xl p-4">
                    <p className="text-zinc-400 text-sm">Drafts</p>
                    <p className="text-2xl font-bold text-orange-400 mt-1">{draftCount}</p>
                </div>
                <div className="bg-zinc-900 border border-white/5 rounded-2xl p-4">
                    <p className="text-zinc-400 text-sm">Categories</p>
                    <p className="text-2xl font-bold text-blue-400 mt-1">{Object.keys(faqsByCategory).length}</p>
                </div>
            </div>

            {/* FAQ List by Category */}
            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : faqs.length === 0 ? (
                <div className="text-center py-20 bg-zinc-900 border border-white/5 rounded-2xl">
                    <HelpCircle className="w-16 h-16 text-zinc-600 mx-auto mb-4" />
                    <h2 className="text-xl font-semibold text-white mb-2">No FAQs Yet</h2>
                    <p className="text-zinc-400 mb-6">Create your first FAQ to help residents find answers quickly.</p>
                    <button
                        onClick={openCreateModal}
                        className="px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-xl font-medium transition-colors"
                    >
                        Create First FAQ
                    </button>
                </div>
            ) : (
                <div className="space-y-4">
                    {FAQ_CATEGORIES.filter(cat => faqsByCategory[cat]?.length > 0).map((category) => (
                        <div key={category} className="bg-zinc-900 border border-white/5 rounded-2xl overflow-hidden">
                            {/* Category Header */}
                            <button
                                onClick={() => toggleCategory(category)}
                                className="w-full flex items-center justify-between px-6 py-4 hover:bg-white/5 transition-colors"
                            >
                                <div className="flex items-center gap-3">
                                    <span className="text-lg font-semibold text-white">{category}</span>
                                    <span className="px-2 py-0.5 bg-zinc-800 text-zinc-400 text-xs rounded-full">
                                        {faqsByCategory[category]?.length || 0}
                                    </span>
                                </div>
                                {expandedCategories.has(category) ? (
                                    <ChevronUp className="w-5 h-5 text-zinc-400" />
                                ) : (
                                    <ChevronDown className="w-5 h-5 text-zinc-400" />
                                )}
                            </button>

                            {/* FAQs in Category */}
                            {expandedCategories.has(category) && (
                                <div className="border-t border-white/5">
                                    {faqsByCategory[category]?.map((faq, index) => (
                                        <div
                                            key={faq.id}
                                            className={`px-6 py-4 ${index !== 0 ? 'border-t border-white/5' : ''}`}
                                        >
                                            <div className="flex items-start justify-between gap-4">
                                                <div className="flex-1 min-w-0">
                                                    <div className="flex items-center gap-2 mb-2">
                                                        <HelpCircle className="w-4 h-4 text-blue-400 flex-shrink-0" />
                                                        <h3 className="font-medium text-white">{faq.question}</h3>
                                                        {!faq.isPublished && (
                                                            <span className="px-2 py-0.5 bg-orange-500/20 text-orange-400 text-xs rounded-full">
                                                                Draft
                                                            </span>
                                                        )}
                                                    </div>
                                                    <p className="text-zinc-400 text-sm whitespace-pre-wrap ml-6">{faq.answer}</p>
                                                </div>
                                                <div className="flex items-center gap-2 flex-shrink-0">
                                                    <button
                                                        onClick={() => togglePublish(faq)}
                                                        className={`p-2 rounded-lg transition-colors ${faq.isPublished
                                                            ? 'text-green-400 hover:bg-green-500/10'
                                                            : 'text-zinc-500 hover:bg-white/5'
                                                            }`}
                                                        title={faq.isPublished ? "Unpublish" : "Publish"}
                                                    >
                                                        {faq.isPublished ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                                                    </button>
                                                    <button
                                                        onClick={() => openEditModal(faq)}
                                                        className="p-2 text-zinc-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                                                        title="Edit"
                                                    >
                                                        <Edit2 className="w-4 h-4" />
                                                    </button>
                                                    {deleteConfirm === faq.id ? (
                                                        <div className="flex items-center gap-1">
                                                            <button
                                                                onClick={() => handleDelete(faq.id)}
                                                                className="px-2 py-1 text-xs bg-red-600 hover:bg-red-500 text-white rounded-lg transition-colors"
                                                            >
                                                                Delete
                                                            </button>
                                                            <button
                                                                onClick={() => setDeleteConfirm(null)}
                                                                className="px-2 py-1 text-xs bg-zinc-700 hover:bg-zinc-600 text-white rounded-lg transition-colors"
                                                            >
                                                                Cancel
                                                            </button>
                                                        </div>
                                                    ) : (
                                                        <button
                                                            onClick={() => setDeleteConfirm(faq.id)}
                                                            className="p-2 text-zinc-400 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                                                            title="Delete"
                                                        >
                                                            <Trash2 className="w-4 h-4" />
                                                        </button>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            )}

            {/* Create/Edit Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
                        <div className="p-6 border-b border-white/5">
                            <h2 className="text-xl font-semibold text-white">
                                {editingFAQ ? "Edit FAQ" : "Create New FAQ"}
                            </h2>
                        </div>

                        <form onSubmit={handleSubmit} className="p-6 space-y-6">
                            {/* Category */}
                            <div>
                                <label className="block text-sm font-medium text-zinc-300 mb-2">
                                    Category
                                </label>
                                <select
                                    value={formData.category}
                                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                                    className="w-full px-4 py-3 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                                >
                                    {FAQ_CATEGORIES.map((cat) => (
                                        <option key={cat} value={cat}>{cat}</option>
                                    ))}
                                </select>
                            </div>

                            {/* Question */}
                            <div>
                                <label className="block text-sm font-medium text-zinc-300 mb-2">
                                    Question *
                                </label>
                                <input
                                    type="text"
                                    value={formData.question}
                                    onChange={(e) => setFormData({ ...formData, question: e.target.value })}
                                    placeholder="e.g., What are the quiet hours?"
                                    className="w-full px-4 py-3 bg-zinc-800 border border-white/10 rounded-xl text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                                    required
                                />
                            </div>

                            {/* Answer */}
                            <div>
                                <label className="block text-sm font-medium text-zinc-300 mb-2">
                                    Answer *
                                </label>
                                <textarea
                                    value={formData.answer}
                                    onChange={(e) => setFormData({ ...formData, answer: e.target.value })}
                                    placeholder="Provide a clear and helpful answer..."
                                    rows={5}
                                    className="w-full px-4 py-3 bg-zinc-800 border border-white/10 rounded-xl text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 resize-none"
                                    required
                                />
                            </div>

                            {/* Publish Toggle */}
                            <div className="flex items-center gap-3">
                                <label className="relative inline-flex items-center cursor-pointer">
                                    <input
                                        type="checkbox"
                                        checked={formData.isPublished}
                                        onChange={(e) => setFormData({ ...formData, isPublished: e.target.checked })}
                                        className="sr-only peer"
                                    />
                                    <div className="w-11 h-6 bg-zinc-700 peer-focus:ring-2 peer-focus:ring-blue-500/50 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-600"></div>
                                </label>
                                <span className="text-zinc-300 text-sm">
                                    {formData.isPublished ? "Published - visible to residents" : "Draft - not visible to residents"}
                                </span>
                            </div>

                            {/* Actions */}
                            <div className="flex justify-end gap-3 pt-4 border-t border-white/5">
                                <button
                                    type="button"
                                    onClick={() => { setIsModalOpen(false); resetForm(); }}
                                    className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="px-6 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl font-medium transition-colors"
                                >
                                    {editingFAQ ? "Save Changes" : "Create FAQ"}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
