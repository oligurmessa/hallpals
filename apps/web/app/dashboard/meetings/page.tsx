"use client";

import React, { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useCommunityMeetings, CommunityMeeting, MeetingTopic } from "@/hooks/useCommunityMeetings";
import { Plus, Users, Calendar, Trash2, X, CheckCircle, Clock, ChevronDown, ChevronUp } from "lucide-react";

export default function MeetingsPage() {
    const { profile } = useAuth();
    const hallId = profile?.hallId;
    const { meetings, upcomingMeetings, completedMeetings, loading, createMeeting, updateMeetingStatus, deleteMeeting } = useCommunityMeetings(hallId);

    // Modal state
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [formData, setFormData] = useState({
        title: "",
        description: "",
        scheduledDate: "",
        topics: [{ name: "", description: "" }]
    });

    // Tab state
    const [activeTab, setActiveTab] = useState<'upcoming' | 'completed'>('upcoming');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const cleanedTopics = formData.topics.filter(t => t.name.trim() !== "");
        if (cleanedTopics.length === 0) {
            alert("Please add at least one topic.");
            return;
        }
        await createMeeting({
            title: formData.title,
            description: formData.description,
            scheduledDate: formData.scheduledDate,
            topics: cleanedTopics
        });
        closeModal();
    };

    const closeModal = () => {
        setIsModalOpen(false);
        setFormData({ title: "", description: "", scheduledDate: "", topics: [{ name: "", description: "" }] });
    };

    const addTopic = () => {
        setFormData({ ...formData, topics: [...formData.topics, { name: "", description: "" }] });
    };

    const removeTopic = (index: number) => {
        setFormData({ ...formData, topics: formData.topics.filter((_, i) => i !== index) });
    };

    const updateTopic = (index: number, field: 'name' | 'description', value: string) => {
        const newTopics = [...formData.topics];
        newTopics[index][field] = value;
        setFormData({ ...formData, topics: newTopics });
    };

    if (!hallId) {
        return <div className="p-8 text-center text-zinc-500">No Hall Assigned</div>;
    }

    const displayMeetings = activeTab === 'upcoming' ? upcomingMeetings : completedMeetings;

    return (
        <div className="max-w-7xl mx-auto">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white">Community Meetings</h1>
                    <p className="text-zinc-400 mt-1">Schedule and manage community meetings for your hall.</p>
                </div>
                <button
                    onClick={() => setIsModalOpen(true)}
                    className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl text-sm font-medium transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    Schedule Meeting
                </button>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 mb-6">
                <button
                    onClick={() => setActiveTab('upcoming')}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${activeTab === 'upcoming'
                        ? 'bg-purple-600 text-white'
                        : 'bg-zinc-800 text-zinc-400 hover:text-white'
                        }`}
                >
                    <div className="flex items-center gap-2">
                        <Clock className="w-4 h-4" />
                        Upcoming
                        {upcomingMeetings.length > 0 && (
                            <span className="px-1.5 py-0.5 bg-white/20 rounded text-xs">
                                {upcomingMeetings.length}
                            </span>
                        )}
                    </div>
                </button>
                <button
                    onClick={() => setActiveTab('completed')}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${activeTab === 'completed'
                        ? 'bg-purple-600 text-white'
                        : 'bg-zinc-800 text-zinc-400 hover:text-white'
                        }`}
                >
                    <div className="flex items-center gap-2">
                        <CheckCircle className="w-4 h-4" />
                        Completed
                    </div>
                </button>
            </div>

            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                </div>
            ) : displayMeetings.length === 0 ? (
                <div className="text-center py-20">
                    <Users className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
                    <h3 className="text-lg font-medium text-white mb-2">
                        {activeTab === 'upcoming' ? 'No Upcoming Meetings' : 'No Completed Meetings'}
                    </h3>
                    <p className="text-zinc-400">
                        {activeTab === 'upcoming' ? 'Schedule a community meeting to get started.' : 'Completed meetings will appear here.'}
                    </p>
                </div>
            ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {displayMeetings.map((meeting) => (
                        <MeetingCard
                            key={meeting.id}
                            meeting={meeting}
                            onMarkComplete={() => updateMeetingStatus(meeting.id, 'completed')}
                            onReopen={() => updateMeetingStatus(meeting.id, 'upcoming')}
                            onDelete={() => deleteMeeting(meeting.id)}
                        />
                    ))}
                </div>
            )}

            {/* Create Meeting Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
                        <div className="flex items-center justify-between mb-4">
                            <h2 className="text-xl font-bold text-white">Schedule Community Meeting</h2>
                            <button onClick={closeModal} className="text-zinc-400 hover:text-white">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <form onSubmit={handleSubmit} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Meeting Title</label>
                                <input
                                    type="text"
                                    value={formData.title}
                                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                    placeholder="e.g., Welcome Meeting, Safety & Wellness"
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Description</label>
                                <textarea
                                    rows={2}
                                    value={formData.description}
                                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                    placeholder="Brief description of the meeting purpose"
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Scheduled Date & Time</label>
                                <input
                                    type="datetime-local"
                                    value={formData.scheduledDate}
                                    onChange={(e) => setFormData({ ...formData, scheduledDate: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                />
                            </div>

                            {/* Topics */}
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-2">Topics to Cover</label>
                                <div className="space-y-3">
                                    {formData.topics.map((topic, index) => (
                                        <div key={index} className="bg-zinc-800/50 rounded-lg p-3 border border-white/5">
                                            <div className="flex items-start gap-2">
                                                <div className="flex-1 space-y-2">
                                                    <input
                                                        type="text"
                                                        value={topic.name}
                                                        onChange={(e) => updateTopic(index, 'name', e.target.value)}
                                                        placeholder="Topic name"
                                                        className="w-full px-3 py-1.5 bg-zinc-700 border border-white/10 rounded-lg text-white text-sm focus:outline-none focus:ring-1 focus:ring-purple-500/50"
                                                    />
                                                    <input
                                                        type="text"
                                                        value={topic.description}
                                                        onChange={(e) => updateTopic(index, 'description', e.target.value)}
                                                        placeholder="Brief description (optional)"
                                                        className="w-full px-3 py-1.5 bg-zinc-700 border border-white/10 rounded-lg text-white text-sm focus:outline-none focus:ring-1 focus:ring-purple-500/50"
                                                    />
                                                </div>
                                                {formData.topics.length > 1 && (
                                                    <button
                                                        type="button"
                                                        onClick={() => removeTopic(index)}
                                                        className="text-zinc-500 hover:text-red-400 p-1"
                                                    >
                                                        <Trash2 className="w-4 h-4" />
                                                    </button>
                                                )}
                                            </div>
                                        </div>
                                    ))}
                                </div>
                                <button
                                    type="button"
                                    onClick={addTopic}
                                    className="mt-2 text-sm text-purple-400 hover:text-purple-300 flex items-center gap-1"
                                >
                                    <Plus className="w-4 h-4" />
                                    Add Topic
                                </button>
                            </div>

                            <div className="flex justify-end gap-2 mt-6 pt-4 border-t border-white/10">
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
                                    Schedule Meeting
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

