import { read, utils } from 'xlsx';

export interface ParsedRosterRow {
    firstName: string;
    lastName: string;
    email: string;
    roomNumber: string;
    floor: number;
    wing?: string;
    role: 'ra' | 'resident';
    originalRow: any; // For debugging/displaying errors
}

export interface ParseResult {
    residents: ParsedRosterRow[];
    staff: ParsedRosterRow[];
    wings: string[];
    errors: string[];
}

// Mappings for fuzzy matching
const COLUMN_MAPPINGS = {
    firstName: ["first name", "fname", "given name", "first", "forename"],
    lastName: ["last name", "lname", "surname", "last", "family name"],
    email: ["email", "u email", "university email", "mail", "e-mail", "email address"],
    room: ["room", "room number", "bed", "bed space", "unit", "space"],
    role: ["role", "type", "position", "job", "staff type", "designation"],
    wing: ["wing", "section", "block", "community", "hall section"]
};

// Helper to find a matching key in a row object
function findValue(row: any, mappings: Record<string, string[]>, mappingKey: string): string | undefined {
    const keys = Object.keys(row);
    const normalizedKeys = keys.map(k => k.toLowerCase().trim().replace(/_/g, ' '));
    const targets = mappings[mappingKey];

    if (!targets) return undefined;

    // 1. Exact match in our mapping list
    for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const normalized = normalizedKeys[i];
        if (targets.includes(normalized)) {
            return row[key]?.toString().trim();
        }
    }

    // 2. Partial match (Specific to 'email' logic if needed, but risky for general use)
    if (mappingKey.toLowerCase().includes('email')) {
        for (let i = 0; i < keys.length; i++) {
            if (normalizedKeys[i].includes('email') && !normalizedKeys[i].includes('secondary')) {
                // simple heuristic: if looking for 'email' or 'primaryEmail', avoid secondary
                if (mappingKey === 'secondaryEmail' && !normalizedKeys[i].includes('secondary')) continue;
                return row[keys[i]]?.toString().trim();
            }
        }
    }

    return undefined;
}

export function inferFloor(roomNumber: string): number {
    if (!roomNumber) return 1;
    const numericPart = roomNumber.replace(/\D/g, '');
    if (numericPart.length === 3) return Number(numericPart[0]);
    if (numericPart.length === 4) return Number(numericPart.substring(0, 2));
    return 1; // Default
}

export async function parseRosterFile(file: File): Promise<ParseResult> {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();

        reader.onload = (e) => {
            try {
                const data = e.target?.result;
                const workbook = read(data, { type: 'binary' });
                const sheetName = workbook.SheetNames[0];
                const sheet = workbook.Sheets[sheetName];
                const jsonData = utils.sheet_to_json(sheet);

                const result: ParseResult = {
                    residents: [],
                    staff: [],
                    wings: [],
                    errors: []
                };

                const wingsSet = new Set<string>();

                jsonData.forEach((row: any, index) => {
                    // 1. Extract Fields
                    const firstName = findValue(row, COLUMN_MAPPINGS, 'firstName');
                    const lastName = findValue(row, COLUMN_MAPPINGS, 'lastName');
                    const email = findValue(row, COLUMN_MAPPINGS, 'email');
                    const room = findValue(row, COLUMN_MAPPINGS, 'room');
                    const roleRaw = findValue(row, COLUMN_MAPPINGS, 'role');
                    const wing = findValue(row, COLUMN_MAPPINGS, 'wing');

                    // 2. Validation
                    if (!email) {
                        // result.errors.push(`Row ${index + 2}: Missing Email`); // Optional: Skip rows without email silently or log?
                        return;
                    }

                    // 3. Normalize Role
                    let role: 'ra' | 'resident' = 'resident';
                    if (roleRaw) {
                        const lowerRole = roleRaw.toLowerCase();
                        if (lowerRole.includes('ra') || lowerRole.includes('advisor') || lowerRole.includes('staff')) {
                            role = 'ra';
                        }
                    }

                    // 4. Normalize Name
                    // If only "Name" column exists (not split), we might need to handle that, but let's assume split for now or fall back
                    // Ideally we add a "Name" mapper too.
                    let finalFirstName = firstName || "";
                    let finalLastName = lastName || "";

                    if (!finalFirstName && !finalLastName) {
                        // Try to find a generic "Name" column
                        const nameKey = Object.keys(row).find(k => k.toLowerCase().includes('name'));
                        if (nameKey) {
                            const fullName = row[nameKey].toString().trim();
                            const parts = fullName.split(' ');
                            if (parts.length > 1) {
                                finalLastName = parts.pop() || "";
                                finalFirstName = parts.join(" ");
                            } else {
                                finalFirstName = fullName;
                            }
                        }
                    }

                    if (!finalFirstName) {
                        result.errors.push(`Row ${index + 2}: Missing Name for ${email}`);
                        return;
                    }

                    // 5. Build Object
                    const parsedRow: ParsedRosterRow = {
                        firstName: finalFirstName,
                        lastName: finalLastName,
                        email: email,
                        roomNumber: room || "",
                        floor: inferFloor(room || ""),
                        wing: wing,
                        role,
                        originalRow: row
                    };

                    if (wing) wingsSet.add(wing);

                    if (role === 'ra') {
                        result.staff.push(parsedRow);
                    } else {
                        result.residents.push(parsedRow);
                    }
                });

                result.wings = Array.from(wingsSet).sort();
                resolve(result);

            } catch (err) {
                reject(err);
            }
        };

        reader.onerror = (err) => reject(err);
        reader.readAsBinaryString(file);
    });
}

