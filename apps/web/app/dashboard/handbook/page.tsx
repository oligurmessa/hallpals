"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { Link as LinkIcon, Search, Plus, Book, Upload, Sparkles, Pencil } from "lucide-react";
import { useDocs, DocMeta } from "@/hooks/useDocs";
import { doc, writeBatch, collection } from "firebase/firestore";
import { db } from "@/lib/firebase";
import AIChatModal from "@/components/AIChatModal";

export default function HandbookPage() {
    const router = useRouter();
    const { docs, loading, createDoc, updateDocMeta } = useDocs();
    const [search, setSearch] = useState("");
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isAIChatOpen, setIsAIChatOpen] = useState(false);
    const [importing, setImporting] = useState(false);
    const [editingDoc, setEditingDoc] = useState<DocMeta | null>(null);

    const [formData, setFormData] = useState({
        title: "",
        category: "General"
    });

    const filteredDocs = docs.filter(d =>
        d.title.toLowerCase().includes(search.toLowerCase()) ||
        d.category.toLowerCase().includes(search.toLowerCase())
    );

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            if (editingDoc) {
                // Update existing doc
                await updateDocMeta(editingDoc.id, {
                    title: formData.title,
                    category: formData.category
                });
            } else {
                // Create new doc - generate slug from title
                const slug = formData.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
                await createDoc(slug, {
                    title: formData.title,
                    category: formData.category,
                    isPublished: false
                });
            }
            closeModal();
        } catch (err) {
            alert("Error saving doc: " + err);
        }
    };

    const closeModal = () => {
        setIsModalOpen(false);
        setEditingDoc(null);
        setFormData({ title: "", category: "General" });
    };

    const openEditModal = (docToEdit: DocMeta, e: React.MouseEvent) => {
        e.stopPropagation(); // Prevent navigation to doc detail
        setEditingDoc(docToEdit);
        setFormData({
            title: docToEdit.title,
            category: docToEdit.category
        });
        setIsModalOpen(true);
    };

    const openCreateModal = () => {
        setEditingDoc(null);
        setFormData({ title: "", category: "General" });
        setIsModalOpen(true);
    };

    const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setImporting(true);
        try {
            const text = await file.text();
            const data = JSON.parse(text);

            if (!Array.isArray(data)) {
                alert("Invalid JSON format. Expected an array of documents.");
                return;
            }

            const batch = writeBatch(db);
            let opCount = 0;

            // Process each document in the array
            for (const item of data) {
                if (!item.slug || !item.title) continue;

                // 1. Set Document Metadata
                // Use item.slug as the document ID
                const docRef = doc(db, "docs", item.slug);
                batch.set(docRef, {
                    title: item.title,
                    slug: item.slug,
                    category: item.category || "General",
                    isPublished: true,
                    updatedAt: new Date(),
                    updatedBy: "import"
                });
                opCount++;

                // 2. Set Entries
                if (item.entries && Array.isArray(item.entries)) {
                    for (const entry of item.entries) {
                        // Generate a new ID for the entry or use provided ID if available
                        const entryRef = doc(collection(db, "docs", item.slug, "entries"));
                        batch.set(entryRef, {
                            section: entry.section || "General",
                            text: entry.text || "",
                            order: entry.order || 0,
                            topic: item.title, // Use doc title as topic fallback
                            updatedAt: new Date(),
                            updatedBy: "import"
                        });
                        opCount++;
                    }
                }
            }

            await batch.commit();
            alert(`Successfully imported ${data.length} documents.`);
            // Trigger re-fetch if needed, but real-time hook should handle it
        } catch (err) {
            console.error("Import error:", err);
            alert("Failed to import JSON. Check console for details.");
        } finally {
            setImporting(false);
            // clear input
            e.target.value = "";
        }
    };

    return (
        <div className="max-w-7xl mx-auto">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Handbook</h1>
                    <p className="text-zinc-400 mt-1">Manage global knowledge base and policies.</p>
                </div>

                <div className="flex gap-3">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                        <input
                            type="text"
                            placeholder="Search docs..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            className="pl-9 pr-4 py-2 bg-zinc-900 border border-white/10 rounded-xl text-sm text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50 w-full md:w-64"
                        />
                    </div>

                    <label className={`flex items-center gap-2 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-sm font-medium transition-colors cursor-pointer ${importing ? "opacity-50 pointer-events-none" : ""}`}>
                        <Upload className="w-4 h-4" />
                        {importing ? "Importing..." : "Import JSON"}
                        <input type="file" accept=".json" className="hidden" onChange={handleFileUpload} />
                    </label>

                    <button
                        onClick={() => setIsAIChatOpen(true)}
                        className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-sm font-medium transition-colors shadow-lg shadow-indigo-500/20"
                    >
                        <Sparkles className="w-4 h-4" />
                        Ask AI
                    </button>

                    <button
                        onClick={openCreateModal}
                        className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                    >
                        <Plus className="w-4 h-4" />
                        Create Doc
                    </button>
                </div>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {filteredDocs.map((docItem) => (
                        <div
                            key={docItem.id}
                            onClick={() => router.push(`/dashboard/handbook/${docItem.id}`)}
                            className="bg-zinc-900 border border-white/5 rounded-2xl p-6 hover:border-white/10 transition-all cursor-pointer group hover:-translate-y-1 relative"
                        >
                            <div className="flex justify-between items-start mb-4">
                                <div className="w-10 h-10 rounded-lg bg-purple-500/10 text-purple-400 flex items-center justify-center">
                                    <Book className="w-5 h-5" />
                                </div>
                                <div className="flex items-center gap-2">
                                    <button
                                        onClick={(e) => openEditModal(docItem, e)}
                                        className="p-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-400 hover:text-white transition-colors opacity-0 group-hover:opacity-100"
                                        title="Edit doc info"
                                    >
                                        <Pencil className="w-3.5 h-3.5" />
                                    </button>
                                    <span className={`text-xs px-2 py-1 rounded-full ${docItem.isPublished ? 'bg-emerald-500/10 text-emerald-400' : 'bg-zinc-800 text-zinc-400'}`}>
                                        {docItem.category}
                                    </span>
                                </div>
                            </div>

                            <h3 className="text-lg font-bold text-white mb-2 group-hover:text-purple-400 transition-colors">
                                {docItem.title}
                            </h3>
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-2 text-xs text-zinc-500 font-mono">
                                    <LinkIcon className="w-3 h-3" />
                                    <span>/{docItem.title.toLowerCase().replace(/[^a-z0-9]+/g, '-')}</span>
                                </div>
                                <span className={`text-xs px-2 py-0.5 rounded-full ${docItem.isPublished ? 'bg-emerald-500/10 text-emerald-400' : 'bg-yellow-500/10 text-yellow-400'}`}>
                                    {docItem.isPublished ? "Published" : "Draft"}
                                </span>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
                        <h2 className="text-xl font-bold text-white mb-4">
                            {editingDoc ? "Edit Document" : "Create New Document"}
                        </h2>
                        <form onSubmit={handleSubmit} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Title</label>
                                <input
                                    type="text"
                                    value={formData.title}
                                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    placeholder="Enter document title"
                                    required
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Category</label>
                                <select
                                    value={formData.category}
                                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                >
                                    <option value="General">General</option>
                                    <option value="Procedures">Procedures</option>
                                    <option value="Policies">Policies</option>
                                    <option value="Emergency">Emergency</option>
                                    <option value="Housing">Housing</option>
                                </select>
                            </div>

                            <div className="flex justify-end gap-2 mt-6">
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
                                    {editingDoc ? "Save Changes" : "Create Doc"}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
            <AIChatModal isOpen={isAIChatOpen} onClose={() => setIsAIChatOpen(false)} />
        </div>
    );
}
