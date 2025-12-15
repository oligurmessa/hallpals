"use client";

import React, { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useDoc, DocEntry } from "@/hooks/useDocs";
import { ArrowLeft, Save, Plus, Trash2, GripVertical } from "lucide-react";

export default function HandbookDetailPage() {
    const { slug } = useParams() as { slug: string };
    const router = useRouter();
    const { docMeta, entries, loading, updateEntry, addEntry, deleteEntry } = useDoc(slug);

    const [isAddOpen, setIsAddOpen] = useState(false);
    const [newEntryData, setNewEntryData] = useState({ section: "General", text: "" });

    if (loading) {
        return (
            <div className="flex justify-center py-20">
                <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
            </div>
        );
    }

    if (!docMeta) {
        return (
            <div className="text-center py-20">
                <h2 className="text-xl text-white">Document not found</h2>
                <button onClick={() => router.back()} className="text-purple-400 mt-4">Go Back</button>
            </div>
        );
    }

    // Group entries by Section (if you want grouped view) or just flat list
    // The iOS app groups by Section. Let's do a flat list for editing simplicity, referencing sections.

    const handleAdd = async () => {
        await addEntry(newEntryData.section, newEntryData.text);
        setNewEntryData({ section: "General", text: "" });
        setIsAddOpen(false);
    };

    return (
        <div className="max-w-5xl mx-auto pb-20">
            <div className="flex items-center gap-4 mb-6">
                <button
                    onClick={() => router.back()}
                    className="p-2 hover:bg-white/5 rounded-lg text-zinc-400 hover:text-white transition-colors"
                >
                    <ArrowLeft className="w-5 h-5" />
                </button>
                <div>
                    <h1 className="text-2xl font-bold text-white">{docMeta.title}</h1>
                    <div className="flex items-center gap-2 mt-1">
                        <span className="text-sm text-zinc-500 uppercase tracking-wider">{docMeta.category}</span>
                        <span className="w-1 h-1 bg-zinc-700 rounded-full" />
                        <span className={`text-xs px-2 py-0.5 rounded-full ${docMeta.isPublished ? 'bg-emerald-500/10 text-emerald-400' : 'bg-yellow-500/10 text-yellow-400'}`}>
                            {docMeta.isPublished ? "Published" : "Draft"}
                        </span>
                    </div>
                </div>
            </div>

            <div className="space-y-6">
                {entries.length === 0 ? (
                    <div className="p-10 border border-dashed border-white/10 rounded-2xl text-center">
                        <p className="text-zinc-500">No content yet.</p>
                        <button onClick={() => setIsAddOpen(true)} className="text-purple-400 font-medium mt-2">Add First Entry</button>
                    </div>
                ) : (
                    entries.map((entry) => (
                        <EntryEditor
                            key={entry.id}
                            entry={entry}
                            onUpdate={updateEntry}
                            onDelete={deleteEntry}
                        />
                    ))
                )}

                <button
                    onClick={() => setIsAddOpen(true)}
                    className="w-full py-4 border border-dashed border-white/10 rounded-xl text-zinc-500 hover:text-white hover:bg-white/5 hover:border-purple-500/30 transition-all flex items-center justify-center gap-2"
                >
                    <Plus className="w-5 h-5" />
                    Add New Entry
                </button>
            </div>

            {isAddOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-2xl shadow-2xl">
                        <h2 className="text-lg font-bold text-white mb-4">Add Content Entry</h2>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Section Header (Optional)</label>
                                <input
                                    type="text"
                                    value={newEntryData.section}
                                    onChange={(e) => setNewEntryData({ ...newEntryData, section: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="e.g. General, Procedures"
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Content</label>
                                <textarea
                                    rows={6}
                                    value={newEntryData.text}
                                    onChange={(e) => setNewEntryData({ ...newEntryData, text: e.target.value })}
                                    className="w-full px-4 py-3 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="Type content here..."
                                />
                            </div>
                        </div>

                        <div className="flex justify-end gap-2 mt-6">
                            <button
                                onClick={() => setIsAddOpen(false)}
                                className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleAdd}
                                disabled={!newEntryData.text}
                                className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium disabled:opacity-50"
                            >
                                Add Entry
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

function EntryEditor({ entry, onUpdate, onDelete }: {
    entry: DocEntry,
    onUpdate: (id: string, text: string) => Promise<void>,
    onDelete: (id: string) => Promise<void>
}) {
    const [isEditing, setIsEditing] = useState(false);
    const [localText, setLocalText] = useState(entry.text);
    const [saving, setSaving] = useState(false);

    const handleSave = async () => {
        setSaving(true);
        await onUpdate(entry.id, localText);
        setSaving(false);
        setIsEditing(false);
    };

    return (
        <div className="bg-zinc-900/50 border border-white/5 rounded-xl p-4 group hover:border-white/10 transition-colors">
            <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-purple-400 uppercase tracking-widest">{entry.section}</span>

                <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    {!isEditing && (
                        <>
                            <button onClick={() => setIsEditing(true)} className="p-1.5 hover:bg-white/10 rounded-lg text-zinc-400 hover:text-white">
                                <span className="text-xs">Edit</span>
                            </button>
                            <button onClick={() => confirm("Delete entry?") && onDelete(entry.id)} className="p-1.5 hover:bg-red-500/10 rounded-lg text-zinc-400 hover:text-red-400">
                                <Trash2 className="w-4 h-4" />
                            </button>
                        </>
                    )}
                </div>
            </div>

            {isEditing ? (
                <div className="space-y-3">
                    <textarea
                        value={localText}
                        onChange={(e) => setLocalText(e.target.value)}
                        className="w-full bg-zinc-950 border border-white/10 rounded-lg p-3 text-white text-sm focus:outline-none focus:ring-1 focus:ring-purple-500/50 min-h-[100px]"
                    />
                    <div className="flex justify-end gap-2">
                        <button onClick={() => { setLocalText(entry.text); setIsEditing(false); }} className="text-xs text-zinc-500 hover:text-white px-3 py-2">
                            Cancel
                        </button>
                        <button onClick={handleSave} disabled={saving} className="bg-purple-600 hover:bg-purple-500 text-white text-xs px-3 py-2 rounded-lg font-medium flex items-center gap-2">
                            {saving ? "Saving..." : "Save Changes"}
                        </button>
                    </div>
                </div>
            ) : (
                <div className="prose prose-invert max-w-none text-zinc-300 text-sm whitespace-pre-wrap">
                    {entry.text}
                </div>
            )}
        </div>
    );
}
