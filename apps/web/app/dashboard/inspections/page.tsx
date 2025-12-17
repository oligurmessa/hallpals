"use client";

import React, { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useInspectionTemplates, InspectionTemplate } from "@/hooks/useInspectionTemplates";
import { useInspectionRounds, InspectionRound } from "@/hooks/useInspectionRounds";
import { useRoster } from "@/hooks/useRoster";
import { Plus, ClipboardCheck, Edit2, Trash2, X, Calendar, CheckCircle, Home } from "lucide-react";

export default function InspectionsPage() {
    const { profile } = useAuth();
    const hallId = profile?.hallId;
    const { templates, loading: templatesLoading, addTemplate, updateTemplate, deleteTemplate } = useInspectionTemplates(hallId);
    const { rounds, activeRounds, loading: roundsLoading, createRound, deleteRound } = useInspectionRounds(hallId);
    const { residents: roster } = useRoster(hallId);

    // Template modal state
    const [isTemplateModalOpen, setIsTemplateModalOpen] = useState(false);
    const [editingId, setEditingId] = useState<string | null>(null);
    const [templateForm, setTemplateForm] = useState<{ name: string, items: string[] }>({
        name: "",
        items: [""]
    });

    // Round modal state
    const [isRoundModalOpen, setIsRoundModalOpen] = useState(false);
    const [roundForm, setRoundForm] = useState({
        name: "",
        templateId: "",
        dueDate: "",
        roomNumbers: ""
    });

    // Tab state
    const [activeTab, setActiveTab] = useState<'rounds' | 'templates'>('rounds');

    // Get unique room numbers from roster
    const availableRooms = [...new Set((roster || []).map(r => r.roomNumber).filter(Boolean))].sort();

    // Template handlers
    const handleTemplateSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const cleanedItems = templateForm.items.filter(i => i.trim() !== "");
        if (cleanedItems.length === 0) {
            alert("Please add at least one inspection item.");
            return;
        }

        if (editingId) {
            await updateTemplate(editingId, { name: templateForm.name, items: cleanedItems });
        } else {
            await addTemplate({ name: templateForm.name, items: cleanedItems });
        }
        closeTemplateModal();
    };

    const openCreateTemplate = () => {
        setEditingId(null);
        setTemplateForm({ name: "", items: ["Check for damage", "Check cleanliness", "Verify furniture"] });
        setIsTemplateModalOpen(true);
    };

    const openEditTemplate = (t: InspectionTemplate) => {
        setEditingId(t.id);
        setTemplateForm({ name: t.name, items: t.items });
        setIsTemplateModalOpen(true);
    };

    const closeTemplateModal = () => {
        setIsTemplateModalOpen(false);
        setEditingId(null);
    };

    const handleItemChange = (idx: number, val: string) => {
        const newItems = [...templateForm.items];
        newItems[idx] = val;
        setTemplateForm({ ...templateForm, items: newItems });
    };

    const addItem = () => {
        setTemplateForm({ ...templateForm, items: [...templateForm.items, ""] });
    };

    const removeItem = (idx: number) => {
        const newItems = [...templateForm.items];
        newItems.splice(idx, 1);
        setTemplateForm({ ...templateForm, items: newItems });
    };

    // Round handlers
    const handleRoundSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        const roomNumbers = roundForm.roomNumbers
            .split(/[,\n]/)
            .map(r => r.trim())
            .filter(r => r !== "");

        if (roomNumbers.length === 0) {
            alert("Please enter at least one room number.");
            return;
        }

        if (!roundForm.templateId) {
            alert("Please select a template.");
            return;
        }

        try {
            await createRound({
                name: roundForm.name,
                templateId: roundForm.templateId,
                dueDate: roundForm.dueDate,
                roomNumbers
            });
            closeRoundModal();
        } catch (error) {
            console.error("Error creating round:", error);
            alert("Failed to create inspection round");
        }
    };

    const openCreateRound = () => {
        const nextWeek = new Date();
        nextWeek.setDate(nextWeek.getDate() + 7);
        setRoundForm({
            name: "",
            templateId: templates[0]?.id || "",
            dueDate: nextWeek.toISOString().split('T')[0],
            roomNumbers: availableRooms.join(", ")
        });
        setIsRoundModalOpen(true);
    };

    const closeRoundModal = () => {
        setIsRoundModalOpen(false);
    };

    if (!hallId) {
        return <div className="p-8 text-center text-zinc-500">No Hall Assigned</div>;
    }

    const loading = templatesLoading || roundsLoading;

    return (
        <div className="max-w-7xl mx-auto">
            {/* Header */}
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Room Inspections</h1>
                    <p className="text-zinc-400 mt-1">Create and manage inspection rounds for RAs.</p>
                </div>
                <button
                    onClick={activeTab === 'rounds' ? openCreateRound : openCreateTemplate}
                    disabled={activeTab === 'rounds' && templates.length === 0}
                    className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 disabled:bg-zinc-700 disabled:cursor-not-allowed text-white rounded-xl text-sm font-medium transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    {activeTab === 'rounds' ? 'New Round' : 'New Template'}
                </button>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 mb-6">
                <button
                    onClick={() => setActiveTab('rounds')}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${activeTab === 'rounds'
                        ? 'bg-purple-600 text-white'
                        : 'bg-zinc-800 text-zinc-400 hover:text-white'
                        }`}
                >
                    <div className="flex items-center gap-2">
                        <ClipboardCheck className="w-4 h-4" />
                        Inspection Rounds
                        {activeRounds.length > 0 && (
                            <span className="px-1.5 py-0.5 bg-white/20 rounded text-xs">
                                {activeRounds.length}
                            </span>
                        )}
                    </div>
                </button>
                <button
                    onClick={() => setActiveTab('templates')}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${activeTab === 'templates'
                        ? 'bg-purple-600 text-white'
                        : 'bg-zinc-800 text-zinc-400 hover:text-white'
                        }`}
                >
                    <div className="flex items-center gap-2">
                        <Edit2 className="w-4 h-4" />
                        Templates
                    </div>
                </button>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : activeTab === 'rounds' ? (
                // ROUNDS TAB
                <div>
                    {templates.length === 0 ? (
                        <div className="bg-zinc-900 border border-white/5 rounded-2xl p-12 text-center">
                            <ClipboardCheck className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
                            <h3 className="text-lg font-bold text-white mb-2">No Templates Yet</h3>
                            <p className="text-zinc-400 mb-4">Create a template first before scheduling inspection rounds.</p>
                            <button
                                onClick={() => setActiveTab('templates')}
                                className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-lg text-sm font-medium"
                            >
                                Create Template
                            </button>
                        </div>
                    ) : rounds.length === 0 ? (
                        <div className="bg-zinc-900 border border-white/5 rounded-2xl p-12 text-center">
                            <Calendar className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
                            <h3 className="text-lg font-bold text-white mb-2">No Inspection Rounds</h3>
                            <p className="text-zinc-400 mb-4">Create your first inspection round to assign rooms to RAs.</p>
                            <button
                                onClick={openCreateRound}
                                className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-lg text-sm font-medium"
                            >
                                Create Round
                            </button>
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {rounds.map((round) => (
                                <RoundCard
                                    key={round.id}
                                    round={round}
                                    onDelete={() => deleteRound(round.id)}
                                />
                            ))}
                        </div>
                    )}
                </div>
            ) : (
                // TEMPLATES TAB
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {templates.map((template) => (
                        <div key={template.id} className="bg-zinc-900 border border-white/5 rounded-2xl p-6 group hover:border-white/10 transition-all flex flex-col">
                            <div className="flex justify-between items-start mb-4">
                                <div className="w-10 h-10 rounded-lg bg-zinc-800 flex items-center justify-center">
                                    <ClipboardCheck className="w-5 h-5 text-zinc-400" />
                                </div>
                                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                    <button onClick={() => openEditTemplate(template)} className="p-2 hover:bg-white/10 rounded-lg text-zinc-400 hover:text-white">
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
                            <div className="mt-4 text-xs text-zinc-500">
                                {template.items.length} items
                            </div>
                        </div>
                    ))}
                    {templates.length === 0 && (
                        <div className="col-span-full bg-zinc-900 border border-white/5 rounded-2xl p-12 text-center">
                            <ClipboardCheck className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
                            <h3 className="text-lg font-bold text-white mb-2">No Templates Yet</h3>
                            <p className="text-zinc-400 mb-4">Create your first inspection template.</p>
                            <button
                                onClick={openCreateTemplate}
                                className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-lg text-sm font-medium"
                            >
                                Create Template
                            </button>
                        </div>
                    )}
                </div>
            )}

            {/* Template Modal */}
            {isTemplateModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
                        <h2 className="text-xl font-bold text-white mb-4">{editingId ? 'Edit Template' : 'New Template'}</h2>
                        <form onSubmit={handleTemplateSubmit} className="space-y-6">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Template Name</label>
                                <input
                                    type="text"
                                    value={templateForm.name}
                                    onChange={(e) => setTemplateForm({ ...templateForm, name: e.target.value })}
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
                                    {templateForm.items.map((item, idx) => (
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
                                                disabled={templateForm.items.length === 1}
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
                                    onClick={closeTemplateModal}
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

            {/* Round Modal */}
            {isRoundModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
                        <h2 className="text-xl font-bold text-white mb-4">New Inspection Round</h2>
                        <form onSubmit={handleRoundSubmit} className="space-y-6">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Round Name</label>
                                <input
                                    type="text"
                                    value={roundForm.name}
                                    onChange={(e) => setRoundForm({ ...roundForm, name: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="e.g. Week 15 Health & Safety"
                                    required
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Template</label>
                                <select
                                    value={roundForm.templateId}
                                    onChange={(e) => setRoundForm({ ...roundForm, templateId: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                >
                                    <option value="">Select a template...</option>
                                    {templates.map((t) => (
                                        <option key={t.id} value={t.id}>{t.name}</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Due Date</label>
                                <input
                                    type="date"
                                    value={roundForm.dueDate}
                                    onChange={(e) => setRoundForm({ ...roundForm, dueDate: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">
                                    Room Numbers
                                    {availableRooms.length > 0 && (
                                        <span className="text-zinc-500 font-normal ml-2">
                                            ({availableRooms.length} from roster)
                                        </span>
                                    )}
                                </label>
                                <textarea
                                    value={roundForm.roomNumbers}
                                    onChange={(e) => setRoundForm({ ...roundForm, roomNumbers: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50 h-24"
                                    placeholder="101, 102, 103, 104..."
                                    required
                                />
                                <p className="text-xs text-zinc-500 mt-1">Separate room numbers with commas or new lines</p>
                            </div>

                            <div className="flex justify-end gap-2 pt-4 border-t border-white/5">
                                <button
                                    type="button"
                                    onClick={closeRoundModal}
                                    className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium"
                                >
                                    Create Round
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

// Round Card Component
function RoundCard({ round, onDelete }: { round: InspectionRound; onDelete: () => void }) {
    const completedRooms = round.rooms.filter(r => r.status === 'completed').length;
    const totalRooms = round.rooms.length;
    const progress = totalRooms > 0 ? (completedRooms / totalRooms) * 100 : 0;
    const isOverdue = new Date(round.dueDate) < new Date() && round.status === 'active';

    return (
        <div className="bg-zinc-900 border border-white/5 rounded-2xl p-6 hover:border-white/10 transition-all">
            <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${round.status === 'completed' ? 'bg-green-500/20' : isOverdue ? 'bg-red-500/20' : 'bg-purple-500/20'
                        }`}>
                        {round.status === 'completed' ? (
                            <CheckCircle className="w-5 h-5 text-green-400" />
                        ) : (
                            <ClipboardCheck className={`w-5 h-5 ${isOverdue ? 'text-red-400' : 'text-purple-400'}`} />
                        )}
                    </div>
                    <div>
                        <h3 className="text-lg font-bold text-white">{round.name}</h3>
                        <p className="text-sm text-zinc-500">Template: {round.templateName || 'Unknown'}</p>
                    </div>
                </div>
                <button
                    onClick={onDelete}
                    className="p-2 hover:bg-red-500/10 rounded-lg text-zinc-500 hover:text-red-400 transition-colors"
                >
                    <Trash2 className="w-4 h-4" />
                </button>
            </div>

            {/* Progress Bar */}
            <div className="mb-4">
                <div className="flex justify-between text-sm mb-1">
                    <span className="text-zinc-400">Progress</span>
                    <span className="text-white font-medium">{completedRooms}/{totalRooms} rooms</span>
                </div>
                <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
                    <div
                        className={`h-full transition-all ${round.status === 'completed' ? 'bg-green-500' : 'bg-purple-500'
                            }`}
                        style={{ width: `${progress}%` }}
                    />
                </div>
            </div>

            {/* Details Row */}
            <div className="flex items-center gap-4 text-sm">
                <div className={`flex items-center gap-1.5 ${isOverdue ? 'text-red-400' : 'text-zinc-400'}`}>
                    <Calendar className="w-4 h-4" />
                    <span>Due: {new Date(round.dueDate).toLocaleDateString()}</span>
                </div>
                <div className="flex items-center gap-1.5 text-zinc-400">
                    <Home className="w-4 h-4" />
                    <span>{totalRooms} rooms</span>
                </div>
                {round.status === 'completed' && (
                    <span className="px-2 py-0.5 bg-green-500/20 text-green-400 rounded text-xs font-medium">
                        Completed
                    </span>
                )}
                {isOverdue && (
                    <span className="px-2 py-0.5 bg-red-500/20 text-red-400 rounded text-xs font-medium">
                        Overdue
                    </span>
                )}
            </div>
        </div>
    );
}
