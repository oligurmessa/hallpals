/**
 * Seed script to populate Firestore /docs collection from knowledge_base.json
 *
 * Usage:
 *   cd /Users/oligurmessa/hallpals/firebase
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json node scripts/seed-docs.js
 *
 * OR use Firebase CLI auth:
 *   firebase login
 *   Then the script will use Application Default Credentials
 */

const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// Check for service account file in common locations
const serviceAccountPaths = [
  path.join(__dirname, '../serviceAccount.json'),
  path.join(__dirname, '../service-account.json'),
  process.env.GOOGLE_APPLICATION_CREDENTIALS
].filter(Boolean);

let serviceAccount = null;
for (const saPath of serviceAccountPaths) {
  if (saPath && fs.existsSync(saPath)) {
    serviceAccount = require(saPath);
    console.log('Using service account from:', saPath);
    break;
  }
}

// Initialize Firebase Admin
if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'hallpals'
  });
} else {
  // Fall back to application default credentials
  console.log('No service account found, using Application Default Credentials');
  console.log('If this fails, download a service account key from Firebase Console');
  console.log('and save it as firebase/serviceAccount.json');
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'hallpals'
  });
}

const db = admin.firestore();

// Topic slugs matching KBTopic.slug in iOS
const TOPIC_SLUGS = {
  "Duty & On-Call": "duty_&_on-call",
  "Emergencies": "emergencies",
  "Facilities": "facilities",
  "General": "general",
  "Housing": "housing",
  "Incidents": "incidents",
  "Move-in/out": "move-in_out",
  "Policies": "policies",
  "Procedures": "procedures",
  "Safety": "safety",
  "Student Conduct": "student_conduct",
  "Training": "training"
};

// Topic display info
const TOPIC_INFO = {
  "duty_&_on-call": { title: "Duty & On-Call", category: "operations" },
  "emergencies": { title: "Emergencies", category: "safety" },
  "facilities": { title: "Facilities", category: "operations" },
  "general": { title: "General", category: "general" },
  "housing": { title: "Housing", category: "housing" },
  "incidents": { title: "Incidents", category: "operations" },
  "move-in_out": { title: "Move-in/out", category: "housing" },
  "policies": { title: "Policies", category: "compliance" },
  "procedures": { title: "Procedures", category: "operations" },
  "safety": { title: "Safety", category: "safety" },
  "student_conduct": { title: "Student Conduct", category: "compliance" },
  "training": { title: "Training", category: "training" }
};

async function seedDocs() {
  console.log('Starting Firestore docs seed...\n');

  // Load knowledge base
  const kbPath = path.join(__dirname, '../../apps/ios/HallHub/HallHub/Features/Resources/knowledge_base.json');

  if (!fs.existsSync(kbPath)) {
    console.error('knowledge_base.json not found at:', kbPath);
    process.exit(1);
  }

  const kbData = JSON.parse(fs.readFileSync(kbPath, 'utf8'));
  console.log(`Loaded ${kbData.length} entries from knowledge_base.json\n`);

  // Group entries by topic
  const entriesByTopic = {};
  for (const entry of kbData) {
    const topic = entry.topic;
    if (!entriesByTopic[topic]) {
      entriesByTopic[topic] = [];
    }
    entriesByTopic[topic].push(entry);
  }

  console.log('Topics found:', Object.keys(entriesByTopic));
  console.log('');

  const now = admin.firestore.FieldValue.serverTimestamp();

  // Create doc for each topic
  for (const [topicName, entries] of Object.entries(entriesByTopic)) {
    const slug = TOPIC_SLUGS[topicName];

    if (!slug) {
      console.warn(`⚠️  Unknown topic "${topicName}", skipping...`);
      continue;
    }

    const info = TOPIC_INFO[slug];
    console.log(`📝 Creating /docs/${slug} with ${entries.length} entries...`);

    // Create the doc metadata
    const docRef = db.collection('docs').doc(slug);
    await docRef.set({
      title: info.title,
      slug: slug,
      category: info.category,
      isPublished: true,
      createdAt: now,
      updatedAt: now,
      entryCount: entries.length
    });

    // Create entries subcollection
    const entriesRef = docRef.collection('entries');

    let order = 0;
    for (const entry of entries) {
      order++;
      const entryId = entry.canonical_id || `entry_${order}`;

      await entriesRef.doc(entryId).set({
        order: order,
        topic: topicName,
        section: entry.section || 'General',
        text: entry.text,
        sources: entry.sources || [],
        createdAt: now,
        updatedAt: now
      });
    }

    console.log(`   ✅ Created ${entries.length} entries`);
  }

  // Also ensure all 12 topics exist (even if empty)
  for (const [slug, info] of Object.entries(TOPIC_INFO)) {
    const docRef = db.collection('docs').doc(slug);
    const doc = await docRef.get();

    if (!doc.exists) {
      console.log(`📝 Creating empty /docs/${slug}...`);
      await docRef.set({
        title: info.title,
        slug: slug,
        category: info.category,
        isPublished: true,
        createdAt: now,
        updatedAt: now,
        entryCount: 0
      });
      console.log(`   ✅ Created (empty)`);
    }
  }

  console.log('\n✅ Seed complete!');
  process.exit(0);
}

seedDocs().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
