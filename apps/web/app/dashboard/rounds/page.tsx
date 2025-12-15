"use client";

import React from "react";
import { useAuth } from "@/context/AuthContext";
import { useRounds } from "@/hooks/useRounds";
import { Shield, Calendar, Clock, User, CheckCircle } from "lucide-react";

export default function RoundsPage() {
    const { profile } = useAuth();
    const hallId = profile?.hallId;
    const { sessions, loading } = useRounds(hallId);

    if (!hallId) {
        return (
            <div className="p-8 text-center text-zinc-500">
                <h2 className="text-xl font-bold text-white mb-2">No Hall Assigned</h2>
            </div>
        )
    }

    const formatDate = (timestamp: any) => {
        if (!timestamp) return "-";
        return new Date(timestamp.seconds * 1000).toLocaleDateString();
    };

    const formatTime = (timestamp: any) => {
        if (!timestamp) return "-";
        return new Date(timestamp.seconds * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    };

    const getDuration = (start: any, end: any) => {
        if (!start || !end) return "-";
        const diffInfo = end.seconds - start.seconds;
        const mins = Math.floor(diffInfo / 60);
        return `${mins} min`;
    };

    return (
        <div className="max-w-7xl mx-auto">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Rounds Logs</h1>
                    <p className="text-zinc-400 mt-1">Audit log of all rounds sessions in Hall {hallId}.</p>
                </div>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : (
                <div className="bg-zinc-900 border border-white/5 rounded-2xl overflow-hidden">
                    <table className="w-full text-left font-sans">
                        <thead className="bg-white/5 text-zinc-400 text-xs uppercase tracking-wider font-semibold">
                            <tr>
                                <th className="px-6 py-4">Status</th>
                                <th className="px-6 py-4">RA (User ID)</th>
                                <th className="px-6 py-4">Date</th>
                                <th className="px-6 py-4">Time</th>
                                <th className="px-6 py-4">Duration</th>
                                <th className="px-6 py-4">Steps</th>
                                <th className="px-6 py-4">Floors</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-white/5">
                            {sessions.map((session) => (
                                <tr key={session.id} className="hover:bg-white/5 transition-colors">
                                    <td className="px-6 py-4">
                                        <span className={`flex items-center gap-2 text-sm font-medium ${session.status === 'Completed' ? 'text-emerald-400' : 'text-zinc-400'}`}>
                                            {session.status === 'Completed' ? <CheckCircle className="w-4 h-4" /> : <Clock className="w-4 h-4" />}
                                            {session.status}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 text-sm text-zinc-300 font-mono text-xs">
                                        {session.userId ? session.userId.slice(0, 8) : 'Unknown'}...
                                    </td>
                                    <td className="px-6 py-4 text-sm text-zinc-300">
                                        {formatDate(session.startTime)}
                                    </td>
                                    <td className="px-6 py-4 text-sm text-zinc-300">
                                        {formatTime(session.startTime)} - {formatTime(session.endTime)}
                                    </td>
                                    <td className="px-6 py-4 text-sm text-zinc-300">
                                        {getDuration(session.startTime, session.endTime)}
                                    </td>
                                    <td className="px-6 py-4 text-sm text-zinc-300">
                                        {session.totalSteps?.toLocaleString() || '-'}
                                    </td>
                                    <td className="px-6 py-4">
                                        <div className="flex gap-1">
                                            {session.floorsVisited?.map(floor => (
                                                <span key={floor} className="w-6 h-6 flex items-center justify-center bg-zinc-800 rounded text-xs text-zinc-400">
                                                    {floor}
                                                </span>
                                            ))}
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}
