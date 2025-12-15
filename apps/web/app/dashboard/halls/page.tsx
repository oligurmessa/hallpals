"use client";

import React, { useState } from "react";
import { useHalls, Hall } from "@/hooks/useHalls";
import { Building2, Plus, Edit2, CheckCircle, XCircle } from "lucide-react";

import { useRouter } from "next/navigation";

export default function HallsPage() {
    const router = useRouter();
    const { halls, loading, createHall, updateHall } = useHalls();
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [currentHall, setCurrentHall] = useState<Partial<Hall>>({
        name: "",
        shortName: "",
        floors: [1, 2, 3],
        isActive: true
    });
    const [editingId, setEditingId] = useState<string | null>(null);

    // UI State for floors
    const [tempFloorCount, setTempFloorCount] = useState(3);
    const [hasBasement, setHasBasement] = useState(false);
    const [isSubmitting, setIsSubmitting] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsSubmitting(true);

        try {
            // Generate floors array
            let floors: number[] = [];
            if (hasBasement) {
                // If basement, 0 represents B, then 1 to count-1
                // e.g. Count 5 + B = [0, 1, 2, 3, 4] where 0 is displayed as B
                // But usually Basement is an ADDITION to total floors.
                // Assumption: User enters "Number of Levels".
                // If 6 levels and has basement: 0, 1, 2, 3, 4, 5
                for (let i = 0; i < tempFloorCount; i++) {
                    floors.push(i);
                }
            } else {
                // 1 to count
                for (let i = 1; i <= tempFloorCount; i++) {
                    floors.push(i);
                }
            }

            const hallData = { ...currentHall, floors };

            if (editingId) {
                await updateHall(editingId, hallData);
            } else {
                // Simple slug generation for ID if not editing
                const id = currentHall.name?.toLowerCase().replace(/[^a-z0-9]/g, "-") || "new-hall";
                await createHall(id, hallData as any);
            }
            closeModal();
        } catch (error: any) {
            console.error("Failed to save hall:", error);
            alert(`Error: ${error.message || "Unknown error"}`);
        } finally {
            setIsSubmitting(false);
        }
    };

    const openCreate = () => {
        setEditingId(null);
        setCurrentHall({ name: "", shortName: "", floors: [1, 2, 3], isActive: true });
        setTempFloorCount(3);
        setHasBasement(false);
        setIsModalOpen(true);
    };

    const openEdit = (hall: Hall) => {
        setEditingId(hall.id);
        setCurrentHall(hall);

        // Infer UI state from hall data
        const floors = hall.floors || [];
        const hasZero = floors.includes(0);
        setHasBasement(hasZero);
        setTempFloorCount(floors.length);

        setIsModalOpen(true);
    };

    const closeModal = () => {
        setIsModalOpen(false);
        setEditingId(null);
    }

    const handleFloorsChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const val = e.target.value;
        const floors = val.split(',').map(n => parseInt(n.trim())).filter(n => !isNaN(n));
        setCurrentHall({ ...currentHall, floors });
    };

    return (
        <div className="max-w-7xl mx-auto">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Residence Halls</h1>
                    <p className="text-zinc-400 mt-1">Manage buildings and active status.</p>
                </div>
                <button
                    onClick={openCreate}
                    className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    Add Hall
                </button>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {halls.map((hall) => (
                        <div
                            key={hall.id}
                            onClick={(e) => {
                                // Prevent navigation if clicking edit button
                                if ((e.target as HTMLElement).closest('button')) return;
                                router.push(`/dashboard/halls/${hall.id}`);
                            }}
                            className="bg-zinc-900 border border-white/5 rounded-2xl p-6 relative overflow-hidden group hover:border-purple-500/30 transition-all cursor-pointer"
                        >
                            <div className="flex justify-between items-start mb-4">
                                <div className="w-12 h-12 rounded-xl bg-zinc-800 flex items-center justify-center">
                                    <Building2 className="w-6 h-6 text-zinc-400" />
                                </div>
                                <button onClick={(e) => { e.stopPropagation(); openEdit(hall); }} className="p-2 bg-zinc-800 rounded-lg text-zinc-400 hover:text-white transition-colors z-10">
                                    <Edit2 className="w-4 h-4" />
                                </button>
                            </div>

                            <h3 className="text-xl font-bold text-white mb-1">{hall.name}</h3>
                            <div className="flex items-center gap-2 mb-4">
                                <span className="text-sm text-zinc-500 font-mono bg-zinc-800 px-2 py-0.5 rounded">{hall.shortName}</span>
                                <span className={`text-xs px-2 py-0.5 rounded-full flex items-center gap-1 ${hall.isActive ? 'bg-emerald-500/10 text-emerald-400' : 'bg-red-500/10 text-red-400'}`}>
                                    {hall.isActive ? <CheckCircle className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                                    {hall.isActive ? 'Active' : 'Inactive'}
                                </span>
                            </div>

                            <div className="border-t border-white/5 pt-4 text-sm text-zinc-400">
                                <p><span className="text-zinc-500">Floors:</span> {hall.floors?.join(", ") || "None"}</p>
                                <p className="mt-1"><span className="text-zinc-500">ID:</span> {hall.id}</p>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
                        <h2 className="text-xl font-bold text-white mb-4">{editingId ? 'Edit Hall' : 'Add New Hall'}</h2>
                        <form onSubmit={handleSubmit} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Hall Name</label>
                                <input
                                    type="text"
                                    value={currentHall.name}
                                    onChange={(e) => setCurrentHall({ ...currentHall, name: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                    disabled={isSubmitting}
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Short Name (Abbr)</label>
                                <input
                                    type="text"
                                    value={currentHall.shortName}
                                    onChange={(e) => setCurrentHall({ ...currentHall, shortName: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="e.g. TLH"
                                    required
                                    disabled={isSubmitting}
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Total Floors (Levels)</label>
                                <div className="flex gap-4">
                                    <input
                                        type="number"
                                        min="1"
                                        value={tempFloorCount}
                                        onChange={(e) => setTempFloorCount(parseInt(e.target.value) || 1)}
                                        className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                        placeholder="e.g. 4"
                                        disabled={isSubmitting}
                                    />
                                    <div className="flex items-center gap-2 min-w-max px-4 border border-white/10 rounded-xl bg-zinc-800/50">
                                        <input
                                            type="checkbox"
                                            checked={hasBasement}
                                            onChange={(e) => setHasBasement(e.target.checked)}
                                            className="w-4 h-4 rounded border-zinc-600 bg-zinc-800 text-purple-600 focus:ring-purple-500"
                                            id="hasBasement"
                                            disabled={isSubmitting}
                                        />
                                        <label htmlFor="hasBasement" className="text-sm text-zinc-300">Include Basement (B)</label>
                                    </div>
                                </div>
                                <p className="text-xs text-zinc-500 mt-1">
                                    Generates floor numbers: {hasBasement ? '0 (B), ' : ''}1, 2... {hasBasement ? tempFloorCount - 1 : tempFloorCount}
                                </p>
                            </div>

                            <div className="flex items-center gap-2">
                                <input
                                    type="checkbox"
                                    checked={currentHall.isActive}
                                    onChange={(e) => setCurrentHall({ ...currentHall, isActive: e.target.checked })}
                                    className="w-4 h-4 rounded border-zinc-600 bg-zinc-800 text-purple-600 focus:ring-purple-500"
                                    id="isActive"
                                    disabled={isSubmitting}
                                />
                                <label htmlFor="isActive" className="text-sm text-zinc-300">Active Hall</label>
                            </div>

                            <div className="flex justify-end gap-2 mt-6">
                                <button
                                    type="button"
                                    onClick={closeModal}
                                    className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                                    disabled={isSubmitting}
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium flex items-center gap-2"
                                    disabled={isSubmitting}
                                >
                                    {isSubmitting && <div className="w-4 h-4 border-2 border-white/50 border-t-white rounded-full animate-spin" />}
                                    {editingId ? 'Update Hall' : 'Create Hall'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
