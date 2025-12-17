import React, { useState, useRef } from 'react';
import { Upload, X, AlertTriangle, Check, Calendar, Loader2, ArrowRight } from 'lucide-react';
import { parseScheduleFile, ScheduleParseResult } from '@/lib/import-utils';
import { useHallStaff } from '@/hooks/useHallStaff';
import { useSchedule } from '@/hooks/useSchedule';

interface DeclareScheduleModalProps {
    isOpen: boolean;
    onClose: () => void;
    hallId: string;
}

type Step = 'upload' | 'preview' | 'importing' | 'success';

export const DeclareScheduleModal: React.FC<DeclareScheduleModalProps> = ({ isOpen, onClose, hallId }) => {
    const fileInputRef = useRef<HTMLInputElement>(null);
    const [step, setStep] = useState<Step>('upload');
    const [parsedData, setParsedData] = useState<ScheduleParseResult | null>(null);
    const [error, setError] = useState<string | null>(null);

    const { staff } = useHallStaff(hallId);
    const { importSchedule, schedule } = useSchedule(hallId);

    if (!isOpen) return null;

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        setError(null);
        try {
            const result = await parseScheduleFile(file, staff);
            if (result.shifts.length === 0) {
                setError("No valid shifts found with dates. Check your column headers.");
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
            // Transform to hook format
            const dutiesToImport = parsedData.shifts.map(shift => {
                // We use email as the primary key for "Declaration"
                // If we matched a staff member, we might have more info, but email is critical.

                // If parsedData has email, use it.
                const pEmail = shift.primaryEmail;
                const sEmail = shift.secondaryEmail;

                // Optional: Lookup name if missing
                let pName = shift.primaryName;
                let sName = shift.secondaryName;

                if (!pEmail) return null; // Primary email required

                // Resolve IDs if possible (though for roster-based declaration, we might not have UIDs yet)
                // The backfill process handles UIDs later.

                const primaryRaObj = {
                    email: pEmail,
                    name: pName || pEmail.split('@')[0],
                    id: undefined // Let hook set to null
                };

                const secondaryRaObj = sEmail ? {
                    email: sEmail,
                    name: sName || sEmail.split('@')[0],
                    id: undefined
                } : undefined;

                return {
                    dateStr: shift.dateStr,
                    primary: primaryRaObj,
                    secondary: secondaryRaObj,
                    notes: shift.notes || ""
                };
            }).filter((d): d is NonNullable<typeof d> => !!d);

            if (dutiesToImport.length > 0) {
                await importSchedule(dutiesToImport);
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
            const headers = ["Date", "Primary Email", "Secondary Email", "Notes"];
            const exampleData = [
                { "Date": "2024-01-01", "Primary Email": "john.doe@example.com", "Secondary Email": "", "Notes": "New Year Duty" },
                { "Date": "2024-01-02", "Primary Email": "jane.smith@example.com", "Secondary Email": "john.doe@example.com", "Notes": "" },
                { "Date": "2024-01-03", "Primary Email": "alice@example.com", "Secondary Email": "", "Notes": "" },
            ];
            const ws = XLSX.utils.json_to_sheet(exampleData, { header: headers });

            // Adjust column widths
            ws['!cols'] = [
                { wch: 12 }, // Date
                { wch: 30 }, // Primary
                { wch: 30 }, // Secondary
                { wch: 20 }, // Notes
            ];

            XLSX.utils.book_append_sheet(wb, ws, "Schedule Template");
            XLSX.writeFile(wb, "schedule_template.xlsx");
        } catch (err) {
            console.error(err);
            alert("Failed to generate template");
        }
    };

    const matchedCount = parsedData?.shifts.filter(s => s.primaryRaId).length || 0;
    const totalCount = parsedData?.shifts.length || 0;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
            <div className="bg-zinc-900 border border-white/10 rounded-2xl w-full max-w-2xl shadow-2xl flex flex-col max-h-[90vh]">

                {/* Header */}
                <div className="p-6 border-b border-white/10 flex items-center justify-between">
                    <div>
                        <h2 className="text-xl font-bold text-white flex items-center gap-2">
                            <Calendar className="w-5 h-5 text-purple-400" />
                            Declare Schedule
                        </h2>
                        <p className="text-zinc-400 text-sm mt-1">Upload a duty schedule for the month.</p>
                        <p className="text-amber-500 text-xs mt-1 font-medium bg-amber-500/10 px-2 py-0.5 rounded inline-block">⚠️ Will overwrite existing duties for the matching dates.</p>
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
                            <h3 className="text-lg font-medium text-white">Click to upload schedule</h3>
                            <p className="text-zinc-500 text-sm mt-2">Supports .xlsx, .xls, .csv</p>
                            <div className="mt-8 text-xs text-zinc-600 grid grid-cols-2 gap-x-8 gap-y-2 text-left">
                                <span>✓ Smart Date Parsing</span>
                                <span>✓ Auto-Matches RAs</span>
                            </div>
                            <button onClick={(e) => { e.stopPropagation(); handleDownloadTemplate(); }} className="mt-6 text-xs text-purple-400 hover:text-purple-300 underline">
                                Download Schedule Template (.xlsx)
                            </button>
                        </div>
                    )}

                    {step === 'preview' && parsedData && (
                        <div className="space-y-6">

                            <div className="grid grid-cols-3 gap-4">
                                <div className="p-4 bg-zinc-800 rounded-xl border border-white/5">
                                    <h4 className="text-zinc-400 text-xs uppercase tracking-wider font-bold mb-1">Shifts Found</h4>
                                    <p className="text-2xl font-bold text-white">{totalCount}</p>
                                </div>
                                <div className="p-4 bg-zinc-800 rounded-xl border border-white/5">
                                    <h4 className="text-zinc-400 text-xs uppercase tracking-wider font-bold mb-1">Matched RAs</h4>
                                    <p className={`text-2xl font-bold ${matchedCount === totalCount ? 'text-green-400' : 'text-amber-400'}`}>
                                        {matchedCount} <span className="text-base font-normal text-zinc-500">/ {totalCount}</span>
                                    </p>
                                </div>
                                <div className="p-4 bg-zinc-800 rounded-xl border border-white/5">
                                    <h4 className="text-zinc-400 text-xs uppercase tracking-wider font-bold mb-1">Unmatched Names</h4>
                                    <p className="text-2xl font-bold text-white">{parsedData.unmatchedRAs.length}</p>
                                </div>
                            </div>

                            {parsedData.unmatchedRAs.length > 0 && (
                                <div className="p-4 bg-amber-500/10 border border-amber-500/20 rounded-xl text-amber-200">
                                    <h4 className="font-bold flex items-center gap-2 mb-2">
                                        <AlertTriangle className="w-4 h-4" />
                                        Unrecognized Staff Names
                                    </h4>
                                    <p className="text-sm mb-3 opacity-90">The following names in your file did not match any current staff. These shifts will be skipped or imported without assignment:</p>
                                    <div className="flex flex-wrap gap-2">
                                        {parsedData.unmatchedRAs.map(name => (
                                            <span key={name} className="px-2 py-1 bg-amber-500/20 rounded text-xs font-mono border border-amber-500/30">
                                                {name}
                                            </span>
                                        ))}
                                    </div>
                                    <p className="text-xs mt-3 text-amber-300/70">Tip: Rename them in your file to match the exact names or emails in HallPals.</p>
                                </div>
                            )}

                        </div>
                    )}

                    {step === 'importing' && (
                        <div className="text-center py-20">
                            <Loader2 className="w-12 h-12 text-purple-500 animate-spin mx-auto mb-4" />
                            <h3 className="text-xl font-bold text-white">Importing Schedule...</h3>
                            <p className="text-zinc-400">Updating calendar with {matchedCount} shifts.</p>
                        </div>
                    )}

                    {step === 'success' && (
                        <div className="text-center py-12">
                            <div className="w-16 h-16 bg-green-500/20 text-green-500 rounded-full flex items-center justify-center mx-auto mb-4">
                                <Check className="w-8 h-8" />
                            </div>
                            <h3 className="text-xl font-bold text-white">Schedule Updated!</h3>
                            <p className="text-zinc-400 mt-2 mb-8">
                                Successfully imported {matchedCount} duty slots.
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
                            disabled={matchedCount === 0}
                            className="flex items-center gap-2 px-5 py-2 bg-purple-600 hover:bg-purple-500 text-white font-bold rounded-xl transition-colors shadow-lg shadow-purple-900/20 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            Import {matchedCount} Shifts <ArrowRight className="w-4 h-4" />
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
};
