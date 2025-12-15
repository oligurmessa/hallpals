"use client";

import React, { useState, useEffect } from "react";
import { useAuth } from "@/context/AuthContext";
import { useSchedule, DutySchedule } from "@/hooks/useSchedule";
import { useHallStaff } from "@/hooks/useHallStaff";
import { useHalls } from "@/hooks/useHalls";
import { ChevronLeft, ChevronRight, Plus, Upload, Warehouse } from "lucide-react";
import * as XLSX from "xlsx";

// Minimal date utils without date-fns
const getDaysInMonth = (year: number, month: number) => new Date(year, month + 1, 0).getDate();
const getFirstDayOfMonth = (year: number, month: number) => new Date(year, month, 1).getDay(); // 0 = Sun
const formatDate = (d: Date) => d.toISOString().split('T')[0];

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

    const { schedule, loading: scheduleLoading, addDuty, deleteDuty, importSchedule } = useSchedule(selectedHallId);
    const { staff, loading: staffLoading } = useHallStaff(selectedHallId);

    const [currentDate, setCurrentDate] = useState(new Date());
    const [selectedDate, setSelectedDate] = useState<string | null>(null);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [importing, setImporting] = useState(false);

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
            primaryId: existing?.primaryRa.id || "",
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

    const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setImporting(true);
        try {
            const buffer = await file.arrayBuffer();
            const wb = XLSX.read(buffer, { type: 'array' });
            const wsName = wb.SheetNames[0];
            const ws = wb.Sheets[wsName];
            const data: any[] = XLSX.utils.sheet_to_json(ws);

            const dutiesToImport: DutySchedule[] = [];

            for (const row of data) {
                // Try to parse Date. Excel often gives Number or String.
                // Expected Columns: "Date", "Primary", "Secondary"
                let dateStr = "";
                if (row['Date']) {
                    // Very basic date parsing. 
                    // If string "1/1/2024", normalize.
                    // If number (Excel serial), convert.
                    const d = new Date(row['Date']);
                    if (!isNaN(d.getTime())) {
                        dateStr = formatDate(d);
                    }
                }

                if (!dateStr) continue;

                // Match RAs
                // We'll search by Name (First/Last) or Email
                const primaryName = row['Primary'] || "";
                const secondaryName = row['Secondary'] || "";

                const findRa = (query: string) => {
                    if (!query) return null;
                    const q = query.toLowerCase().trim();
                    return staff.find(s =>
                        s.email.toLowerCase() === q ||
                        ((s.firstName || "") + " " + (s.lastName || "")).toLowerCase().includes(q)
                    );
                };

                const primary = findRa(primaryName);
                const secondary = findRa(secondaryName);

                if (primary) {
                    dutiesToImport.push({
                        id: dateStr,
                        date: null, // Hook handles Timestamp conv
                        primaryRa: {
                            id: primary.id,
                            name: (primary.firstName || "") + " " + (primary.lastName || ""),
                            email: primary.email
                        },
                        secondaryRa: secondary ? {
                            id: secondary.id,
                            name: (secondary.firstName || "") + " " + (secondary.lastName || ""),
                            email: secondary.email
                        } : undefined,
                        notes: row['Notes'] || ""
                    } as any);
                }
            }

            if (dutiesToImport.length > 0) {
                await importSchedule(dutiesToImport);
                alert(`Successfully imported ${dutiesToImport.length} duty slots.`);
            } else {
                alert("No valid duties found. Check your column names: 'Date', 'Primary', 'Secondary'.");
            }

        } catch (err) {
            console.error("Import failed:", err);
            alert("Failed to import. See console.");
        } finally {
            setImporting(false);
            e.target.value = "";
        }
    };

    if (!profile) return <div className="p-10 text-zinc-500">Loading profile...</div>;
    // We allow selectedHallId to be null initially while loading halls, but if halls loaded and still null, we show select message?
    // Actually the effect should set it if profile has hall or halls has length.

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
                    <label className={`flex items-center gap-2 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-sm font-medium transition-colors cursor-pointer ${importing ? "opacity-50 pointer-events-none" : ""}`}>
                        <Upload className="w-4 h-4" />
                        {importing ? "Importing..." : "Excel Import"}
                        <input type="file" accept=".xlsx, .xls, .csv" className="hidden" onChange={handleFileUpload} />
                    </label>
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

            {/* Calendar Grid */}
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
                                            <span className="text-xs font-medium text-purple-200 truncate">{duty.primaryRa.name}</span>
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
        </div>
    );
}
