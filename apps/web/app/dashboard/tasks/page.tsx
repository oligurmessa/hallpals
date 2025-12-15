"use client";

import React, { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useTasks, BulletinTask } from "@/hooks/useTasks";
import { Search, Plus, ListTodo, Calendar, User, Clock, CheckCircle } from "lucide-react";

export default function TasksPage() {
    const { profile } = useAuth();
    const hallId = profile?.hallId;
    const { tasks, loading, addTask, updateTask, deleteTask } = useTasks(hallId);
    const [isModalOpen, setIsModalOpen] = useState(false);

    const [formData, setFormData] = useState<Partial<BulletinTask>>({
        title: "",
        description: "",
        assignee: "",
        deadline: "",
        priority: "medium",
        status: "pending"
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        await addTask(formData as any);
        closeModal();
    };

    const closeModal = () => {
        setIsModalOpen(false);
        setFormData({ title: "", description: "", assignee: "", deadline: "", priority: "medium", status: "pending" });
    }

    if (!hallId) {
        return <div className="p-8 text-center text-zinc-500">No Hall Assigned</div>;
    }

    return (
        <div className="max-w-7xl mx-auto">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Bulletin & Tasks</h1>
                    <p className="text-zinc-400 mt-1">Manage team assignments and bulletin board.</p>
                </div>
                <button
                    onClick={() => setIsModalOpen(true)}
                    className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    Create Task
                </button>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {/* Kanban-ish columns or just a grid? Let's do a grid of cards for now. */}
                    {tasks.map((task) => (
                        <div key={task.id} className="bg-zinc-900 border border-white/5 rounded-2xl p-5 flex flex-col hover:border-white/10 transition-colors">
                            <div className="flex justify-between items-start mb-3">
                                <span className={`text-xs px-2 py-1 rounded-full uppercase tracking-wider font-bold ${task.priority === 'high' ? 'bg-red-500/10 text-red-400' :
                                        task.priority === 'medium' ? 'bg-yellow-500/10 text-yellow-400' :
                                            'bg-blue-500/10 text-blue-400'
                                    }`}>
                                    {task.priority}
                                </span>
                                <button onClick={() => deleteTask(task.id)} className="text-zinc-500 hover:text-red-400 text-xs">Delete</button>
                            </div>

                            <h3 className="text-lg font-bold text-white mb-2">{task.title}</h3>
                            <p className="text-sm text-zinc-400 mb-4 flex-1">{task.description}</p>

                            <div className="space-y-2 border-t border-white/5 pt-4">
                                <div className="flex items-center gap-2 text-sm text-zinc-400">
                                    <User className="w-4 h-4 text-zinc-500" />
                                    <span>{task.assignee || "Unassigned"}</span>
                                </div>
                                <div className="flex items-center gap-2 text-sm text-zinc-400">
                                    <Calendar className="w-4 h-4 text-zinc-500" />
                                    <span>{task.deadline ? new Date(task.deadline).toLocaleDateString() : "No Deadline"}</span>
                                </div>
                            </div>

                            <div className="mt-4 pt-2">
                                <select
                                    value={task.status}
                                    onChange={(e) => updateTask(task.id, { status: e.target.value as any })}
                                    className="w-full bg-zinc-950 border border-white/10 rounded-lg text-sm text-white px-3 py-2 focus:outline-none"
                                >
                                    <option value="pending">Pending</option>
                                    <option value="in_progress">In Progress</option>
                                    <option value="completed">Completed</option>
                                </select>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
                        <h2 className="text-xl font-bold text-white mb-4">Create New Task</h2>
                        <form onSubmit={handleSubmit} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Title</label>
                                <input
                                    type="text"
                                    value={formData.title}
                                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Description</label>
                                <textarea
                                    rows={3}
                                    value={formData.description}
                                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1">Assignee</label>
                                    <input
                                        type="text"
                                        value={formData.assignee}
                                        onChange={(e) => setFormData({ ...formData, assignee: e.target.value })}
                                        className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                        placeholder="Name"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1">Deadline</label>
                                    <input
                                        type="date"
                                        value={formData.deadline}
                                        onChange={(e) => setFormData({ ...formData, deadline: e.target.value })}
                                        className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Priority</label>
                                <select
                                    value={formData.priority}
                                    onChange={(e) => setFormData({ ...formData, priority: e.target.value as any })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                >
                                    <option value="low">Low</option>
                                    <option value="medium">Medium</option>
                                    <option value="high">High</option>
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
                                    Create Task
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
