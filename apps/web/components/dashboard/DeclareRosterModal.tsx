import React, { useState, useRef } from 'react';
import { Upload, X, AlertTriangle, Check, FileSpreadsheet, Loader2, ArrowRight } from 'lucide-react';
import { parseRosterFile, ParseResult } from '@/lib/import-utils';
import { useRoster } from '@/hooks/useRoster';
import { useHallStaff } from '@/hooks/useHallStaff';
import { useHalls } from '@/hooks/useHalls';

interface DeclareRosterModalProps {
    isOpen: boolean;
    onClose: () => void;
    hallId: string;
}

type Step = 'upload' | 'preview' | 'importing' | 'success';

export const DeclareRosterModal: React.FC<DeclareRosterModalProps> = ({ isOpen, onClose, hallId }) => {
    const fileInputRef = useRef<HTMLInputElement>(null);
    const [step, setStep] = useState<Step>('upload');
    const [parsedData, setParsedData] = useState<ParseResult | null>(null);
    const [error, setError] = useState<string | null>(null);

    // Hooks
    const { residents } = useRoster(hallId);
    const { staff } = useHallStaff(hallId);
    const { updateHall, halls } = useHalls();
    const currentHall = halls.find(h => h.id === hallId);

    if (!isOpen) return null;

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setError(null);
        try {
            const result = await parseRosterFile(file);
            if (result.residents.length === 0 && result.staff.length === 0) {
                setError("No valid residents or staff found in file. Please check your column headers.");
                return;
            }
            setParsedData(result);
            setStep('preview');
        } catch (err: any) {
            console.error(err);
            setError("Failed to parse file: " + err.message);
        }
    };

    const handleConfirmImport = async () => {
        if (!parsedData) return;
        setStep('importing');

        try {
            const { httpsCallable } = await import("firebase/functions");
            const { functions } = await import("@/lib/firebase");

            const residentsToImport = parsedData.residents.map(r => ({
                firstName: r.firstName,
                lastName: r.lastName,
                email: r.email,
                roomNumber: r.roomNumber,
                floor: r.floor,
                wing: r.wing,
                role: 'resident'
            }));

            const staffToImport = parsedData.staff.map(s => ({
                firstName: s.firstName,
                lastName: s.lastName,
                email: s.email,
                roomNumber: s.roomNumber,
                floor: s.floor,
                wing: s.wing,
                role: 'ra'
            }));

            const rosterData = [...residentsToImport, ...staffToImport];

            if (rosterData.length > 0) {
                const importRoster = httpsCallable(functions, 'importRoster');
                await importRoster({
                    hallId,
                    data: rosterData
                });
            }

            setStep('success');

        } catch (err: any) {
            console.error(err);
            setError("Import failed: " + err.message);
            setStep('preview');
        }
    };

    const handleClose = () => {
        setStep('upload');
        setParsedData(null);
        setError(null);
        onClose();
    }

    const handleDownloadTemplate = async () => {
        try {
            const XLSX = await import("xlsx");
            const wb = XLSX.utils.book_new();
            const headers = ["First Name", "Last Name", "Email", "Room", "Floor", "Wing", "Role"];
            const exampleData = [
                { "First Name": "John", "Last Name": "Doe", "Email": "john.doe@university.edu", "Room": "101", "Floor": 1, "Wing": "North", "Role": "Resident" },
                { "First Name": "Jane", "Last Name": "Smith", "Email": "jane.smith@university.edu", "Room": "102", "Floor": 1, "Wing": "North", "Role": "RA" },
                { "First Name": "Alice", "Last Name": "Johnson", "Email": "alice.j@university.edu", "Room": "205", "Floor": 2, "Wing": "South", "Role": "Resident" },
            ];
            const ws = XLSX.utils.json_to_sheet(exampleData, { header: headers });
            XLSX.utils.book_append_sheet(wb, ws, "Roster Template");
            XLSX.writeFile(wb, "roster_template.xlsx");
        } catch (err) {
            console.error(err);
            alert("Failed to generate template");
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
            <div className="bg-zinc-900 border border-white/10 rounded-2xl w-full max-w-2xl shadow-2xl flex flex-col max-h-[90vh]">

                {/* Header */}
                <div className="p-6 border-b border-white/10 flex items-center justify-between">
                    <div>
                        <h2 className="text-xl font-bold text-white flex items-center gap-2">
                            <FileSpreadsheet className="w-5 h-5 text-purple-400" />
                            Declare Roster
                        </h2>
                        <p className="text-zinc-400 text-sm mt-1">Upload a master roster to populate this hall.</p>
                        <p className="text-amber-500 text-xs mt-1 font-medium bg-amber-500/10 px-2 py-0.5 rounded inline-block">⚠️ For initial setup or major resets ONLY. For edits, use the manual controls.</p>
                    </div>
                    <button onClick={handleClose} className="p-2 hover:bg-white/10 rounded-lg text-zinc-400 hover:text-white transition-colors">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Content */}
                <div className="p-6 flex-1 overflow-y-auto">

                    {error && (
                        <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 rounded-xl flex items-start gap-3 text-red-200">
                            <AlertTriangle className="w-5 h-5 shrink-0 text-red-400" />
                            <div>
                                <h4 className="font-medium text-red-400">Error</h4>
                                <p className="text-sm opacity-90">{error}</p>
                            </div>
                        </div>
                    )}

                    {step === 'upload' && (
                        <div className="flex flex-col items-center justify-center py-12 border-2 border-dashed border-white/10 rounded-xl bg-zinc-800/20 hover:bg-zinc-800/40 hover:border-purple-500/30 transition-all cursor-pointer group"
                            onClick={() => fileInputRef.current?.click()}>
                            <input type="file" ref={fileInputRef} className="hidden" accept=".xlsx,.xls,.csv" onChange={handleFileChange} />
                            <div className="w-16 h-16 bg-zinc-800 rounded-full flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                                <Upload className="w-8 h-8 text-zinc-400 group-hover:text-purple-400" />
                            </div>
                            <h3 className="text-lg font-medium text-white">Click to upload roster file</h3>
                            <p className="text-zinc-500 text-sm mt-2">Supports .xlsx, .xls, .csv</p>
                            <div className="mt-8 text-xs text-zinc-600 grid grid-cols-2 gap-x-8 gap-y-2 text-left">
                                <span>✓ Smart Column Matching</span>
                                <span>✓ Auto-Detects Wings</span>
                                <span>✓ Splits Residents & RAs</span>
                            </div>
                            <button onClick={(e) => { e.stopPropagation(); handleDownloadTemplate(); }} className="mt-6 text-xs text-purple-400 hover:text-purple-300 underline">
                                Download Example Template (.xlsx)
                            </button>
                        </div>
                    )}

                    {step === 'preview' && parsedData && (
                        <div className="space-y-6">
                            <div className="p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-xl text-yellow-200 text-sm flex gap-3">
                                <AlertTriangle className="w-5 h-5 shrink-0" />
                                <div>
                                    <p className="font-bold">Warning: Overwrite Action</p>
                                    <p className="opacity-80">This will <strong>DELETE ALL</strong> existing residents and staff in this hall and replace them with the data below.</p>
                                </div>
                            </div>

                            <div className="grid grid-cols-3 gap-4">
                                <div className="p-4 bg-zinc-800 rounded-xl border border-white/5">
                                    <h4 className="text-zinc-400 text-xs uppercase tracking-wider font-bold mb-1">Residents</h4>
                                    <p className="text-2xl font-bold text-white">{parsedData.residents.length}</p>
                                </div>
                                <div className="p-4 bg-zinc-800 rounded-xl border border-white/5">
                                    <h4 className="text-zinc-400 text-xs uppercase tracking-wider font-bold mb-1">Staff (RAs)</h4>
                                    <p className="text-2xl font-bold text-white">{parsedData.staff.length}</p>
                                </div>
                                <div className="p-4 bg-zinc-800 rounded-xl border border-white/5">
                                    <h4 className="text-zinc-400 text-xs uppercase tracking-wider font-bold mb-1">Wings Found</h4>
                                    <div className="flex flex-wrap gap-1 mt-1">
                                        {parsedData.wings.map(w => (
                                            <span key={w} className="text-xs bg-purple-500/20 text-purple-300 px-2 py-0.5 rounded">{w}</span>
                                        ))}
                                        {parsedData.wings.length === 0 && <span className="text-zinc-500 text-sm">-</span>}
                                    </div>
                                </div>
                            </div>

                            {parsedData.errors.length > 0 && (
                                <div className="border border-white/10 rounded-xl overflow-hidden">
                                    <div className="bg-red-500/10 px-4 py-2 text-red-400 text-xs font-bold uppercase">Skipped Rows ({parsedData.errors.length})</div>
                                    <div className="bg-zinc-900 p-2 max-h-32 overflow-y-auto">
                                        {parsedData.errors.map((e, i) => (
                                            <div key={i} className="text-xs text-zinc-500 font-mono py-1 border-b border-white/5 last:border-0">{e}</div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    )}

                    {step === 'importing' && (
                        <div className="text-center py-20">
                            <Loader2 className="w-12 h-12 text-purple-500 animate-spin mx-auto mb-4" />
                            <h3 className="text-xl font-bold text-white">Importing Roster...</h3>
                            <p className="text-zinc-400">Processing residents, staff, and wing configurations.</p>
                        </div>
                    )}

                    {step === 'success' && (
                        <div className="text-center py-12">
                            <div className="w-16 h-16 bg-green-500/20 text-green-500 rounded-full flex items-center justify-center mx-auto mb-4">
                                <Check className="w-8 h-8" />
                            </div>
                            <h3 className="text-xl font-bold text-white">Roster Declared Successfully!</h3>
                            <p className="text-zinc-400 mt-2 mb-8">
                                Added {parsedData?.residents.length} residents and {parsedData?.staff.length} staff members.
                            </p>
                            <button onClick={handleClose} className="px-6 py-2 bg-white text-black font-bold rounded-lg hover:bg-zinc-200 transition-colors">
                                Done
                            </button>
                        </div>
                    )}
                </div>

                {/* Footer Actions */}
                {step === 'preview' && (
                    <div className="p-6 border-t border-white/10 flex justify-end gap-3 bg-zinc-900/50">
                        <button onClick={() => setStep('upload')} className="px-4 py-2 text-zinc-400 hover:text-white transition-colors">
                            Back
                        </button>
                        <button
                            onClick={handleConfirmImport}
                            className="flex items-center gap-2 px-5 py-2 bg-purple-600 hover:bg-purple-500 text-white font-bold rounded-xl transition-colors shadow-lg shadow-purple-900/20"
                        >
                            Confirm & Overwrite <ArrowRight className="w-4 h-4" />
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
};
