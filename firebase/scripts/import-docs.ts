import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

// Initialize Firebase Admin
// Expects GOOGLE_APPLICATION_CREDENTIALS or default credentials
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

// Types
interface DocEntry {
    canonicalId?: string;
    topic?: string;
    section?: string;
    text: string;
    sources?: string[];
    order?: number;
}

interface DocFile {
    entries?: DocEntry[];
    [key: string]: any; // Allow other top-level fields
}

// Helper: Slugify filename
function slugify(text: string): string {
    return text.toString().toLowerCase()
        .replace(/\s+/g, '-')           // Replace spaces with -
        .replace(/[^\w\-]+/g, '')       // Remove all non-word chars
        .replace(/\-\-+/g, '-')         // Replace multiple - with single -
        .replace(/^-+/, '')             // Trim - from start
        .replace(/-+$/, '');            // Trim - from end
}

// Helper: Generate deterministic hash for entryId
function generateEntryId(entry: DocEntry, index: number): string {
    if (entry.canonicalId) return entry.canonicalId;

    const data = `${entry.topic || ''}:${entry.section || ''}:${entry.order ?? index}`;
    return crypto.createHash('md5').update(data).digest('hex');
}

// Main Import Function
async function importDocs(sourceDir: string) {
    console.log(`Starting Global Docs Import from ${sourceDir}`);

    if (!fs.existsSync(sourceDir)) {
        console.error(`Source directory not found: ${sourceDir}`);
        process.exit(1);
    }

    const files = fs.readdirSync(sourceDir).filter(f => f.endsWith('.json'));
    console.log(`Found ${files.length} JSON files.`);

    const batchSize = 400; // conservative batch limit
    let totalEntries = 0;
    let totalDocs = 0;

    for (const file of files) {
        const filePath = path.join(sourceDir, file);
        const fileName = path.basename(file, '.json');
        const docId = slugify(fileName);

        console.log(`Processing ${file} -> docId: ${docId}`);

        let content: any;
        try {
            content = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        } catch (e) {
            console.error(`Error parsing JSON ${file}:`, e);
            continue;
        }

        let entries: DocEntry[] = [];
        if (Array.isArray(content)) {
            entries = content;
        } else if (content.entries && Array.isArray(content.entries)) {
            entries = content.entries;
        } else {
            console.warn(`Skipping ${file}: No entries array found.`);
            continue;
        }

        const now = admin.firestore.FieldValue.serverTimestamp();

        // 1. Create/Update Doc Metadata (Global Path)
        const docRef = db.collection('docs').doc(docId);

        // Use batch for doc + entries
        let batch = db.batch();
        let batchCount = 0;

        batch.set(docRef, {
            title: fileName.replace(/_/g, ' ').replace(/-/g, ' '), // rudimentary title from filename
            slug: docId,
            category: 'general', // default category
            isPublished: true,
            updatedAt: now,
            updatedBy: 'system-import', // Script user
            createdAt: now
        }, { merge: true });

        batchCount++;
        totalDocs++;

        // 2. Process Entries
        let orderIndex = 0;
        for (const entry of entries) {
            if (!entry.text) {
                console.warn(`   [WARN] Entry in ${file} missing text. Skipping.`);
                continue;
            }

            const entryId = generateEntryId(entry, orderIndex);
            const entryRef = docRef.collection('entries').doc(entryId);

            const entryData = {
                canonicalId: entry.canonicalId || null,
                topic: entry.topic || null,
                section: entry.section || null,
                text: entry.text,
                sources: entry.sources || [],
                order: entry.order ?? orderIndex,
                updatedAt: now,
                updatedBy: 'system-import',
                createdAt: now // Added createdAt per requirement
            };

            batch.set(entryRef, entryData, { merge: true });
            batchCount++;
            orderIndex++;
            totalEntries++;

            if (batchCount >= batchSize) {
                await batch.commit();
                batch = db.batch();
                batchCount = 0;
            }
        }

        if (batchCount > 0) {
            await batch.commit();
        }
    }

    console.log(`\nImport Complete!`);
    console.log(`Processed ${totalDocs} documents.`);
    console.log(`Processed ${totalEntries} entries.`);
}

// CLI Args
const args = process.argv.slice(2);
// Default to ../docs_json relative to script location (assuming script is in firebase/scripts)
// Or use absolute path /firebase/docs_json as requested
const defaultDir = path.join(__dirname, '..', 'docs_json');

importDocs(defaultDir).catch(console.error);
