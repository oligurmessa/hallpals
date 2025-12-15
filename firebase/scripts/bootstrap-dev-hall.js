/**
 * Bootstrap script to create the dev hall (hall-001) in Firestore
 * Run this once to set up the development environment
 *
 * Usage: node firebase/scripts/bootstrap-dev-hall.js
 *
 * Note: Requires Firebase Admin SDK credentials
 * Set GOOGLE_APPLICATION_CREDENTIALS env var to path of service account key
 */

const admin = require('firebase-admin');

// Initialize with default credentials (uses GOOGLE_APPLICATION_CREDENTIALS)
// Or you can use: admin.initializeApp({ projectId: 'hallpals-64c06' });
admin.initializeApp();

const db = admin.firestore();

async function bootstrapDevHall() {
    const hallId = 'hall-001';
    const hallRef = db.collection('halls').doc(hallId);

    // Check if hall already exists
    const snapshot = await hallRef.get();

    if (snapshot.exists) {
        console.log(`✅ Hall ${hallId} already exists`);
        console.log('Data:', snapshot.data());
        return;
    }

    // Create the hall document
    const hallData = {
        name: 'Development Hall',
        shortName: 'DevHall',
        address: '123 Dev Street',
        floors: [1, 2, 3, 4, 5],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
    };

    await hallRef.set(hallData);
    console.log(`✅ Created hall ${hallId}`);
    console.log('Data:', hallData);
}

bootstrapDevHall()
    .then(() => {
        console.log('\n🎉 Bootstrap complete!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Error:', error);
        process.exit(1);
    });
