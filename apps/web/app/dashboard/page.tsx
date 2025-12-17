"use client";

import React from "react";
import { BookOpen, Users, ShieldAlert, ListTodo, ArrowRight } from "lucide-react";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { useRoster } from "@/hooks/useRoster";
import { useTasks } from "@/hooks/useTasks";
import { useRounds } from "@/hooks/useRounds";
import { useDocs } from "@/hooks/useDocs";

export default function DashboardPage() {
    const { profile } = useAuth();
    const hallId = profile?.hallId || null;

    const { residents } = useRoster(hallId);
    const { tasks } = useTasks(hallId);
    const { sessions } = useRounds(hallId);
    const { docs } = useDocs();

    // Calculate Stats
    const activeResidents = residents.length;
    const openTasks = tasks.filter(t => t.status !== 'completed').length;
    const totalRounds = sessions.length;
    const publishedDocs = docs.filter(d => d.isPublished).length;

    // Recent Activity - using Tasks for now
    const recentTasks = tasks.slice(0, 3);

    return (
        <div className="max-w-7xl mx-auto space-y-8">
            <div>
                <h1 className="text-3xl font-bold text-white">Dashboard Overview</h1>
                <p className="text-zinc-400 mt-2">Welcome back to HallPals Command Center.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    title="Active Residents"
                    value={activeResidents.toString()}
                    icon={Users}
                    color="bg-blue-500"
                />
                <StatCard
                    title="Open Tasks"
                    value={openTasks.toString()}
                    icon={ListTodo}
                    color="bg-purple-500"
                />
                <StatCard
                    title="Total Rounds"
                    value={totalRounds.toString()}
                    icon={ShieldAlert}
                    color="bg-pink-500"
                />
                <StatCard
                    title="Published Docs"
                    value={publishedDocs.toString()}
                    icon={BookOpen}
                    color="bg-emerald-500"
                />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                <div className="bg-zinc-900 border border-white/5 rounded-2xl p-6">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="text-xl font-bold text-white">Recent Activity (Open Tasks)</h2>
                        <Link href="/dashboard/tasks" className="text-sm text-purple-400 hover:text-purple-300">View All</Link>
                    </div>
                    <div className="space-y-4">
                        {recentTasks.length === 0 ? (
                            <p className="text-zinc-500 text-sm">No recent tasks found.</p>
                        ) : (
                            recentTasks.map((task) => (
                                <Link
                                    key={task.id}
                                    href="/dashboard/tasks"
                                    className="flex items-center gap-4 p-3 rounded-xl hover:bg-white/5 transition-colors cursor-pointer"
                                >
                                    <div className="w-10 h-10 rounded-full bg-zinc-800 flex items-center justify-center">
                                        <ListTodo className="w-5 h-5 text-zinc-400" />
                                    </div>
                                    <div className="flex-1">
                                        <p className="text-sm font-medium text-white">{task.title}</p>
                                        <p className="text-xs text-zinc-500">
                                            {task.createdAt?.seconds ? new Date(task.createdAt.seconds * 1000).toLocaleDateString() : 'Just now'} • {task.priority} priority
                                        </p>
                                    </div>
                                    <div className={`px-2 py-1 rounded text-xs ${task.priority === 'high' ? 'bg-red-500/10 text-red-500' :
                                        task.priority === 'medium' ? 'bg-yellow-500/10 text-yellow-500' :
                                            'bg-blue-500/10 text-blue-500'
                                        }`}>
                                        {task.priority}
                                    </div>
                                </Link>
                            ))
                        )}
                    </div>
                </div>

                <div className="bg-zinc-900 border border-white/5 rounded-2xl p-6">
                    <h2 className="text-xl font-bold text-white mb-6">Quick Actions</h2>
                    <div className="grid grid-cols-2 gap-4">
                        <QuickAction title="New Task" href="/dashboard/tasks" color="from-purple-600 to-purple-800" />
                        <QuickAction title="Add Document" href="/dashboard/handbook" color="from-blue-600 to-blue-800" />
                        <QuickAction title="Inspections" href="/dashboard/inspections" color="from-red-600 to-red-800" />
                        <QuickAction title="RA Schedule" href="/dashboard/roster" color="from-emerald-600 to-emerald-800" />
                    </div>
                </div>
            </div>
        </div>
    );
}

function StatCard({ title, value, icon: Icon, color }: any) {
    return (
        <div className="bg-zinc-900 border border-white/5 rounded-2xl p-6 relative overflow-hidden group hover:border-white/10 transition-all">
            <div className={`absolute top-0 right-0 w-24 h-24 ${color} opacity-5 rounded-full blur-2xl group-hover:opacity-10 transition-opacity`} />
            <div className="relative z-10">
                <div className={`w-12 h-12 rounded-xl ${color} bg-opacity-10 flex items-center justify-center mb-4`}>
                    <Icon className={`w-6 h-6 text-white`} />
                </div>
                <p className="text-zinc-400 text-sm font-medium">{title}</p>
                <p className="text-3xl font-bold text-white mt-1">{value}</p>
            </div>
        </div>
    )
}

function QuickAction({ title, href, color }: any) {
    return (
        <Link href={href} className={`group relative overflow-hidden rounded-xl p-4 bg-zinc-800 hover:bg-zinc-750 border border-white/5 transition-all`}>
            <div className={`absolute inset-0 bg-gradient-to-br ${color} opacity-0 group-hover:opacity-10 transition-opacity`} />
            <div className="relative z-10 flex items-center justify-between">
                <span className="font-medium text-white">{title}</span>
                <ArrowRight className="w-4 h-4 text-zinc-500 group-hover:text-white transition-colors" />
            </div>
        </Link>
    )
}
