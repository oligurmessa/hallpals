/**
 * HallPals Security Rules Verification Script
 *
 * This script tests Firestore security rules against the emulator using
 * real Auth UIDs and the Firebase REST API.
 *
 * Prerequisites:
 *   cd firebase && npx firebase emulators:start --project hallpals-dev
 *
 * Run with:
 *   node test-rules.js
 */

const http = require("http");

// Configuration
const PROJECT_ID = "hallpals-dev";
const AUTH_HOST = "127.0.0.1";
const AUTH_PORT = 9099;
const FIRESTORE_HOST = "127.0.0.1";
const FIRESTORE_PORT = 8080;

// Test data
const HALL_ID = "test-hall-001";
const RA_EMAIL = "ra@hallpals.test";
const RESIDENT_EMAIL = "resident@hallpals.test";
const OUTSIDER_EMAIL = "outsider@hallpals.test";

let raUid = null;
let residentUid = null;
let outsiderUid = null;

// ============================================================
// HTTP Helpers
// ============================================================

function httpRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve({
            status: res.statusCode,
            data: data ? JSON.parse(data) : null,
          });
        } catch {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(typeof body === "string" ? body : JSON.stringify(body));
    req.end();
  });
}

// ============================================================
// Auth Emulator API
// ============================================================

async function clearAuthUsers() {
  return httpRequest({
    hostname: AUTH_HOST,
    port: AUTH_PORT,
    path: `/emulator/v1/projects/${PROJECT_ID}/accounts`,
    method: "DELETE",
  });
}

async function createAuthUser(email) {
  const result = await httpRequest(
    {
      hostname: AUTH_HOST,
      port: AUTH_PORT,
      path: `/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
      method: "POST",
      headers: { "Content-Type": "application/json" },
    },
    { email, password: "testpass123", returnSecureToken: true }
  );

  if (result.data?.localId) {
    return result.data.localId;
  }
  console.error("  Failed to create user:", result.data?.error?.message || result.status);
  return null;
}

async function getIdToken(email) {
  const result = await httpRequest(
    {
      hostname: AUTH_HOST,
      port: AUTH_PORT,
      path: `/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
      method: "POST",
      headers: { "Content-Type": "application/json" },
    },
    { email, password: "testpass123", returnSecureToken: true }
  );

  if (result.data?.idToken) {
    return result.data.idToken;
  }
  console.error("  Failed to get token for", email, ":", result.data?.error?.message);
  return null;
}

// ============================================================
// Firestore Emulator API
// ============================================================

async function clearFirestore() {
  return httpRequest({
    hostname: FIRESTORE_HOST,
    port: FIRESTORE_PORT,
    path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    method: "DELETE",
  });
}

function firestoreValue(val) {
  if (typeof val === "string") return { stringValue: val };
  if (typeof val === "number") return Number.isInteger(val) ? { integerValue: String(val) } : { doubleValue: val };
  if (typeof val === "boolean") return { booleanValue: val };
  if (val instanceof Date) return { timestampValue: val.toISOString() };
  if (Array.isArray(val)) return { arrayValue: { values: val.map(firestoreValue) } };
  if (val === null) return { nullValue: null };
  if (typeof val === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(val)) fields[k] = firestoreValue(v);
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function toFirestoreDoc(data) {
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = firestoreValue(value);
  }
  return { fields };
}

// Admin write - bypasses security rules using "owner" token
async function firestoreAdminWrite(path, data) {
  return httpRequest(
    {
      hostname: FIRESTORE_HOST,
      port: FIRESTORE_PORT,
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer owner",  // Emulator bypass token
      },
    },
    toFirestoreDoc(data)
  );
}

async function firestoreWrite(path, data, token = null) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  return httpRequest(
    {
      hostname: FIRESTORE_HOST,
      port: FIRESTORE_PORT,
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
      method: "PATCH",
      headers,
    },
    toFirestoreDoc(data)
  );
}

async function firestoreRead(path, token = null) {
  const headers = {};
  if (token) headers["Authorization"] = `Bearer ${token}`;

  return httpRequest({
    hostname: FIRESTORE_HOST,
    port: FIRESTORE_PORT,
    path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
    method: "GET",
    headers,
  });
}

