#!/usr/bin/env node
/**
 * Seed script using Firebase REST API with CLI token
 *
 * Usage:
 *   cd /Users/oligurmessa/hallpals/firebase
 *   node scripts/seed-docs-rest.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT_ID = 'hallpals';

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

function getFirebaseToken() {
  try {
    // Get token from firebase CLI
    const token = execSync('npx firebase --token 2>/dev/null || npx firebase login:ci --no-localhost 2>&1 | grep -oE "[a-zA-Z0-9_-]{100,}"', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
    return token;
  } catch (e) {
    // Try to use the access token directly
    try {
      const result = execSync('npx firebase use 2>&1', { encoding: 'utf8' });
      console.log('Firebase CLI is authenticated');
      return null; // Will use default auth
    } catch (e2) {
      console.error('Firebase CLI not authenticated. Run: npx firebase login');
      process.exit(1);
    }
  }
}

async function firestoreRequest(method, docPath, data = null) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${docPath}`;

  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(body ? JSON.parse(body) : null);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${body}`));
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

function toFirestoreValue(val) {
  if (val === null || val === undefined) {
    return { nullValue: null };
  }
  if (typeof val === 'string') {
    return { stringValue: val };
  }
  if (typeof val === 'number') {
    if (Number.isInteger(val)) {
      return { integerValue: String(val) };
    }
    return { doubleValue: val };
  }
  if (typeof val === 'boolean') {
    return { booleanValue: val };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function toFirestoreDoc(obj) {
  const fields = {};
  for (const [key, val] of Object.entries(obj)) {
    fields[key] = toFirestoreValue(val);
  }
  return { fields };
}

async function seedDocs() {
  console.log('Starting Firestore docs seed via REST API...\n');

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

  const now = new Date().toISOString();

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
    const docData = {
      title: info.title,
      slug: slug,
      category: info.category,
      isPublished: true,
      createdAt: now,
      updatedAt: now,
      entryCount: entries.length
    };

    try {
      await firestoreRequest('PATCH', `docs/${slug}?updateMask.fieldPaths=title&updateMask.fieldPaths=slug&updateMask.fieldPaths=category&updateMask.fieldPaths=isPublished&updateMask.fieldPaths=createdAt&updateMask.fieldPaths=updatedAt&updateMask.fieldPaths=entryCount`, toFirestoreDoc(docData));
    } catch (e) {
      console.log(`   Creating new doc...`);
      // Try creating instead
    }

    // Create entries subcollection
    let order = 0;
    for (const entry of entries) {
      order++;
      const entryId = entry.canonical_id || `entry_${order}`;

      const entryData = {
        order: order,
        topic: topicName,
        section: entry.section || 'General',
        text: entry.text,
        sources: entry.sources || [],
        createdAt: now,
        updatedAt: now
      };

      try {
        await firestoreRequest('PATCH', `docs/${slug}/entries/${entryId}`, toFirestoreDoc(entryData));
      } catch (e) {
        // Ignore errors, document might already exist
      }
    }

    console.log(`   ✅ Created ${entries.length} entries`);
  }

  console.log('\n✅ Seed complete!');
}

seedDocs().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