// Meeting Card Component
function MeetingCard({ meeting, onMarkComplete, onReopen, onDelete }: {
    meeting: CommunityMeeting;
    onMarkComplete: () => void;
    onReopen: () => void;
    onDelete: () => void;
}) {
    const [isExpanded, setIsExpanded] = useState(false);
    const completedTopics = meeting.topics.filter(t => t.isCompleted).length;
    const totalTopics = meeting.topics.length;
    const progress = totalTopics > 0 ? (completedTopics / totalTopics) * 100 : 0;
    const isOverdue = meeting.scheduledDate && new Date(meeting.scheduledDate) < new Date() && meeting.status === 'upcoming';

    const formatDate = (dateStr: string) => {
        if (!dateStr) return "Not scheduled";
        const date = new Date(dateStr);
        return date.toLocaleString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit'
        });
    };

    return (
        <div className="bg-zinc-900 border border-white/5 rounded-2xl overflow-hidden hover:border-white/10 transition-all">
            {/* Header */}
            <div className="p-6">
                <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-3">
                        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${meeting.status === 'completed' ? 'bg-green-500/20' : isOverdue ? 'bg-red-500/20' : 'bg-indigo-500/20'
                            }`}>
                            {meeting.status === 'completed' ? (
                                <CheckCircle className="w-5 h-5 text-green-400" />
                            ) : (
                                <Users className={`w-5 h-5 ${isOverdue ? 'text-red-400' : 'text-indigo-400'}`} />
                            )}
                        </div>
                        <div>
                            <h3 className="text-lg font-bold text-white">{meeting.title}</h3>
                            <p className="text-sm text-zinc-400">{meeting.description || "Community meeting"}</p>
                        </div>
                    </div>
                    <button
                        onClick={() => onDelete()}
                        className="text-zinc-500 hover:text-red-400 p-1"
                    >
                        <Trash2 className="w-4 h-4" />
                    </button>
                </div>

                {/* Progress Bar */}
                <div className="mb-4">
                    <div className="flex justify-between text-sm mb-1">
                        <span className="text-zinc-400">Topics</span>
                        <span className="text-white font-medium">{completedTopics}/{totalTopics}</span>
                    </div>
                    <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
                        <div
                            className={`h-full transition-all ${meeting.status === 'completed' ? 'bg-green-500' : 'bg-indigo-500'
                                }`}
                            style={{ width: `${progress}%` }}
                        />
                    </div>
                </div>

                {/* Details Row */}
                <div className="flex items-center gap-4 text-sm">
                    <div className={`flex items-center gap-1.5 ${isOverdue ? 'text-red-400' : 'text-zinc-400'}`}>
                        <Calendar className="w-4 h-4" />
                        <span>{formatDate(meeting.scheduledDate)}</span>
                        {isOverdue && <span className="text-xs bg-red-500/20 px-1.5 py-0.5 rounded">Overdue</span>}
                    </div>
                </div>
            </div>

            {/* Expandable Topics Section */}
            <div className="border-t border-white/5">
                <button
                    onClick={() => setIsExpanded(!isExpanded)}
                    className="w-full px-6 py-3 flex items-center justify-between text-sm text-zinc-400 hover:text-white transition-colors"
                >
                    <span>View Topics</span>
                    {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                </button>

                {isExpanded && (
                    <div className="px-6 pb-4 space-y-2">
                        {meeting.topics.map((topic, index) => (
                            <div key={topic.id || index} className="flex items-start gap-3 py-2">
                                <div className={`w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 ${topic.isCompleted ? 'bg-green-500/20' : 'bg-zinc-700'
                                    }`}>
                                    {topic.isCompleted && <CheckCircle className="w-3 h-3 text-green-400" />}
                                </div>
                                <div>
                                    <p className={`text-sm ${topic.isCompleted ? 'text-zinc-500 line-through' : 'text-white'}`}>
                                        {topic.name}
                                    </p>
                                    {topic.description && (
                                        <p className="text-xs text-zinc-500 mt-0.5">{topic.description}</p>
                                    )}
                                </div>
                            </div>
                        ))}

                        {/* Action Button */}
                        <div className="pt-3 border-t border-white/5">
                            {meeting.status === 'upcoming' ? (
                                <button
                                    onClick={onMarkComplete}
                                    className="w-full py-2 bg-green-600 hover:bg-green-500 text-white rounded-lg text-sm font-medium transition-colors"
                                >
                                    Mark as Completed
                                </button>
                            ) : (
                                <button
                                    onClick={onReopen}
                                    className="w-full py-2 bg-zinc-700 hover:bg-zinc-600 text-white rounded-lg text-sm font-medium transition-colors"
                                >
                                    Reopen Meeting
                                </button>
                            )}
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