async function firestoreCreate(collectionPath, docId, data, token = null) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  return httpRequest(
    {
      hostname: FIRESTORE_HOST,
      port: FIRESTORE_PORT,
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collectionPath}?documentId=${docId}`,
      method: "POST",
      headers,
    },
    toFirestoreDoc(data)
  );
}

// ============================================================
// Test Utilities
// ============================================================

function logTest(name, passed, details = "") {
  const icon = passed ? "✅" : "❌";
  console.log(`${icon} ${name}${details ? ` - ${details}` : ""}`);
  return passed;
}

function expectAllow(result, testName) {
  const passed = result.status >= 200 && result.status < 300;
  return logTest(testName, passed, passed ? "ALLOWED" : `DENIED (${result.status})`);
}

function expectDeny(result, testName) {
  const passed = result.status === 403 || result.status === 401 || (result.status >= 400 && result.status < 500);
  return logTest(testName, passed, passed ? "DENIED" : `UNEXPECTEDLY ALLOWED (${result.status})`);
}

// ============================================================
// Main Test Suite
// ============================================================

async function setup() {
  console.log("\n🔧 SETUP\n" + "=".repeat(50));

  // Clear existing data
  console.log("Clearing Auth emulator...");
  await clearAuthUsers();

  console.log("Clearing Firestore emulator...");
  await clearFirestore();

  // Create test users
  console.log("Creating test users...");
  raUid = await createAuthUser(RA_EMAIL);
  if (!raUid) throw new Error("Failed to create RA user");
  console.log(`  RA user: ${raUid}`);

  residentUid = await createAuthUser(RESIDENT_EMAIL);
  if (!residentUid) throw new Error("Failed to create resident user");
  console.log(`  Resident user: ${residentUid}`);

  outsiderUid = await createAuthUser(OUTSIDER_EMAIL);
  if (!outsiderUid) throw new Error("Failed to create outsider user");
  console.log(`  Outsider user: ${outsiderUid}`);

  // Seed hall and membership data using admin bypass
  console.log("\nSeeding test data (admin writes with 'owner' bypass)...");

  // Create hall
  let result = await firestoreAdminWrite(`halls/${HALL_ID}`, {
    name: "Test Hall",
    building: "Building A",
    createdAt: new Date(),
  });
  if (result.status >= 400) {
    console.error("  Failed to create hall:", result.status, result.data);
  } else {
    console.log(`  Created hall: ${HALL_ID}`);
  }

  // Create RA membership
  result = await firestoreAdminWrite(`halls/${HALL_ID}/members/${raUid}`, {
    role: "ra",
    room: "101",
    joinedAt: new Date(),
  });
  if (result.status >= 400) {
    console.error("  Failed to create RA membership:", result.status);
  } else {
    console.log(`  Created RA membership: ${raUid}`);
  }

  // Create resident membership
  result = await firestoreAdminWrite(`halls/${HALL_ID}/members/${residentUid}`, {
    role: "resident",
    room: "102",
    joinedAt: new Date(),
  });
  if (result.status >= 400) {
    console.error("  Failed to create resident membership:", result.status);
  } else {
    console.log(`  Created resident membership: ${residentUid}`);
  }

  // NOTE: outsiderUid has NO membership in HALL_ID - this is intentional

  // Create a room
  await firestoreAdminWrite(`halls/${HALL_ID}/rooms/room-101`, {
    roomNumber: "101",
    floor: "1",
    residentIds: [raUid],
  });
  console.log(`  Created room: room-101`);

  // Create user docs
  await firestoreAdminWrite(`users/${raUid}`, {
    email: RA_EMAIL,
    displayName: "Test RA",
    role: "ra",
    hallId: HALL_ID,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  await firestoreAdminWrite(`users/${residentUid}`, {
    email: RESIDENT_EMAIL,
    displayName: "Test Resident",
    role: "resident",
    hallId: HALL_ID,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  await firestoreAdminWrite(`users/${outsiderUid}`, {
    email: OUTSIDER_EMAIL,
    displayName: "Outsider User",
    role: "resident",
    hallId: "other-hall",
    createdAt: new Date(),
    updatedAt: new Date(),
  });
  console.log(`  Created user docs`);

  // Create a conversation for message tests
  await firestoreAdminWrite(`halls/${HALL_ID}/conversations/conv-001`, {
    type: "dm",
    participantIds: [raUid, residentUid],
    lastMessage: "",
    lastMessageAt: new Date(),
    createdAt: new Date(),
  });
  console.log(`  Created conversation: conv-001`);

  console.log("\n✅ Setup complete!\n");
}

async function runTests() {
  let passed = 0;
  let failed = 0;

  const track = (result) => {
    if (result) passed++;
    else failed++;
  };

  // Get tokens
  console.log("Getting auth tokens...");
  const raToken = await getIdToken(RA_EMAIL);
  const residentToken = await getIdToken(RESIDENT_EMAIL);
  const outsiderToken = await getIdToken(OUTSIDER_EMAIL);

  if (!raToken || !residentToken || !outsiderToken) {
    throw new Error("Failed to get auth tokens");
  }
  console.log("  Tokens acquired\n");

  console.log("🧪 SECURITY RULES TESTS\n" + "=".repeat(50));

  // ============================================================
  // TEST 1: Member can read hall data
  // ============================================================
  console.log("\n📋 Test 1: Member can read hall-scoped docs");
  track(expectAllow(
    await firestoreRead(`halls/${HALL_ID}`, raToken),
    "RA reads hall doc"
  ));
  track(expectAllow(
    await firestoreRead(`halls/${HALL_ID}/members/${raUid}`, raToken),
    "RA reads own membership"
  ));
  track(expectAllow(
    await firestoreRead(`halls/${HALL_ID}/rooms/room-101`, raToken),
    "RA reads room"
  ));

  // ============================================================
  // TEST 2: Non-member denied
  // ============================================================
  console.log("\n📋 Test 2: Non-member gets denied");
  track(expectDeny(
    await firestoreRead(`halls/${HALL_ID}`, outsiderToken),
    "Outsider reads hall doc"
  ));
  track(expectDeny(
    await firestoreRead(`halls/${HALL_ID}/rooms/room-101`, outsiderToken),
    "Outsider reads room"
  ));

  // ============================================================
  // TEST 3: RA can read/write inspections
  // ============================================================
  console.log("\n📋 Test 3: RA can read/write room inspections");
  track(expectAllow(
    await firestoreCreate(`halls/${HALL_ID}/room_inspections`, "insp-001", {
      roomId: "room-101",
      inspectorId: raUid,
      isComplete: false,
      checklist: [],
      notes: "",
      photoUrls: [],
      createdAt: new Date(),
    }, raToken),
    "RA creates inspection"
  ));
  track(expectAllow(
    await firestoreRead(`halls/${HALL_ID}/room_inspections/insp-001`, raToken),
    "RA reads inspection"
  ));

  // ============================================================
  // TEST 4: Resident cannot read inspections
  // ============================================================
  console.log("\n📋 Test 4: Resident cannot access inspections");
  track(expectDeny(
    await firestoreRead(`halls/${HALL_ID}/room_inspections/insp-001`, residentToken),
    "Resident reads inspection"
  ));
  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/room_inspections`, "insp-002", {
      roomId: "room-102",
      inspectorId: residentUid,
      isComplete: false,
    }, residentToken),
    "Resident creates inspection"
  ));

  // ============================================================
  // TEST 5: DM creation works
  // ============================================================
  console.log("\n📋 Test 5: DM creation works for members");
  track(expectAllow(
    await firestoreCreate(`halls/${HALL_ID}/conversations`, "new-dm-001", {
      type: "dm",
      participantIds: [raUid, residentUid],
      lastMessage: "",
      lastMessageAt: new Date(),
      createdAt: new Date(),
    }, raToken),
    "RA creates DM conversation"
  ));

  // ============================================================
  // TEST 5b: Self-DM creation denied (hardening)
  // ============================================================
  console.log("\n📋 Test 5b: Self-DM creation denied (hardening)");
  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/conversations`, "self-dm-001", {
      type: "dm",
      participantIds: [raUid, raUid],  // Same user twice - not allowed!
      lastMessage: "",
      lastMessageAt: new Date(),
      createdAt: new Date(),
    }, raToken),
    "RA creates DM with self"
  ));

  // ============================================================
  // TEST 6: Group creation denied
  // ============================================================
  console.log("\n📋 Test 6: Group creation denied for non-admin");
  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/conversations`, "new-group-001", {
      type: "group",
      name: "Test Group",
      participantIds: [raUid, residentUid],
      lastMessage: "",
      lastMessageAt: new Date(),
      createdAt: new Date(),
    }, raToken),
    "RA creates group conversation"
  ));

  // ============================================================
  // TEST 7: Message creation works for participant
  // ============================================================
  console.log("\n📋 Test 7: Message creation works for participant");
  track(expectAllow(
    await firestoreCreate(`halls/${HALL_ID}/conversations/conv-001/messages`, "msg-001", {
      senderId: raUid,
      text: "Hello from RA!",
      createdAt: new Date(),
    }, raToken),
    "RA creates message with own senderId"
  ));

  // ============================================================
  // TEST 8: Wrong senderId denied
  // ============================================================
  console.log("\n📋 Test 8: Message with wrong senderId denied");
  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/conversations/conv-001/messages`, "msg-002", {
      senderId: residentUid,  // Wrong! Should be raUid
      text: "Impersonation attempt",
      createdAt: new Date(),
    }, raToken),
    "RA creates message with wrong senderId"
  ));

  // ============================================================
  // TEST 8b: Message schema validation - empty message denied (hardening)
  // ============================================================
  console.log("\n📋 Test 8b: Message schema validation (hardening)");
  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/conversations/conv-001/messages`, "msg-empty", {
      senderId: raUid,
      text: "",  // Empty text - not allowed!
      createdAt: new Date(),
    }, raToken),
    "Empty text message denied"
  ));

  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/conversations/conv-001/messages`, "msg-no-content", {
      senderId: raUid,
      // No text or imageUrl - not allowed!
      createdAt: new Date(),
    }, raToken),
    "Message without text or imageUrl denied"
  ));

  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/conversations/conv-001/messages`, "msg-no-timestamp", {
      senderId: raUid,
      text: "Hello",
      // No createdAt - not allowed!
    }, raToken),
    "Message without createdAt denied"
  ));

  track(expectAllow(
    await firestoreCreate(`halls/${HALL_ID}/conversations/conv-001/messages`, "msg-image-only", {
      senderId: raUid,
      imageUrl: "https://storage.example.com/image.png",
      createdAt: new Date(),
    }, raToken),
    "Message with imageUrl only allowed"
  ));

  // ============================================================
  // TEST 9: Rounds session creation
  // ============================================================
  console.log("\n📋 Test 9: Rounds session creation for RA");
  track(expectAllow(
    await firestoreCreate(`halls/${HALL_ID}/rounds_sessions`, "session-001", {
      userId: raUid,
      status: "inProgress",
      startTime: new Date(),
      startingFloor: 1,
      currentFloor: 1,
      totalSteps: 0,
    }, raToken),
    "RA creates rounds session"
  ));

  // ============================================================
  // TEST 10: Cannot set overallCoverage
  // ============================================================
  console.log("\n📋 Test 10: Cannot set protected overallCoverage field");
  track(expectDeny(
    await firestoreCreate(`halls/${HALL_ID}/rounds_sessions`, "session-002", {
      userId: raUid,
      status: "inProgress",
      startTime: new Date(),
      overallCoverage: 0.95,  // Not allowed!
    }, raToken),
    "RA creates session with overallCoverage"
  ));

  // ============================================================
  // TEST 11: User can read own user doc
  // ============================================================
  console.log("\n📋 Test 11: User can read own user doc");
  track(expectAllow(
    await firestoreRead(`users/${raUid}`, raToken),
    "RA reads own user doc"
  ));

  // ============================================================
  // TEST 12: User devices subcollection
  // ============================================================
  console.log("\n📋 Test 12: User can manage own devices");
  track(expectAllow(
    await firestoreCreate(`users/${raUid}/devices`, "device-001", {
      token: "fcm-token-12345",
      platform: "ios",
      createdAt: new Date(),
    }, raToken),
    "RA creates own device doc"
  ));

  // ============================================================
  // Summary
  // ============================================================
  console.log("\n" + "=".repeat(50));
  console.log(`📊 RESULTS: ${passed} passed, ${failed} failed`);
  console.log("=".repeat(50));

  return failed === 0;
}

async function main() {
  console.log("🔒 HallPals Security Rules Verification");
  console.log("========================================\n");
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Auth Emulator: http://${AUTH_HOST}:${AUTH_PORT}`);
  console.log(`Firestore Emulator: http://${FIRESTORE_HOST}:${FIRESTORE_PORT}`);

  try {
    await setup();
    const success = await runTests();
    process.exit(success ? 0 : 1);
  } catch (error) {
    console.error("\n❌ Test failed with error:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
