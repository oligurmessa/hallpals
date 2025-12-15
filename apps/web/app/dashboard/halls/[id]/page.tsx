"use client";

import React, { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useRoster, Resident } from "@/hooks/useRoster";
import { useHallStaff, HallStaff } from "@/hooks/useHallStaff";
import { useHalls, Hall } from "@/hooks/useHalls";
import { ArrowLeft, User, Plus, Trash2, Edit2, Shield, Users, Settings, X, Upload, UserPlus, MoreVertical } from "lucide-react";
import { collection, query, where, getDocs, writeBatch, doc } from "firebase/firestore"; // Import direclty for batch ops
import { db } from "@/lib/firebase";

export default function HallDetailsPage() {
    const params = useParams();
    const router = useRouter();
    const hallId = params.id as string;

    // Data Hooks
    const { residents, loading: residentsLoading, addResident, updateResident, deleteResident, addResidentsBulk, deleteAllResidents } = useRoster(hallId);
    const { staff, loading: staffLoading, addStaff, removeStaff, addStaffBulk, deleteAllStaff } = useHallStaff(hallId);

    // Hall Config Hook
    const { halls, updateHall } = useHalls();
    const currentHall = halls.find((h: Hall) => h.id === hallId);

    // View State
    const [activeFloor, setActiveFloor] = useState<number>(1);
    const [activeWing, setActiveWing] = useState<string | null>(null); // Null means default view (if no wings) or first wing

    // Resident Modal State
    const [isResidentModalOpen, setIsResidentModalOpen] = useState(false);
    const [residentEditingId, setResidentEditingId] = useState<string | null>(null);
    const [residentForm, setResidentForm] = useState<Partial<Resident>>({
        firstName: "", lastName: "", email: "", roomNumber: "", floor: 1, wing: "", status: "active"
    });

    // Staff Modal State
    const [isStaffModalOpen, setIsStaffModalOpen] = useState(false);
    const [staffForm, setStaffForm] = useState({ email: "", role: "ra" as "ra" | "staff" });
    const [isSubmitting, setIsSubmitting] = useState(false);

    // Import State
    const [isImporting, setIsImporting] = useState(false);
    const fileInputRef = React.useRef<HTMLInputElement>(null);

    // Derived Data
    const floors = React.useMemo(() => {
        const configuredFloors = currentHall?.floors || [];
        const residentFloors = residents.map(r => r.floor);
        const staffFloors = staff.map(s => s.floor || 0);

        // Merge and deduplicate
        const allFloors = new Set([...configuredFloors, ...residentFloors, ...staffFloors]);

        // Filter valid floors and sort
        const sorted = Array.from(allFloors)
            .filter(f => f > 0)
            .sort((a, b) => a - b);

        // Default fallback if absolutely (or just 1)
        if (sorted.length === 0) return [1, 2, 3];

        return sorted;
    }, [residents, staff, currentHall]);

    const wings = currentHall?.wings || [];
    const hasWings = wings.length > 0;

    // Ensure activeWing is valid
    React.useEffect(() => {
        if (hasWings && !activeWing) {
            setActiveWing(wings[0]);
        } else if (!hasWings && activeWing) {
            setActiveWing(null);
        }
    }, [hasWings, wings, activeWing]);

    // Derived Roster View
    const filteredResidents = residents.filter(r =>
        r.floor == activeFloor && (activeWing ? r.wing === activeWing : true)
    );
    const filteredRAs = staff.filter(s =>
        s.floor == activeFloor && s.role === 'ra' && (activeWing ? (s as any).wing === activeWing : true)
    );
    const viewRoster = [
        ...filteredRAs.map(s => ({ ...s, type: 'ra' as const })),
        ...filteredResidents.map(r => ({ ...r, type: 'resident' as const }))
    ];


    // --- Actions ---

    const handleImportClick = () => {
        fileInputRef.current?.click();

    };

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setIsImporting(true);
        try {
            const XLSX = await import("xlsx");
            const reader = new FileReader();

            reader.onload = async (evt) => {
                try {
                    const bstr = evt.target?.result;
                    const wb = XLSX.read(bstr, { type: 'binary' });
                    const wsname = wb.SheetNames[0];
                    const ws = wb.Sheets[wsname];
                    const data = XLSX.utils.sheet_to_json(ws);

                    // Import Logic
                    const residentsToImport = data.map((row: any) => {
                        const email = row['UST Email'] || row['Email'] || row['email'] || '';
                        const firstName = row['First Name'] || row['firstName'] || '';
                        const lastName = row['Last Name'] || row['lastName'] || '';
                        const room = String(row['Bed Space'] || row['Room'] || row['roomNumber'] || '');

                        // Floor inference
                        let floor = Number(row['Floor'] || row['floor']);
                        if (!floor && room) {
                            const numericPart = room.replace(/\D/g, '');
                            if (numericPart.length === 3) floor = Number(numericPart[0]);
                            else if (numericPart.length === 4) floor = Number(numericPart.substring(0, 2));
                        }

                        return {
                            firstName,
                            lastName,
                            email,
                            roomNumber: room,
                            floor: floor || 1,
                            status: 'active',
                            wing: activeWing || undefined
                        };
                    }).filter((r: any) => r.email && r.firstName);

                    if (residentsToImport.length > 0) {
                        await addResidentsBulk(residentsToImport as any);
                        alert(`Successfully imported ${residentsToImport.length} residents${activeWing ? ` to ${activeWing}` : ''}.`);
                    } else {
                        alert("No valid residents found in file.");
                    }

                } catch (err: any) {
                    console.error(err);
                    alert("Import failed: " + err.message);
                } finally {
                    setIsImporting(false);
                    if (fileInputRef.current) fileInputRef.current.value = '';
                }
            };
            reader.readAsBinaryString(file);
        } catch (err) {
            console.error(err);
            setIsImporting(false);
        }
    };

    const handleAddWing = async () => {
        const wingName = window.prompt("Enter new Wing name (e.g., 'East', 'West'):");
        if (!wingName || !currentHall) return;
        if (wings.includes(wingName)) return alert("Wing already exists");

        try {
            const updatedWings = [...wings, wingName];
            await updateHall(hallId, { wings: updatedWings });
            setActiveWing(wingName);
        } catch (err) {
            console.error(err);
            alert("Failed to add wing");
        }
    };

    const handleRenameWing = async (oldName: string) => {
        const newName = window.prompt("Enter new name for wing:", oldName);
        if (!newName || newName === oldName || !currentHall) return;
        if (wings.includes(newName)) return alert("Wing name already exists");

        if (!confirm(`Rename '${oldName}' to '${newName}'? This will update all residents in this wing.`)) return;

        try {
            // 1. Update Hall Wings
            const updatedWings = wings.map(w => w === oldName ? newName : w);
            await updateHall(hallId, { wings: updatedWings });
            setActiveWing(newName);

            // 2. Batch Update Residents
            const batch = writeBatch(db);
            // Query residents with old wing
            const qRes = query(collection(db, "halls", hallId, "residents"), where("wing", "==", oldName));
            const qStaff = query(collection(db, "halls", hallId, "staff"), where("wing", "==", oldName));

            const [resSnap, staffSnap] = await Promise.all([getDocs(qRes), getDocs(qStaff)]);

            resSnap.forEach(doc => batch.update(doc.ref, { wing: newName }));
            staffSnap.forEach(doc => batch.update(doc.ref, { wing: newName }));

            await batch.commit();

        } catch (err) {
            console.error(err);
            alert("Failed to rename wing");
        }
    };

    const handleDeleteWing = async (wingToDelete: string) => {
        if (!currentHall) return;
        if (!confirm(`Delete '${wingToDelete}'? logic: Residents in this wing will become 'Unassigned' (wingless).`)) return;

        try {
            // 1. Update Hall Wings
            const updatedWings = wings.filter(w => w !== wingToDelete);
            await updateHall(hallId, { wings: updatedWings });
            if (activeWing === wingToDelete) setActiveWing(updatedWings[0] || null);

            // 2. Batch Update Residents (Set wing to null)
            const batch = writeBatch(db);
            const qRes = query(collection(db, "halls", hallId, "residents"), where("wing", "==", wingToDelete));
            const qStaff = query(collection(db, "halls", hallId, "staff"), where("wing", "==", wingToDelete));

            const [resSnap, staffSnap] = await Promise.all([getDocs(qRes), getDocs(qStaff)]);

            resSnap.forEach(doc => batch.update(doc.ref, { wing: null }));
            staffSnap.forEach(doc => batch.update(doc.ref, { wing: null }));

            await batch.commit();

        } catch (err) {
            console.error(err);
            alert("Failed to delete wing");
        }
    }


    // --- Submits ---
    const handleResidentSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsSubmitting(true);
        try {
            const data = { ...residentForm, wing: activeWing || undefined };
            if (residentEditingId) {
                await updateResident(residentEditingId, data);
            } else {
                await addResident(data as any);
            }
            closeResidentModal();
        } catch (err) {
            console.error(err);
            alert("Error saving resident");
        } finally {
            setIsSubmitting(false);
        }
    };

    const handleStaffSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsSubmitting(true);
        try {
            await addStaff(staffForm.email, staffForm.role, activeFloor, activeWing || undefined);
            closeStaffModal();
        } catch (err) {
            console.error(err); alert("Failed");
        } finally {
            setIsSubmitting(false);
        }
    };

    // --- Modals ---
    const openAddRAModal = () => {
        setStaffForm({ email: "", role: "ra" });
        setIsStaffModalOpen(true);
    }

    const openResidentModal = (r?: Resident) => {
        if (r) {
            setResidentEditingId(r.id);
            setResidentForm(r);
        } else {
            setResidentEditingId(null);
            setResidentForm({ firstName: "", lastName: "", email: "", roomNumber: "", floor: activeFloor, wing: activeWing || "", status: "active" });
        }
        setIsResidentModalOpen(true);
    };
    const closeResidentModal = () => { setIsResidentModalOpen(false); setResidentEditingId(null); };
    const closeStaffModal = () => setIsStaffModalOpen(false);


    return (
        <div className="max-w-7xl mx-auto pb-20">
            <input type="file" ref={fileInputRef} className="hidden" accept=".xlsx,.xls,.csv" onChange={handleFileChange} />

            {/* Header */}
            <div className="flex items-center justify-between mb-8">
                <div className="flex items-center gap-4">
                    <button onClick={() => router.push('/dashboard/halls')} className="p-2 bg-zinc-900 border border-white/10 rounded-xl text-zinc-400 hover:text-white transition-colors">
                        <ArrowLeft className="w-5 h-5" />
                    </button>
                    <div>
                        <h1 className="text-3xl font-bold text-white">Hall Details</h1>
                        <p className="text-zinc-400 mt-1">Managing {hallId}</p>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <button
                        onClick={handleImportClick}
                        className="flex items-center gap-2 px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-lg text-sm font-medium transition-colors border border-white/10"
                    >
                        <Upload className="w-4 h-4" /> Import
                    </button>
                    <button
                        onClick={openAddRAModal}
                        className="flex items-center gap-2 px-3 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-lg text-sm font-medium transition-colors"
                    >
                        <UserPlus className="w-4 h-4" /> Add RA
                    </button>
                    <button
                        onClick={() => {
                            if (!hasWings) handleAddWing();
                            // If wings exist, this button could toggle an 'Edit Mode' or standard 'Add Wing'
                            else handleAddWing();
                        }}
                        className="flex items-center gap-2 px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-lg text-sm font-medium transition-colors border border-white/10"
                    >
                        <Settings className="w-4 h-4" /> {hasWings ? 'Edit Wings' : 'Add Wings'}
                    </button>
                </div>
            </div>

            {/* Floor Navigation */}
            <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide border-b border-white/10">
                {floors.map((floorNum: number) => (
                    <button
                        key={floorNum}
                        onClick={() => setActiveFloor(floorNum)}
                        className={`px-4 py-3 text-sm font-medium transition-colors whitespace-nowrap border-b-2 relative -bottom-[1px] ${activeFloor === floorNum ? 'border-purple-500 text-purple-400' : 'border-transparent text-zinc-400 hover:text-white'}`}
                    >
                        {floorNum === 1 ? '1st Floor' : floorNum === 2 ? '2nd Floor' : floorNum === 3 ? '3rd Floor' : `${floorNum}th Floor`}
                    </button>
                ))}
            </div>

            {/* Wing Navigation (Dynamic) */}
            {hasWings && (
                <div className="flex items-center gap-2 mb-6 pb-2">
                    {wings.map(wing => (
                        <div key={wing} className="group relative">
                            <button
                                onClick={() => setActiveWing(wing)}
                                className={`px-4 py-1.5 rounded-full text-sm font-medium transition-all ${activeWing === wing ? 'bg-white text-zinc-900 shadow-lg scale-105' : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700 hover:text-white'}`}
                            >
                                {wing}
                            </button>
                            {/* Wing Context Actions (Hover) */}
                            <div className="absolute top-full left-1/2 -translate-x-1/2 mt-1 hidden group-hover:flex gap-1 bg-zinc-900 border border-white/10 p-1 rounded-lg shadow-xl z-10">
                                <button onClick={(e) => { e.stopPropagation(); handleRenameWing(wing); }} className="p-1 hover:bg-white/10 rounded text-zinc-400 hover:text-white" title="Rename Wing"><Edit2 className="w-3 h-3" /></button>
                                <button onClick={(e) => { e.stopPropagation(); handleDeleteWing(wing); }} className="p-1 hover:bg-red-500/20 rounded text-red-500 hover:text-red-400" title="Delete Wing"><X className="w-3 h-3" /></button>
                            </div>
                        </div>
                    ))}
                    <button
                        onClick={handleAddWing}
                        className="px-2 py-1.5 rounded-full bg-zinc-800/50 text-zinc-500 hover:bg-zinc-800 hover:text-white transition-colors border border-dashed border-white/10 hover:border-white/30"
                        title="Add Another Wing"
                    >
                        <Plus className="w-4 h-4" />
                    </button>
                </div>
            )}

            {/* Roster / Content Area */}
            {residentsLoading || staffLoading ? (
                <div className="flex justify-center py-20"><div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin" /></div>
            ) : (
                <div className="bg-zinc-900 border border-white/5 rounded-2xl overflow-hidden flex flex-col min-h-[400px]">
                    <div className="p-4 border-b border-white/5 flex flex-wrap gap-2 justify-between bg-zinc-900/50 items-center">
                        <h3 className="font-bold text-white text-lg flex items-center gap-2">
                            <span className="opacity-50">Roster</span>
                            <span>•</span>
                            <span>Floor {activeFloor}</span>
                            {activeWing && <span className="text-purple-400 bg-purple-500/10 px-2 py-0.5 rounded text-sm ml-1">{activeWing}</span>}
                        </h3>

                        {/* De-cluttered actions */}
                        {viewRoster.length > 0 && (
                            <button
                                onClick={async () => {
                                    if (confirm(`Delete ALL residents in this view?`)) {
                                        setIsImporting(true);
                                        for (const r of filteredResidents) await deleteResident(r.id);
                                        setIsImporting(false);
                                    }
                                }}
                                disabled={isImporting}
                                className="text-red-500 hover:text-red-400 text-xs font-medium px-2 py-1 hover:bg-red-500/10 rounded transition-colors"
                            >
                                Clear Roster
                            </button>
                        )}
                    </div>

                    <div className="overflow-x-auto">
                        <table className="w-full text-left font-sans">
                            <thead className="bg-white/5 text-zinc-400 text-xs uppercase tracking-wider font-semibold">
                                <tr>
                                    <th className="px-6 py-3">Name</th>
                                    <th className="px-6 py-3">Room</th>
                                    <th className="px-6 py-3 text-right"></th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-white/5">
                                {viewRoster.map((item: any) => (
                                    <tr key={item.id} className={`hover:bg-white/5 transition-colors group ${item.type === 'ra' ? 'bg-purple-900/10' : ''}`}>
                                        <td className="px-6 py-3">
                                            <div>
                                                <div className="flex items-center gap-2">
                                                    <p className="text-sm font-medium text-white">{item.firstName === 'Invited' ? 'Invited RA' : item.firstName} {item.lastName !== 'User' ? item.lastName : ''}</p>
                                                    {item.type === 'ra' && <span className="text-[10px] uppercase bg-purple-500 text-white px-1.5 rounded-sm">RA</span>}
                                                </div>
                                                <p className="text-xs text-zinc-500 truncate max-w-[200px]">{item.email}</p>
                                            </div>
                                        </td>
                                        <td className="px-6 py-3 text-sm text-zinc-300 font-mono">{item.roomNumber || '-'}</td>
                                        <td className="px-6 py-3 text-right">
                                            <div className="flex justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                                {item.type === 'resident' ? (
                                                    <button onClick={() => confirm("Delete?") && deleteResident(item.id)} className="p-1 hover:bg-red-500/10 rounded text-zinc-500 hover:text-red-400">
                                                        <Trash2 className="w-3 h-3" />
                                                    </button>
                                                ) : (
                                                    <button onClick={() => confirm("Remove RA?") && removeStaff(item.id)} className="p-1 hover:bg-red-500/10 rounded text-zinc-500 hover:text-red-400">
                                                        <Trash2 className="w-3 h-3" />
                                                    </button>
                                                )}
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                                {viewRoster.length === 0 && (
                                    <tr><td colSpan={3} className="py-20 text-center text-zinc-500 text-sm">
                                        <div className="flex flex-col items-center gap-2">
                                            <Users className="w-8 h-8 opacity-20" />
                                            <p>No residents or RAs in this section.</p>
                                            <button onClick={handleImportClick} className="text-purple-400 hover:text-purple-300 underline mt-1">Import Residents</button>
                                        </div>
                                    </td></tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}


            {/* Resident Modal */}
            {isResidentModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-lg shadow-2xl">
                        <h2 className="text-xl font-bold text-white mb-4">{residentEditingId ? 'Edit Resident' : 'Add New Resident'}</h2>
                        <form onSubmit={handleResidentSubmit} className="grid grid-cols-2 gap-4">
                            <input type="text" placeholder="First Name" value={residentForm.firstName} onChange={e => setResidentForm({ ...residentForm, firstName: e.target.value })} className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" required disabled={isSubmitting} />
                            <input type="text" placeholder="Last Name" value={residentForm.lastName} onChange={e => setResidentForm({ ...residentForm, lastName: e.target.value })} className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" required disabled={isSubmitting} />
                            <input type="email" placeholder="Email" value={residentForm.email} onChange={e => setResidentForm({ ...residentForm, email: e.target.value })} className="col-span-2 w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" required disabled={isSubmitting} />
                            <input type="text" placeholder="Room Number" value={residentForm.roomNumber} onChange={e => setResidentForm({ ...residentForm, roomNumber: e.target.value })} className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" required disabled={isSubmitting} />
                            <input type="number" placeholder="Floor" value={residentForm.floor} onChange={e => setResidentForm({ ...residentForm, floor: parseInt(e.target.value) || 1 })} className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" required disabled={isSubmitting} />
                            <select value={residentForm.status} onChange={e => setResidentForm({ ...residentForm, status: e.target.value as any })} className="col-span-2 w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" disabled={isSubmitting}>
                                <option value="active">Active</option>
                                <option value="inactive">Inactive</option>
                            </select>
                            <div className="col-span-2 flex justify-end gap-2 mt-4">
                                <button type="button" onClick={closeResidentModal} className="px-4 py-2 text-zinc-400 hover:text-white" disabled={isSubmitting}>Cancel</button>
                                <button type="submit" className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium" disabled={isSubmitting}>{isSubmitting ? 'Saving...' : 'Save'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Staff Modal */}
            {isStaffModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
                    <div className="bg-zinc-900 border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
                        <h2 className="text-xl font-bold text-white mb-4">Add Resident Advisor</h2>
                        <form onSubmit={handleStaffSubmit} className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1">Email Address</label>
                                <input type="email" value={staffForm.email} onChange={e => setStaffForm({ ...staffForm, email: e.target.value })} className="w-full px-4 py-2 bg-zinc-800 border border-white/10 rounded-xl text-white" required placeholder="user@example.com" disabled={isSubmitting} />
                            </div>

                            <div className="p-3 bg-purple-500/10 border border-purple-500/30 rounded-xl text-sm text-purple-300">
                                Adding RA to <strong>Floor {activeFloor}</strong> {activeWing && <span>({activeWing})</span>}
                            </div>

                            <div className="flex justify-end gap-2 mt-6">
                                <button type="button" onClick={closeStaffModal} className="px-4 py-2 text-zinc-400 hover:text-white" disabled={isSubmitting}>Cancel</button>
                                <button type="submit" className="px-4 py-2 bg-purple-600 hover:bg-purple-500 text-white rounded-xl font-medium" disabled={isSubmitting}>{isSubmitting ? 'Manifesting...' : 'Add RA'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
