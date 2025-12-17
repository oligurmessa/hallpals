"use client";

import React, { useState, useEffect } from "react";
import { useMoveOutChecklists, useResidentChecklists, ChecklistItem } from "@/hooks/useMoveOutChecklist";
import { useAuth } from "@/context/AuthContext";
import { useHalls } from "@/hooks/useHalls";
import { Plus, Trash2, GripVertical, Eye, EyeOff, CheckCircle2, Circle, ClipboardList, Warehouse } from "lucide-react";

export default function MoveOutChecklistPage() {
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
    const { checklists, loading, createChecklist, updateChecklist, publishChecklist, unpublishChecklist, deleteChecklist } = useMoveOutChecklists(hallId);
    const { residentChecklists } = useResidentChecklists(hallId);

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingChecklist, setEditingChecklist] = useState<string | null>(null);
    const [formData, setFormData] = useState({
        title: "",
        description: "",
        items: [] as ChecklistItem[]
    });
    const [newItemText, setNewItemText] = useState("");

    const resetForm = () => {
        setFormData({ title: "", description: "", items: [] });
        setNewItemText("");
        setEditingChecklist(null);
    };

    const openCreateModal = () => {
        resetForm();
        setIsModalOpen(true);
    };

    const openEditModal = (checklist: any) => {
        setEditingChecklist(checklist.id);
        setFormData({
            title: checklist.title,
            description: checklist.description || "",
            items: checklist.items || []
        });
        setIsModalOpen(true);
    };

    const closeModal = () => {
        setIsModalOpen(false);
        resetForm();
    };

    const addItem = () => {
        if (!newItemText.trim()) return;
        const newItem: ChecklistItem = {
            id: `item-${Date.now()}`,
            text: newItemText.trim(),
            order: formData.items.length,
            isRequired: true
        };
        setFormData({ ...formData, items: [...formData.items, newItem] });
        setNewItemText("");
    };

    const removeItem = (itemId: string) => {
        setFormData({
            ...formData,
            items: formData.items.filter(item => item.id !== itemId)
        });
    };

    const toggleItemRequired = (itemId: string) => {
        setFormData({
            ...formData,
            items: formData.items.map(item =>
                item.id === itemId ? { ...item, isRequired: !item.isRequired } : item
            )
        });
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!formData.title.trim()) return;

        try {
            if (editingChecklist) {
                await updateChecklist(editingChecklist, formData);
            } else {
                await createChecklist(formData);
            }
            closeModal();
        } catch (err) {
            alert("Error saving checklist: " + err);
        }
    };

    const handlePublishToggle = async (checklistId: string, isPublished: boolean) => {
        if (isPublished) {
            await unpublishChecklist(checklistId);
        } else {
            await publishChecklist(checklistId);
        }
    };

    const handleDelete = async (checklistId: string) => {
        if (confirm("Are you sure you want to delete this checklist?")) {
            await deleteChecklist(checklistId);
        }
    };

    // Get completion stats for a checklist
    const getCompletionStats = (checklistId: string) => {
        const related = residentChecklists.filter(rc => rc.checklistId === checklistId);
        const completed = related.filter(rc => rc.isComplete).length;
        return { total: related.length, completed };
    };

    // Hall selector for header
    const hallSelector = halls.length > 1 ? (
        <select
            value={selectedHallId || ""}
            onChange={(e) => setSelectedHallId(e.target.value)}
            className="px-3 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500/50"
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
                    <ClipboardList className="w-16 h-16 text-zinc-600 mx-auto mb-4" />
                    <h2 className="text-xl font-semibold text-white mb-2">Select a Hall</h2>
                    <p className="text-zinc-400">Please select a hall to manage move-out checklists.</p>
                    {halls.length > 0 && (
                        <select
                            value=""
                            onChange={(e) => setSelectedHallId(e.target.value)}
                            className="mt-4 px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
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
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Move-Out Checklists</h1>
                    <p className="text-zinc-400 mt-1">Create and publish checklists for residents moving out.</p>
                </div>

                <div className="flex items-center gap-3">
                    {hallSelector}
                    <button
                        onClick={openCreateModal}
                        className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                    >
                        <Plus className="w-4 h-4" />
                        Create Checklist
                    </button>
                </div>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : checklists.length === 0 ? (
                <div className="text-center py-20 bg-zinc-900 border border-white/5 rounded-2xl">
                    <ClipboardList className="w-16 h-16 text-zinc-600 mx-auto mb-4" />
                    <h2 className="text-xl font-semibold text-white mb-2">No Checklists Yet</h2>
                    <p className="text-zinc-400 mb-6">Create your first move-out checklist for residents.</p>
                    <button
                        onClick={openCreateModal}
                        className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                    >
                        Create Checklist
                    </button>
                </div>
            ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {checklists.map((checklist) => {
                        const stats = getCompletionStats(checklist.id);
                        return (
                            <div
                                key={checklist.id}
                                className="bg-zinc-900 border border-white/5 rounded-2xl p-6 hover:border-white/10 transition-all"
                            >
                                <div className="flex justify-between items-start mb-4">
                                    <div className="flex-1">
                                        <div className="flex items-center gap-2 mb-1">
                                            <h3 className="text-lg font-bold text-white">{checklist.title}</h3>
                                            <span className={`text-xs px-2 py-0.5 rounded-full ${checklist.isPublished ? 'bg-emerald-500/10 text-emerald-400' : 'bg-yellow-500/10 text-yellow-400'}`}>
                                                {checklist.isPublished ? "Published" : "Draft"}
                                            </span>
                                        </div>
                                        {checklist.description && (
                                            <p className="text-sm text-zinc-400">{checklist.description}</p>
                                        )}
                                    </div>
                                </div>

                                {/* Checklist Items Preview */}
                                <div className="space-y-2 mb-4">
                                    {checklist.items.slice(0, 4).map((item, idx) => (
                                        <div key={item.id} className="flex items-center gap-2 text-sm">
                                            <Circle className="w-4 h-4 text-zinc-600" />
                                            <span className="text-zinc-300">{item.text}</span>
                                            {item.isRequired && (
                                                <span className="text-xs text-red-400">*</span>
                                            )}
                                        </div>
                                    ))}
                                    {checklist.items.length > 4 && (
                                        <p className="text-xs text-zinc-500 pl-6">
                                            +{checklist.items.length - 4} more items
                                        </p>
                                    )}
                                </div>

                                {/* Stats */}
                                {checklist.isPublished && stats.total > 0 && (
                                    <div className="flex items-center gap-4 mb-4 text-sm">
                                        <div className="flex items-center gap-1">
                                            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                                            <span className="text-zinc-400">{stats.completed}/{stats.total} completed</span>
                                        </div>
                                    </div>
                                )}

                                {/* Actions */}
                                <div className="flex items-center gap-2 pt-4 border-t border-white/5">
                                    <button
                                        onClick={() => openEditModal(checklist)}
                                        className="px-3 py-1.5 bg-zinc-800 hover:bg-zinc-700 text-white rounded-lg text-sm transition-colors"
                                    >
                                        Edit
                                    </button>
                                    <button
                                        onClick={() => handlePublishToggle(checklist.id, checklist.isPublished)}
                                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm transition-colors ${
                                            checklist.isPublished
                                                ? 'bg-yellow-500/10 text-yellow-400 hover:bg-yellow-500/20'
                                                : 'bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20'
                                        }`}
                                    >
                                        {checklist.isPublished ? (
                                            <>
                                                <EyeOff className="w-3.5 h-3.5" />
                                                Unpublish
                                            </>
                                        ) : (
                                            <>
                                                <Eye className="w-3.5 h-3.5" />
                                                Publish
                                            </>
                                        )}
                                    </button>
                                    <button
                                        onClick={() => handleDelete(checklist.id)}
                                        className="px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg text-sm transition-colors ml-auto"
                                    >
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}

            {/* Create/Edit Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
                        <h2 className="text-xl font-bold text-white mb-4">
                            {editingChecklist ? "Edit Checklist" : "Create Move-Out Checklist"}
                        </h2>
                        <form onSubmit={handleSubmit} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Title</label>
                                <input
                                    type="text"
                                    value={formData.title}
                                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="e.g., Spring 2025 Move-Out"
                                    required
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Description (optional)</label>
                                <textarea
                                    value={formData.description}
                                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50 resize-none"
                                    placeholder="Instructions for residents..."
                                    rows={2}
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-2">Checklist Items</label>

                                {/* Existing Items */}
                                <div className="space-y-2 mb-3">
                                    {formData.items.map((item, idx) => (
                                        <div key={item.id} className="flex items-center gap-2 bg-zinc-800 rounded-lg p-2">
                                            <GripVertical className="w-4 h-4 text-zinc-600 cursor-move" />
                                            <span className="flex-1 text-sm text-white">{item.text}</span>
                                            <button
                                                type="button"
                                                onClick={() => toggleItemRequired(item.id)}
                                                className={`text-xs px-2 py-1 rounded ${item.isRequired ? 'bg-red-500/20 text-red-400' : 'bg-zinc-700 text-zinc-400'}`}
                                            >
                                                {item.isRequired ? "Required" : "Optional"}
                                            </button>
                                            <button
                                                type="button"
                                                onClick={() => removeItem(item.id)}
                                                className="p-1 text-zinc-500 hover:text-red-400 transition-colors"
                                            >
                                                <Trash2 className="w-4 h-4" />
                                            </button>
                                        </div>
                                    ))}
                                </div>

                                {/* Add New Item */}
                                <div className="flex gap-2">
                                    <input
                                        type="text"
                                        value={newItemText}
                                        onChange={(e) => setNewItemText(e.target.value)}
                                        onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), addItem())}
                                        className="flex-1 px-3 py-2 bg-zinc-800 border border-white/10 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                        placeholder="Add checklist item..."
                                    />
                                    <button
                                        type="button"
                                        onClick={addItem}
                                        className="px-3 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-lg text-sm transition-colors"
                                    >
                                        <Plus className="w-4 h-4" />
                                    </button>
                                </div>
                            </div>

                            <div className="flex justify-end gap-2 mt-6 pt-4 border-t border-white/5">
                                <button
                                    type="button"
                                    onClick={closeModal}
                                    className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    disabled={!formData.title.trim() || formData.items.length === 0}
                                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    {editingChecklist ? "Save Changes" : "Create Checklist"}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