// Schedule Types
export interface ParsedScheduleRow {
    date: Date;
    dateStr: string; // YYYY-MM-DD
    primaryEmail?: string;
    secondaryEmail?: string;
    primaryName?: string;
    secondaryName?: string;
    notes?: string;
    primaryRaId?: string; // Resolved ID
    secondaryRaId?: string; // Resolved ID
    originalRow: any;
}

export interface ScheduleParseResult {
    shifts: ParsedScheduleRow[];
    errors: string[];
    unmatchedRAs: string[]; // Emails or Names found but not matched
}

const SCHEDULE_MAPPINGS = {
    date: ["date", "day", "shift date", "time"],
    primaryEmail: ["primary email", "primary ra email", "ra 1 email", "email 1", "primary"],
    secondaryEmail: ["secondary email", "secondary ra email", "ra 2 email", "email 2", "backup email", "secondary"],
    notes: ["notes", "note", "comments", "description", "details"]
};

export async function parseScheduleFile(file: File, staffList: { id: string, firstName?: string, lastName?: string, email: string }[]): Promise<ScheduleParseResult> {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();

        reader.onload = (e) => {
            try {
                const data = e.target?.result;
                const workbook = read(data, { type: 'binary' });
                const sheetName = workbook.SheetNames[0];
                const sheet = workbook.Sheets[sheetName];
                const jsonData = utils.sheet_to_json(sheet);

                const result: ScheduleParseResult = {
                    shifts: [],
                    errors: [],
                    unmatchedRAs: []
                };

                const unmatchedSet = new Set<string>();

                // Helper to find system RA by unique Email
                const findRaByEmail = (email: string) => {
                    if (!email) return null;
                    const q = email.toLowerCase().trim();
                    return staffList.find(s => s.email.toLowerCase() === q);
                };

                // Fallback: Try to find by name if email fails/missing (legacy support)
                const findRaByName = (name: string) => {
                    if (!name) return null;
                    const q = name.toLowerCase().trim();
                    return staffList.find(s =>
                        ((s.firstName || "") + " " + (s.lastName || "")).toLowerCase().includes(q)
                    );
                };

                jsonData.forEach((row: any, index) => {
                    // 1. Extract Fields
                    const dateRaw = findValue(row, SCHEDULE_MAPPINGS, 'date') || row['Date'];

                    // Prioritize specific email column mappings
                    let primaryVal = findValue(row, SCHEDULE_MAPPINGS, 'primaryEmail');
                    let secondaryVal = findValue(row, SCHEDULE_MAPPINGS, 'secondaryEmail');

                    const notes = findValue(row, SCHEDULE_MAPPINGS, 'notes');

                    // 2. Parse Date
                    let dateObj: Date | null = null;
                    if (dateRaw) {
                        let val = dateRaw;
                        // Coerce numeric string to number if it looks like a timestamp/serial
                        if (typeof val === 'string' && !isNaN(Number(val)) && val.trim() !== '') {
                            val = Number(val);
                        }

                        if (typeof val === 'number') {
                            // Heuristic: Excel dates are typically ~45000. 
                            // Integers > 1,000,000 are likely Unix timestamps (ms).
                            if (val > 1000000000000) {
                                // Trillions -> Milliseconds
                                dateObj = new Date(val);
                            } else if (val > 1000000000) {
                                // Billions -> Seconds
                                dateObj = new Date(val * 1000);
                            } else if (val > 300000) {
                                // Between 300k and 1B? Treat as MS or large serial?
                                // 1389673587600 falls here if truncated? No.
                                dateObj = new Date(val);
                            } else {
                                // Standard Excel Serial Date
                                dateObj = new Date(Math.round((val - 25569) * 86400 * 1000));
                            }
                        } else {
                            // String date (e.g. "2023-01-01")
                            dateObj = new Date(val);
                        }

                        // Debugging log to confirm fix is running
                        console.log(`[Import] Parsed raw ${dateRaw} (${typeof dateRaw}) -> ${dateObj?.toISOString()}`);
                    }

                    if (!dateObj || isNaN(dateObj.getTime())) {
                        return;
                    }

                    const dateStr = dateObj.toISOString().split('T')[0];

                    // 3. Resolve RAs
                    // Logic: exact match email first. If not found, try name match if input looks like a name.
                    let primaryRa = findRaByEmail(primaryVal || "");
                    if (!primaryRa && primaryVal && !primaryVal.includes('@')) {
                        primaryRa = findRaByName(primaryVal);
                    }

                    let secondaryRa = findRaByEmail(secondaryVal || "");
                    if (!secondaryRa && secondaryVal && !secondaryVal.includes('@')) {
                        secondaryRa = findRaByName(secondaryVal);
                    }

                    if (primaryVal && !primaryRa) unmatchedSet.add(primaryVal);
                    if (secondaryVal && !secondaryRa) unmatchedSet.add(secondaryVal);

                    result.shifts.push({
                        date: dateObj,
                        dateStr,
                        primaryEmail: primaryRa?.email || primaryVal,
                        secondaryEmail: secondaryRa?.email || secondaryVal,
                        notes,
                        primaryRaId: primaryRa?.id,
                        secondaryRaId: secondaryRa?.id,
                        originalRow: row
                    });
                });

                result.unmatchedRAs = Array.from(unmatchedSet);
                resolve(result);

            } catch (err) {
                reject(err);
            }
        };

        reader.onerror = (err) => reject(err);
        reader.readAsBinaryString(file);
    });
}
