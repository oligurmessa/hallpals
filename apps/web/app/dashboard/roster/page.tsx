"use client";

import React, { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";
import { useSchedule, DutySchedule } from "@/hooks/useSchedule";
import { useHallStaff } from "@/hooks/useHallStaff";
import { useHalls } from "@/hooks/useHalls";
import { ChevronLeft, ChevronRight, Plus, Upload, Warehouse, LayoutGrid, List, Edit2 } from "lucide-react";
import * as XLSX from "xlsx";

// Minimal date utils without date-fns
const getDaysInMonth = (year: number, month: number) => new Date(year, month + 1, 0).getDate();
const getFirstDayOfMonth = (year: number, month: number) => new Date(year, month, 1).getDay(); // 0 = Sun
const formatDate = (d: Date) => d.toISOString().split('T')[0];

import { DeclareScheduleModal } from "@/components/dashboard/DeclareScheduleModal";

export default function SchedulePage() {
    const { profile } = useAuth();
    const { halls } = useHalls();

    // Default to profile hall, but allow switching
    const [selectedHallId, setSelectedHallId] = useState<string | null>(null);

    // Initialize selection once profile is loaded
    useEffect(() => {
        if (!selectedHallId && profile?.hallId) {
            setSelectedHallId(profile.hallId);
        } else if (!selectedHallId && halls.length > 0) {
            // Fallback if no profile hall
            setSelectedHallId(halls[0].id);
        }
    }, [profile, halls, selectedHallId]);

    const { schedule, loading: scheduleLoading, addDuty, deleteDuty } = useSchedule(selectedHallId);
    const { staff, loading: staffLoading } = useHallStaff(selectedHallId);

    const [currentDate, setCurrentDate] = useState(new Date());
    const [selectedDate, setSelectedDate] = useState<string | null>(null);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isDeclareModalOpen, setIsDeclareModalOpen] = useState(false);
    const [viewMode, setViewMode] = useState<'calendar' | 'list'>('calendar');

    // Modal Form State
    const [formData, setFormData] = useState({
        primaryId: "",
        secondaryId: "",
        notes: ""
    });

    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();

    const daysInMonth = getDaysInMonth(year, month);
    const firstDay = getFirstDayOfMonth(year, month);

    // Previous Month Fillers
    const prevMonthDays = Array.from({ length: firstDay }, (_, i) => {
        const d = new Date(year, month, 1 - (firstDay - i));
        return { date: d, isCurrentMonth: false };
    });

    // Current Month Days
    const currentMonthDays = Array.from({ length: daysInMonth }, (_, i) => {
        const d = new Date(year, month, i + 1);
        return { date: d, isCurrentMonth: true };
    });

    // Next Month Fillers (to grid 42 usually 6 rows)
    const totalSlots = 42;
    const nextMonthDays = Array.from({ length: totalSlots - (prevMonthDays.length + currentMonthDays.length) }, (_, i) => {
        const d = new Date(year, month + 1, i + 1);
        return { date: d, isCurrentMonth: false };
    });

    const calendarGrid = [...prevMonthDays, ...currentMonthDays, ...nextMonthDays];

    // Helper: Find duty for a date
    const getDutyForDate = (date: Date) => {
        const dateStr = formatDate(date);
        return schedule.find(s => s.id === dateStr);
    };

    const handlePrevMonth = () => setCurrentDate(new Date(year, month - 1, 1));
    const handleNextMonth = () => setCurrentDate(new Date(year, month + 1, 1));

    const openAddModal = (dateStr: string) => {
        const existing = schedule.find(s => s.id === dateStr);
        setFormData({
            primaryId: existing?.primaryRa?.id || "",
            secondaryId: existing?.secondaryRa?.id || "",
            notes: existing?.notes || ""
        });
        setSelectedDate(dateStr);
        setIsModalOpen(true);
    };

    const handleSaveDuty = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!selectedDate) return;

        const primary = staff.find(s => s.id === formData.primaryId);
        const secondary = staff.find(s => s.id === formData.secondaryId);

        if (!primary) {
            alert("Primary RA is required");
            return;
        }

        try {
            await addDuty(selectedDate, {
                id: primary.id,
                name: (primary.firstName || "") + " " + (primary.lastName || ""),
                email: primary.email
            }, secondary ? {
                id: secondary.id,
                name: (secondary.firstName || "") + " " + (secondary.lastName || ""),
                email: secondary.email
            } : null, formData.notes);
            setIsModalOpen(false);
        } catch (err) {
            console.error(err);
            alert("Failed to save duty");
        }
    };

    if (!profile) return <div className="p-10 text-zinc-500">Loading profile...</div>;

    const monthName = currentDate.toLocaleString('default', { month: 'long', year: 'numeric' });

    return (
        <div className="max-w-7xl mx-auto h-[calc(100vh-100px)] flex flex-col">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6 flex-shrink-0">
                <div className="flex flex-col gap-2">
                    <h1 className="text-3xl font-bold text-white">Duty Schedule</h1>

                    {/* Hall Selector */}
                    <div className="relative inline-block w-64">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <Warehouse className="h-4 w-4 text-zinc-400" />
                        </div>
                        <select
                            value={selectedHallId || ""}
                            onChange={(e) => setSelectedHallId(e.target.value)}
                            className="bg-zinc-900 border border-white/10 text-white text-sm rounded-lg focus:ring-purple-500 focus:border-purple-500 block w-full pl-10 pr-8 py-2 appearance-none cursor-pointer hover:bg-zinc-800 transition-colors"
                        >
                            <option value="" disabled>Select a Hall</option>
                            {halls.map(hall => (
                                <option key={hall.id} value={hall.id}>{hall.name}</option>
                            ))}
                        </select>
                        <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-zinc-400">
                            <svg className="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z" /></svg>
                        </div>
                    </div>
                </div>

                <div className="flex gap-3 items-end">
                    <button
                        onClick={() => setIsDeclareModalOpen(true)}
                        className="flex items-center gap-2 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-sm font-medium transition-colors border border-white/10"
                    >
                        <Upload className="w-4 h-4" />
                        Declare Schedule
                    </button>

                    <div className="flex items-center gap-2 bg-zinc-900 border border-white/10 rounded-xl p-1">
                        <button onClick={handlePrevMonth} className="p-2 hover:bg-white/10 rounded-lg text-zinc-400 hover:text-white transition-colors">
                            <ChevronLeft className="w-4 h-4" />
                        </button>
                        <span className="text-sm font-semibold text-white px-2 min-w-[140px] text-center">
                            {monthName}
                        </span>
                        <button onClick={handleNextMonth} className="p-2 hover:bg-white/10 rounded-lg text-zinc-400 hover:text-white transition-colors">
                            <ChevronRight className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            </div>

            {/* View Toggle */}
            <div className="flex bg-zinc-900 border border-white/10 p-1 rounded-xl mb-4 self-end">
                <button
                    onClick={() => setViewMode('calendar')}
                    className={`p-2 rounded-lg transition-colors ${viewMode === 'calendar' ? 'bg-zinc-800 text-white shadow-sm' : 'text-zinc-400 hover:text-white'}`}
                    title="Calendar View"
                >
                    <LayoutGrid className="w-4 h-4" />
                </button>
                <button
                    onClick={() => setViewMode('list')}
                    className={`p-2 rounded-lg transition-colors ${viewMode === 'list' ? 'bg-zinc-800 text-white shadow-sm' : 'text-zinc-400 hover:text-white'}`}
                    title="List View"
                >
                    <List className="w-4 h-4" />
                </button>
            </div>

            {/* Content Area */}
            {viewMode === 'calendar' ? (
                /* Calendar Grid */
                <div className="flex-1 bg-zinc-900 border border-white/10 rounded-2xl overflow-hidden flex flex-col shadow-2xl">
                    {/* Days Header */}
                    <div className="grid grid-cols-7 border-b border-white/10 bg-zinc-950/50">
                        {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
                            <div key={day} className="py-3 text-center text-xs font-semibold text-zinc-500 uppercase tracking-wider">
                                {day}
                            </div>
                        ))}
                    </div>

                    {/* Days Cells */}
                    <div className="flex-1 grid grid-cols-7 grid-rows-6">
                        {scheduleLoading ? (
                            <div className="col-span-7 row-span-6 flex items-center justify-center">
                                <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" />
                            </div>
                        ) : calendarGrid.map((cell, idx) => {
                            const dateStr = formatDate(cell.date);
                            const duty = getDutyForDate(cell.date);
                            const isToday = dateStr === formatDate(new Date());

                            return (
                                <div
                                    key={`${dateStr}-${idx}`}
                                    onClick={() => openAddModal(dateStr)}
                                    className={`
                                        border-b border-r border-white/5 p-2 relative group cursor-pointer hover:bg-white/5 transition-colors
                                        ${!cell.isCurrentMonth ? 'bg-zinc-950/30 text-zinc-700' : 'text-zinc-300'}
                                        ${isToday ? 'bg-purple-500/5' : ''}
                                    `}
                                >
                                    <span className={`
                                        text-xs font-medium w-6 h-6 flex items-center justify-center rounded-full mb-1
                                        ${isToday ? 'bg-purple-600 text-white' : ''}
                                    `}>
                                        {cell.date.getDate()}
                                    </span>

                                    {duty && (
                                        <div className="space-y-1">
                                            <div className="flex items-center gap-1.5 px-2 py-1 rounded-md bg-purple-500/10 border border-purple-500/20">
                                                <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
                                                <span className="text-xs font-medium text-purple-200 truncate">{duty.primaryRa?.name || 'RA'}</span>
                                            </div>
                                            {duty.secondaryRa && (
                                                <div className="flex items-center gap-1.5 px-2 py-1 rounded-md bg-indigo-500/10 border border-indigo-500/20">
                                                    <div className="w-1.5 h-1.5 rounded-full bg-indigo-500" />
                                                    <span className="text-xs font-medium text-indigo-200 truncate">{duty.secondaryRa.name}</span>
                                                </div>
                                            )}
                                        </div>
                                    )}

                                    {!duty && cell.isCurrentMonth && (
                                        <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 pointer-events-none">
                                            <Plus className="w-4 h-4 text-zinc-500" />
                                        </div>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </div>
            ) : (
                /* List View */
                <div className="flex-1 bg-zinc-900 border border-white/10 rounded-2xl overflow-hidden flex flex-col shadow-2xl overflow-y-auto">
                    <div className="overflow-x-auto">
                        <table className="w-full text-left font-sans">
                            <thead className="bg-zinc-950/50 text-zinc-500 text-xs uppercase tracking-wider font-semibold sticky top-0 backdrop-blur-sm z-10 border-b border-white/10">
                                <tr>
                                    <th className="px-6 py-4">Date</th>
                                    <th className="px-6 py-4">Primary RA</th>
                                    <th className="px-6 py-4">Secondary RA</th>
                                    <th className="px-6 py-4 w-1/3">Notes</th>
                                    <th className="px-6 py-4"></th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-white/5">
                                {currentMonthDays.map((cell) => {
                                    const dateStr = formatDate(cell.date);
                                    const duty = getDutyForDate(cell.date);
                                    const isToday = dateStr === formatDate(new Date());

                                    return (
                                        <tr
                                            key={dateStr}
                                            onClick={() => openAddModal(dateStr)}
                                            className={`
                                                group cursor-pointer hover:bg-white/5 transition-colors
                                                ${isToday ? 'bg-purple-500/5' : ''}
                                            `}
                                        >
                                            <td className="px-6 py-4 whitespace-nowrap">
                                                <div className="flex items-center gap-2">
                                                    <span className={`text-sm font-medium ${isToday ? 'text-purple-400' : 'text-zinc-300'}`}>
                                                        {cell.date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                                                    </span>
                                                    {isToday && <span className="text-[10px] bg-purple-500 text-white px-1.5 rounded-sm uppercase font-bold">Today</span>}
                                                </div>
                                            </td>
                                            <td className="px-6 py-4">
                                                {duty ? (
                                                    <div className="flex items-center gap-2">
                                                        <div className="w-2 h-2 rounded-full bg-purple-500" />
                                                        <span className="text-sm text-white font-medium">{duty.primaryRa?.name || 'Unknown'}</span>
                                                    </div>
                                                ) : <span className="text-sm text-zinc-600 italic">Unassigned</span>}
                                            </td>
                                            <td className="px-6 py-4">
                                                {duty?.secondaryRa ? (
                                                    <div className="flex items-center gap-2">
                                                        <div className="w-2 h-2 rounded-full bg-indigo-500" />
                                                        <span className="text-sm text-white font-medium">{duty.secondaryRa.name}</span>
                                                    </div>
                                                ) : <span className="text-sm text-zinc-600">-</span>}
                                            </td>
                                            <td className="px-6 py-4">
                                                <p className="text-sm text-zinc-400 truncate max-w-xs">{duty?.notes || ''}</p>
                                            </td>
                                            <td className="px-6 py-4 text-right">
                                                <button className="p-1 hover:bg-white/10 rounded text-zinc-500 hover:text-white opacity-0 group-hover:opacity-100 transition-opacity">
                                                    <Edit2 className="w-4 h-4" />
                                                </button>
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                        {currentMonthDays.length === 0 && (
                            <div className="p-10 text-center text-zinc-500">No days in this month view?</div>
                        )}
                    </div>
                </div>
            )}

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
                        <div className="flex justify-between items-center mb-6">
                            <div>
                                <h2 className="text-xl font-bold text-white">Assign Duty</h2>
                                <p className="text-sm text-zinc-400">{selectedDate}</p>
                            </div>
                            <button onClick={() => {
                                if (selectedDate && confirm("Clear this duty?")) {
                                    deleteDuty(selectedDate);
                                    setIsModalOpen(false);
                                }
                            }} className="text-red-400 hover:text-red-300 text-sm">Clear</button>
                        </div>

                        <form onSubmit={handleSaveDuty} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Primary RA (Required)</label>
                                <select
                                    value={formData.primaryId}
                                    onChange={(e) => setFormData({ ...formData, primaryId: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                    required
                                >
                                    <option value="">Select RA...</option>
                                    {staff.filter(s => s.role === 'ra').map(s => (
                                        <option key={s.id} value={s.id}>{s.firstName} {s.lastName}</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Secondary RA (Optional)</label>
                                <select
                                    value={formData.secondaryId}
                                    onChange={(e) => setFormData({ ...formData, secondaryId: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                                >
                                    <option value="">None</option>
                                    {staff.filter(s => s.role === 'ra').map(s => (
                                        <option key={s.id} value={s.id}>{s.firstName} {s.lastName}</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Notes</label>
                                <textarea
                                    value={formData.notes}
                                    onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                                    className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-purple-500/50 min-h-[80px]"
                                    placeholder="Shift notes..."
                                />
                            </div>

                            <div className="flex justify-end gap-2 mt-6">
                                <button
                                    type="button"
                                    onClick={() => setIsModalOpen(false)}
                                    className="px-4 py-2 text-zinc-400 hover:text-white transition-colors"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium"
                                >
                                    Save Duty
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Declare Schedule Modal */}
            <DeclareScheduleModal
                isOpen={isDeclareModalOpen}
                onClose={() => setIsDeclareModalOpen(false)}
                hallId={selectedHallId || ""}
            />
        </div>
    );
}
