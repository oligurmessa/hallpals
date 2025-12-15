"use client";

import React, { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useInspectionTemplates, InspectionTemplate } from "@/hooks/useInspectionTemplates";
import { Search, Plus, ClipboardCheck, Edit2, Trash2, X } from "lucide-react";

export default function InspectionsPage() {
    const { profile } = useAuth();
    const hallId = profile?.hallId;
    const { templates, loading, addTemplate, updateTemplate, deleteTemplate } = useInspectionTemplates(hallId);

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingId, setEditingId] = useState<string | null>(null);

    const [formData, setFormData] = useState<{ name: string, items: string[] }>({
        name: "",
        items: [""]
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const cleanedItems = formData.items.filter(i => i.trim() !== "");
        if (cleanedItems.length === 0) {
            alert("Please add at least one inspection item.");
            return;
        }

        if (editingId) {
            await updateTemplate(editingId, { name: formData.name, items: cleanedItems });
        } else {
            await addTemplate({ name: formData.name, items: cleanedItems });
        }
        closeModal();
    };

    const openCreate = () => {
        setEditingId(null);
        setFormData({ name: "", items: ["Check for damage", "Check cleanliness", "Verify furniture"] });
        setIsModalOpen(true);
    };

    const openEdit = (t: InspectionTemplate) => {
        setEditingId(t.id);
        setFormData({ name: t.name, items: t.items });
        setIsModalOpen(true);
    };

    const closeModal = () => {
        setIsModalOpen(false);
        setEditingId(null);
    }

    const handleItemChange = (idx: number, val: string) => {
        const newItems = [...formData.items];
        newItems[idx] = val;
        setFormData({ ...formData, items: newItems });
    };

    const addItem = () => {
        setFormData({ ...formData, items: [...formData.items, ""] });
    };

    const removeItem = (idx: number) => {
        const newItems = [...formData.items];
        newItems.splice(idx, 1);
        setFormData({ ...formData, items: newItems });
    };

    if (!hallId) {
        return <div className="p-8 text-center text-zinc-500">No Hall Assigned</div>;
    }

    return (
        <div className="max-w-7xl mx-auto">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Inspection Templates</h1>
                    <p className="text-zinc-400 mt-1">Manage room inspection checklists.</p>
                </div>
                <button
                    onClick={openCreate}
                    className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    New Template
                </button>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {templates.map((template) => (
                        <div key={template.id} className="bg-zinc-900 border border-white/5 rounded-2xl p-6 group hover:border-white/10 transition-all flex flex-col">
                            <div className="flex justify-between items-start mb-4">
                                <div className="w-10 h-10 rounded-lg bg-zinc-800 flex items-center justify-center">
                                    <ClipboardCheck className="w-5 h-5 text-zinc-400" />
                                </div>
                                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                    <button onClick={() => openEdit(template)} className="p-2 hover:bg-white/10 rounded-lg text-zinc-400 hover:text-white">
                                        <Edit2 className="w-4 h-4" />
                                    </button>
                                    <button onClick={() => deleteTemplate(template.id)} className="p-2 hover:bg-red-500/10 rounded-lg text-zinc-400 hover:text-red-400">
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                            </div>

                            <h3 className="text-lg font-bold text-white mb-2">{template.name}</h3>

                            <div className="flex-1 bg-zinc-950/50 rounded-lg p-3 border border-white/5 overflow-y-auto max-h-48">
                                <ul className="space-y-2">
                                    {template.items.map((item, i) => (
                                        <li key={i} className="text-sm text-zinc-400 flex items-start gap-2">
                                            <span className="w-1.5 h-1.5 bg-zinc-600 rounded-full mt-1.5 flex-shrink-0" />
                                            <span>{item}</span>
                                        </li>
                                    ))}
                                </ul>
                            </div>
                            <div className="mt-4 text-xs text-zinc-500 font-mono">
                                ID: {template.id}
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
                        <h2 className="text-xl font-bold text-white mb-4">{editingId ? 'Edit Template' : 'New Template'}</h2>
                        <form onSubmit={handleSubmit} className="space-y-6">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Template Name</label>
                                <input
                                    type="text"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="e.g. Weekly Room Inspection"
                                    required
                                />
                            </div>

                            <div>
                                <div className="flex justify-between items-center mb-2">
                                    <label className="block text-sm font-medium text-zinc-400">Checklist Items</label>
                                    <button type="button" onClick={addItem} className="text-xs text-purple-400 hover:text-purple-300 font-medium">
                                        + Add Item
                                    </button>
                                </div>
                                <div className="space-y-2">
                                    {formData.items.map((item, idx) => (
                                        <div key={idx} className="flex gap-2">
                                            <input
                                                type="text"
                                                value={item}
                                                onChange={(e) => handleItemChange(idx, e.target.value)}
                                                className="flex-1 px-3 py-2 bg-zinc-800 border border-white/10 rounded-lg text-white text-sm focus:outline-none focus:ring-1 focus:ring-purple-500/50"
                                                placeholder={`Item ${idx + 1}`}
                                            />
                                            <button
                                                type="button"
                                                onClick={() => removeItem(idx)}
                                                className="p-2 hover:bg-red-500/10 text-zinc-500 hover:text-red-400 rounded-lg"
                                                disabled={formData.items.length === 1}
                                            >
                                                <X className="w-4 h-4" />
                                            </button>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            <div className="flex justify-end gap-2 pt-4 border-t border-white/5">
                                <button
                                    type="button"
                                    onClick={closeModal}
                                    className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium"
                                >
                                    Save Template
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
