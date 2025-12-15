/**
 * HallPals Cloud Functions
 * Phase C3.2: Global Chat with tenantId boundary
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v1/auth";

admin.initializeApp();

const db = admin.firestore();

// Default tenant ID for development
const DEFAULT_TENANT_ID = "ust";

// ============================================================
// TYPES
// ============================================================

type UserRole = "resident" | "ra" | "staff";
type ConversationType = "dm" | "group";
type MemberStatus = "active" | "left" | "banned";
type MemberRole = "member" | "admin";

interface JoinHallRequest {
  code: string;
  hallId?: string; // Optional, defaults to "hall-001"
}

interface JoinHallResponse {
  success: boolean;
  role: UserRole;
  hallId: string;
  message: string;
}

interface HallChangeRequest {
  action: "create" | "update" | "delete";
  hallId: string;
  hallData?: {
    name?: string;
    shortName?: string;
    address?: string;
    floors?: number[];
    wings?: string[];
    isActive?: boolean;
  };
}

interface HallChangeResponse {
  success: boolean;
  hallId: string;
  message: string;
}

// Chat types (global - no hallId)
interface CreateDMRequest {
  otherUid: string;
}

interface CreateDMResponse {
  conversationId: string;
  created: boolean;
}

interface CreateGroupRequest {
  title: string;
  memberUids: string[];
}

interface CreateGroupResponse {
  conversationId: string;
}

interface SendMessageRequest {
  conversationId: string;
  messageId: string;
  text?: string;
  imageUrl?: string;
}

interface SendMessageResponse {
  messageId: string;
  createdAt: admin.firestore.Timestamp;
}

interface UpdateLastReadRequest {
  conversationId: string;
  lastReadAt: admin.firestore.Timestamp;
}

// ============================================================
// ROLE CODE MAPPING
// Dev codes bypass manifest check; production codes require manifest
// ============================================================

const DEV_ROLE_CODES: Record<string, UserRole> = {
  "DEVRES": "resident",
  "DEVRA": "ra",
  "DEVLEAD": "staff",
};

// Production codes (would require manifest verification)
const PROD_ROLE_CODES: Record<string, UserRole> = {
  // Add production codes here when ready
};

// Combined codes for validation
const ROLE_CODES: Record<string, UserRole> = {
  ...DEV_ROLE_CODES,
  ...PROD_ROLE_CODES,
};

// Check if code is a dev code (bypasses manifest)
function isDevCode(code: string): boolean {
  return code in DEV_ROLE_CODES;
}

// ============================================================
// HEALTH CHECK
// ============================================================

export const healthCheck = functions.https.onRequest((req, res) => {
  res.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    version: "0.1.0",
  });
});

// ============================================================
// joinHallWithCode
// Callable function for user registration with role assignment
// ============================================================

export const joinHallWithCode = functions.https.onCall(
  async (data: JoinHallRequest, context): Promise<JoinHallResponse> => {
    // 1. Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const email = context.auth.token.email?.toLowerCase().trim();

    if (!email) {
      throw new HttpsError("invalid-argument", "User email is required");
    }

    // 2. Validate code
    const code = data.code?.toUpperCase().trim();
    if (!code) {
      throw new HttpsError("invalid-argument", "Code is required");
    }

    const requestedRole = ROLE_CODES[code];
    if (!requestedRole) {
      throw new HttpsError("invalid-argument", "Invalid code");
    }

    // 3. Determine hall ID
    const hallId = data.hallId || "hall-001";

    // 4. Ensure hall exists (auto-create default hall if missing)
    const hallRef = db.collection("halls").doc(hallId);
    const hallDoc = await hallRef.get();

    if (!hallDoc.exists) {
      // Auto-create hall-001 (default hall) if it doesn't exist
      if (hallId === "hall-001") {
        console.log("Auto-creating default hall-001");
        const now = admin.firestore.FieldValue.serverTimestamp();
        await hallRef.set({
          name: "Default Hall",
          shortName: "DH",
          address: "",
          floors: [1, 2, 3],
          isActive: true,
          createdAt: now,
          updatedAt: now,
          createdBy: "system",
        });
      } else {
        // Non-default halls must be created explicitly by staff
        throw new HttpsError("not-found", `Hall ${hallId} does not exist`);
      }
    }

    // 5. Role validation via manifest (for elevated roles)
    // Dev codes bypass manifest check for easier testing
    let finalRole = requestedRole;

    if (isDevCode(code)) {
      // Dev codes grant role directly without manifest check
      console.log(`Dev code used: ${code} -> ${requestedRole} for ${email}`);
    } else if (requestedRole === "ra") {
      // Production: Check if email is in RA manifest
      const raManifest = await db
        .collection("role_manifests")
        .doc("ra")
        .collection("emails")
        .doc(email)
        .get();

      if (!raManifest.exists) {
        console.log(`Email ${email} not in RA manifest, defaulting to resident`);
        finalRole = "resident";
      }
    } else if (requestedRole === "staff") {
      // Production: Check if email is in staff/leadership manifest
      const staffManifest = await db
        .collection("role_manifests")
        .doc("staff")
        .collection("emails")
        .doc(email)
        .get();

      if (!staffManifest.exists) {
        console.log(`Email ${email} not in staff manifest, defaulting to resident`);
        finalRole = "resident";
      }
    }
    // resident role needs no manifest check

    // 6. Create/update user document (with tenantId for global chat)
    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      // Update existing user - also ensure tenantId is set
      await userRef.update({
        role: finalRole,
        hallId: hallId,
        tenantId: DEFAULT_TENANT_ID,
        updatedAt: now,
      });
    } else {
      // Create new user with tenantId
      await userRef.set({
        email: email,
        displayName: context.auth.token.name || "",
        role: finalRole,
        hallId: hallId,
        tenantId: DEFAULT_TENANT_ID,
        createdAt: now,
        updatedAt: now,
      });
    }

    // 7. Create hall membership
    const memberRef = db
      .collection("halls")
      .doc(hallId)
      .collection("members")
      .doc(uid);

    const memberDoc = await memberRef.get();

    if (!memberDoc.exists) {
      await memberRef.set({
        role: finalRole,
        joinedAt: now,
        isActive: true,
      });
    } else {
      // Update existing membership
      await memberRef.update({
        role: finalRole,
        isActive: true,
      });
    }

    // 8. Create/update public profile (privacy: no email, limited fields)
    const displayName = context.auth.token.name || "";
    const profileRef = db
      .collection("halls")
      .doc(hallId)
      .collection("profiles")
      .doc(uid);

    await profileRef.set({
      displayName: displayName,
      role: finalRole,
      updatedAt: now,
    }, { merge: true });

    console.log(`User ${uid} joined hall ${hallId} as ${finalRole}`);

    return {
      success: true,
      role: finalRole,
      hallId: hallId,
      message: requestedRole !== finalRole ?
        `Joined as ${finalRole} (${requestedRole} requires manifest approval)` :
        `Successfully joined as ${finalRole}`,
    };
  }
);

// ============================================================
// requestHallChange
// Callable function for staff/leadership to manage halls
// ============================================================

export const requestHallChange = functions.https.onCall(
  async (data: HallChangeRequest, context): Promise<HallChangeResponse> => {
    // 1. Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;

    // 2. Validate request
    const { action, hallId, hallData } = data;

    if (!action || !["create", "update", "delete"].includes(action)) {
      throw new HttpsError("invalid-argument", "Invalid action");
    }

    if (!hallId) {
      throw new HttpsError("invalid-argument", "Hall ID is required");
    }

    // 3. Check if user is staff/leadership in any hall
    // For create, check staff manifest. For update/delete, check membership.
    const userDoc = await db.collection("users").doc(uid).get();

    if (!userDoc.exists) {
      throw new HttpsError("permission-denied", "User not found");
    }

    const userData = userDoc.data();

    if (action === "create") {
      // Only staff manifest members can create halls
      const email = context.auth.token.email?.toLowerCase().trim();
      if (!email) {
        throw new HttpsError("invalid-argument", "User email is required");
      }

      const staffManifest = await db
        .collection("role_manifests")
        .doc("staff")
        .collection("emails")
        .doc(email)
        .get();

      let isAuthorized = false;

      // Check manifest first (source of truth)
      if (staffManifest.exists) {
        isAuthorized = true;
      } else {
        // Fallback: Check if user doc has 'staff' role (e.g. via DEVLEAD code)
        // This honours the dev backdoor created in joinHallWithCode
        if (userData?.role === "staff") {
          console.log(`User ${uid} allowed to create hall via user role (DEVLEAD bypass)`);
          isAuthorized = true;
        }
      }

      if (!isAuthorized) {
        throw new HttpsError(
          "permission-denied",
          "Only staff manifest members can create halls"
        );
      }

      // Create the hall
      const now = admin.firestore.FieldValue.serverTimestamp();
      await db.collection("halls").doc(hallId).set({
        name: hallData?.name || hallId,
        shortName: hallData?.shortName || hallId,
        address: hallData?.address || "",
        floors: hallData?.floors || [1, 2, 3],
        isActive: hallData?.isActive ?? true,
        createdAt: now,
        updatedAt: now,
        createdBy: uid,
      });

      // CRITICAL: Add creator as a staff member so they can see/manage the hall
      await db.collection("halls").doc(hallId).collection("members").doc(uid).set({
        role: "staff",
        isActive: true,
        joinedAt: now,
      });

      // Also create profile
      const userProfile = await db.collection("users").doc(uid).get();
      const displayName = userProfile.data()?.displayName || "Staff Member";

      await db.collection("halls").doc(hallId).collection("profiles").doc(uid).set({
        displayName: displayName,
        role: "staff",
        updatedAt: now,
      });

      // Update user's current hall if they don't have one (or maybe even if they do?)
      // Let's set it to this new hall so they are immediately "in" it context-wise
      await db.collection("users").doc(uid).update({
        hallId: hallId,
        role: "staff",
        updatedAt: now,
      });

      console.log(`Hall ${hallId} created by ${uid}`);

      return {
        success: true,
        hallId: hallId,
        message: `Hall ${hallId} created successfully`,
      };
    }

    // For update/delete, must be staff in that specific hall OR global admin
    const isGlobalAdmin = userData?.role === "admin";
    if (!isGlobalAdmin && userData?.role !== "staff") {
      // Also check membership directly
      const memberDoc = await db
        .collection("halls")
        .doc(hallId)
        .collection("members")
        .doc(uid)
        .get();

      if (!memberDoc.exists || memberDoc.data()?.role !== "staff") {
        throw new HttpsError(
          "permission-denied",
          "Only staff of this hall (or admins) can modify it"
        );
      }
    }

    if (action === "update") {
      if (!hallData) {
        throw new HttpsError("invalid-argument", "Hall data is required for update");
      }

      const hallDoc = await db.collection("halls").doc(hallId).get();
      if (!hallDoc.exists) {
        throw new HttpsError("not-found", `Hall ${hallId} does not exist`);
      }

      const updateData: Record<string, unknown> = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (hallData.name !== undefined) updateData.name = hallData.name;
      if (hallData.shortName !== undefined) updateData.shortName = hallData.shortName;
      if (hallData.address !== undefined) updateData.address = hallData.address;
      if (hallData.floors !== undefined) updateData.floors = hallData.floors;
      if (hallData.wings !== undefined) updateData["wings"] = hallData.wings;
      if (hallData.isActive !== undefined) updateData.isActive = hallData.isActive;

      await db.collection("halls").doc(hallId).update(updateData);

      console.log(`Hall ${hallId} updated by ${uid}`);

      return {
        success: true,
        hallId: hallId,
        message: `Hall ${hallId} updated successfully`,
      };
    }

    if (action === "delete") {
      const hallDoc = await db.collection("halls").doc(hallId).get();
      if (!hallDoc.exists) {
        throw new HttpsError("not-found", `Hall ${hallId} does not exist`);
      }

      // Soft delete - just mark as inactive
      await db.collection("halls").doc(hallId).update({
        isActive: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletedBy: uid,
      });

      console.log(`Hall ${hallId} soft-deleted by ${uid}`);

      return {
        success: true,
        hallId: hallId,
        message: `Hall ${hallId} deactivated successfully`,
      };
    }

    throw new HttpsError("invalid-argument", "Unknown action");
  }
);

// ============================================================
// onUserCreated (Auth Trigger)
// Creates /users/{uid} document when Firebase Auth user is created
// Sets default tenantId for global chat; role/hall finalized by joinHallWithCode
// ============================================================

export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const { uid, email, displayName } = user;

  const userRef = db.collection("users").doc(uid);
  const existingDoc = await userRef.get();

  if (existingDoc.exists) {
    // Document already exists (shouldn't happen, but handle gracefully)
    console.log(`User document already exists for ${uid}, skipping creation`);
    return;
  }

  // Create user document with required fields for chat and default role
  await userRef.set({
    email: email?.toLowerCase().trim() || "",
    displayName: displayName || "",
    role: "resident", // Default role; elevated roles require manifest + joinHallWithCode
    hallId: "", // Empty until joinHallWithCode is called
    tenantId: DEFAULT_TENANT_ID, // Set default tenant for chat
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`User document created for ${uid} with tenantId=${DEFAULT_TENANT_ID}`);
});

// ============================================================
// ensureUserDoc (Self-heal Fallback)
// Callable by any authenticated user to ensure their /users/{uid} doc exists
// This is a safety net for users created before the auth trigger was deployed
// ============================================================

interface EnsureUserDocResponse {
  success: boolean;
  action: "created" | "updated" | "none";
  uid: string;
}

export const ensureUserDoc = functions.https.onCall(
  async (_data: unknown, context): Promise<EnsureUserDocResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const email = context.auth.token.email?.toLowerCase().trim() || "";
    const displayName = context.auth.token.name || "";

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      // Create new user document with server-controlled defaults
      await userRef.set({
        email: email,
        displayName: displayName,
        role: "resident", // Server-controlled default
        hallId: "",
        tenantId: DEFAULT_TENANT_ID, // Server-controlled default
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`ensureUserDoc: Created /users/${uid} with tenantId=${DEFAULT_TENANT_ID}`);
      return { success: true, action: "created", uid };
    }

    // Document exists - check if tenantId is missing and fix it
    const userData = userDoc.data();
    if (!userData?.tenantId) {
      await userRef.update({
        tenantId: DEFAULT_TENANT_ID,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`ensureUserDoc: Added tenantId to /users/${uid}`);
      return { success: true, action: "updated", uid };
    }

    // Document exists and has tenantId - nothing to do
    console.log(`ensureUserDoc: /users/${uid} already complete`);
    return { success: true, action: "none", uid };
  }
);

// ============================================================
// backfillUsersTenantId
// Admin callable: Backfills tenantId for existing users missing it
// Also creates /users/{uid} for Auth users without a user doc
// ============================================================

interface BackfillRequest {
  tenantId?: string;
  dryRun?: boolean;
}

interface BackfillResponse {
  success: boolean;
  usersUpdated: number;
  usersCreated: number;
  errors: string[];
  dryRun: boolean;
}

export const backfillUsersTenantId = functions.https.onCall(
  async (data: BackfillRequest, context): Promise<BackfillResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // Only allow staff manifest members to run backfill
    const callerEmail = context.auth.token.email?.toLowerCase().trim();
    if (!callerEmail) {
      throw new HttpsError("invalid-argument", "Caller email is required");
    }

    const staffManifest = await db
      .collection("role_manifests")
      .doc("staff")
      .collection("emails")
      .doc(callerEmail)
      .get();

    if (!staffManifest.exists) {
      throw new HttpsError(
        "permission-denied",
        "Only staff manifest members can run backfill"
      );
    }

    const targetTenantId = data.tenantId || DEFAULT_TENANT_ID;
    const dryRun = data.dryRun ?? false;

    console.log(
      `Starting backfill: tenantId=${targetTenantId}, dryRun=${dryRun}`
    );

    let usersUpdated = 0;
    let usersCreated = 0;
    const errors: string[] = [];

    // Part 1: Update existing /users docs missing tenantId
    try {
      const usersSnapshot = await db.collection("users").get();

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();

        if (!userData.tenantId) {
          if (!dryRun) {
            await userDoc.ref.update({
              tenantId: targetTenantId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          usersUpdated++;
          console.log(`Updated user ${userDoc.id} with tenantId=${targetTenantId}`);
        }
      }
    } catch (error) {
      const errorMsg = `Error updating users: ${error}`;
      console.error(errorMsg);
      errors.push(errorMsg);
    }

    // Part 2: Create /users docs for Auth users missing user docs
    // Note: Requires Firebase Admin SDK to list all Auth users
    // This has a limitation: listUsers() paginates and may be slow for large user bases
    try {
      let nextPageToken: string | undefined;
      do {
        const listResult = await admin.auth().listUsers(1000, nextPageToken);

        for (const authUser of listResult.users) {
          const userDocRef = db.collection("users").doc(authUser.uid);
          const userDoc = await userDocRef.get();

          if (!userDoc.exists) {
            if (!dryRun) {
              await userDocRef.set({
                email: authUser.email?.toLowerCase().trim() || "",
                displayName: authUser.displayName || "",
                role: "resident",
                hallId: "",
                tenantId: targetTenantId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
            usersCreated++;
            console.log(
              `Created user doc for Auth user ${authUser.uid} ` +
              `(${authUser.email}) with tenantId=${targetTenantId}`
            );
          }
        }

        nextPageToken = listResult.pageToken;
      } while (nextPageToken);
    } catch (error) {
      const errorMsg = `Error creating user docs from Auth: ${error}`;
      console.error(errorMsg);
      errors.push(errorMsg);
    }

    console.log(
      `Backfill complete: updated=${usersUpdated}, created=${usersCreated}, ` +
      `errors=${errors.length}, dryRun=${dryRun}`
    );

    return {
      success: errors.length === 0,
      usersUpdated,
      usersCreated,
      errors,
      dryRun,
    };
  }
);

// ============================================================
// addToRoleManifest
// Admin-only function to add emails to role manifests
// Called from Firebase Console or admin scripts
// ============================================================

export const addToRoleManifest = functions.https.onCall(
  async (data: { role: string; email: string }, context) => {
    // Only allow admin users (check custom claims or specific UIDs)
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // In production, check for admin custom claim
    // For now, check if user is in staff manifest
    const callerEmail = context.auth.token.email?.toLowerCase().trim();
    if (!callerEmail) {
      throw new HttpsError("invalid-argument", "Caller email is required");
    }

    const staffManifest = await db
      .collection("role_manifests")
      .doc("staff")
      .collection("emails")
      .doc(callerEmail)
      .get();

    if (!staffManifest.exists) {
      throw new HttpsError("permission-denied", "Only admins can modify manifests");
    }

    const { role, email } = data;

    if (!role || !["ra", "staff"].includes(role)) {
      throw new HttpsError("invalid-argument", "Invalid role");
    }

    if (!email) {
      throw new HttpsError("invalid-argument", "Email is required");
    }

    const normalizedEmail = email.toLowerCase().trim();

    await db
      .collection("role_manifests")
      .doc(role)
      .collection("emails")
      .doc(normalizedEmail)
      .set({
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
        addedBy: context.auth.uid,
      });

    console.log(`Added ${normalizedEmail} to ${role} manifest`);

    return {
      success: true,
      message: `Added ${normalizedEmail} to ${role} manifest`,
    };
  }
);

// ============================================================
// removeFromRoleManifest
// Admin-only function to remove emails from role manifests
// ============================================================

export const removeFromRoleManifest = functions.https.onCall(
  async (data: { role: string; email: string }, context) => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const callerEmail = context.auth.token.email?.toLowerCase().trim();
    if (!callerEmail) {
      throw new HttpsError("invalid-argument", "Caller email is required");
    }

    const staffManifest = await db
      .collection("role_manifests")
      .doc("staff")
      .collection("emails")
      .doc(callerEmail)
      .get();

    if (!staffManifest.exists) {
      throw new HttpsError("permission-denied", "Only admins can modify manifests");
    }

    const { role, email } = data;

    if (!role || !["ra", "staff"].includes(role)) {
      throw new HttpsError("invalid-argument", "Invalid role");
    }

    if (!email) {
      throw new HttpsError("invalid-argument", "Email is required");
    }

    const normalizedEmail = email.toLowerCase().trim();

    await db
      .collection("role_manifests")
      .doc(role)
      .collection("emails")
      .doc(normalizedEmail)
      .delete();

    console.log(`Removed ${normalizedEmail} from ${role} manifest`);

    return {
      success: true,
      message: `Removed ${normalizedEmail} from ${role} manifest`,
    };
  }
);

// ============================================================
// askAI
// Callable function to interact with Google Vertex AI (Gemini)
// ============================================================

import { VertexAI } from "@google-cloud/vertexai";

// Initialize Vertex AI
// Note: Requires "Vertex AI User" role for the service account
// and the API enabled in Google Cloud Console.

// Import knowledge base
// eslint-disable-next-line @typescript-eslint/no-var-requires
const knowledgeBase = require("./knowledge_base.json");

interface KnowledgeItem {
  topic: string;
  section: string;
  text: string;
}

// Format knowledge base into a context string
const knowledgeContext = (knowledgeBase as KnowledgeItem[])
  .map((item) => `Topic: ${item.topic}\nSection: ${item.section}\nContent: ${item.text}`)
  .join("\n\n");

const AI_CONFIG = {
  location: "us-central1",
  defaultModel: "gemini-2.5-flash",
  systemPrompt: `You are "HallPals AI", a helpful and friendly residence life assistant.
Your goal is to assist residents using the HallPals app with their daily tasks.
Keep your responses concise, safe, and helpful.

Use the following knowledge base to answer questions.
If the answer is not in the knowledge base, answer based on general knowledge but prioritize the provided context.

KNOWLEDGE BASE:
${knowledgeContext}`,
};

export const askAI = functions
  .runWith({
    serviceAccount: "vertex-express@hallpals.iam.gserviceaccount.com",
    secrets: [],
  })
  .https.onCall(
    async (data: { prompt: string; model?: string }, context) => {
      // 1. Require authentication
      if (!context.auth) {
        throw new HttpsError("unauthenticated", "User must be authenticated");
      }

      const uid = context.auth.uid;
      const { prompt, model } = data; // Removed systemPrompt from input

      if (!prompt) {
        throw new HttpsError("invalid-argument", "Prompt is required");
      }

      // 2. Configuration
      const project = process.env.GCLOUD_PROJECT;
      const location = AI_CONFIG.location;
      const selectedModel = model || AI_CONFIG.defaultModel;
      const systemPrompt = AI_CONFIG.systemPrompt;

      if (!project) {
        console.error("GCLOUD_PROJECT env var missing");
        throw new HttpsError("internal", "Project configuration error");
      }

      try {
        console.log(`User ${uid} asking AI (${selectedModel}): ${prompt.substring(0, 50)}...`);

        const vertexAi = new VertexAI({ project: project, location: location });
        const generativeModel = vertexAi.getGenerativeModel({ model: selectedModel });

        const chatSession = generativeModel.startChat({
          history: [
            {
              role: "user",
              parts: [{ text: `System Instruction: ${systemPrompt}` }],
            },
            {
              role: "model",
              parts: [{ text: "Understood. I am HallPals AI." }],
            },
          ],
        });

        const result = await chatSession.sendMessage(prompt);
        const responseText = result.response.candidates?.[0].content.parts[0].text || "";

        return {
          response: responseText,
          model: selectedModel,
        };
      } catch (error: unknown) {
        console.error("Error calling Vertex AI:", error);
        const errorMessage = error instanceof Error ? error.message : "Unknown error";
        throw new HttpsError("internal", `Vertex AI Error: ${errorMessage}`, errorMessage);
      }
    }
  );

// ============================================================
// CHAT FUNCTIONS - Phase C3.2 (Global with tenantId)
// ============================================================

// Helper: Get user's tenantId (required for chat)
async function getTenantId(uid: string): Promise<string> {
  const userDoc = await db.collection("users").doc(uid).get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found");
  }

  const tenantId = userDoc.data()?.tenantId;
  if (!tenantId) {
    throw new HttpsError(
      "failed-precondition",
      "Tenant not set. Please complete onboarding first."
    );
  }

  return tenantId;
}

// Helper: Check if user is active member of a conversation (global path)
async function isActiveMember(
  conversationId: string,
  uid: string
): Promise<boolean> {
  const memberDoc = await db
    .collection("conversations")
    .doc(conversationId)
    .collection("members")
    .doc(uid)
    .get();

  return memberDoc.exists && memberDoc.data()?.status === "active";
}

// Helper: Get conversation tenantId for defense-in-depth checks
async function getConversationTenantId(
  conversationId: string
): Promise<string | null> {
  const convDoc = await db.collection("conversations").doc(conversationId).get();
  return convDoc.exists ? convDoc.data()?.tenantId || null : null;
}

// ============================================================
// createOrGetDM
// Creates a DM conversation with deterministic ID to prevent duplicates
// Global path: /conversations/{cid} with tenantId boundary
// ============================================================

export const createOrGetDM = functions.https.onCall(
  async (data: CreateDMRequest, context): Promise<CreateDMResponse> => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { otherUid } = data;

    if (!otherUid) {
      throw new HttpsError("invalid-argument", "otherUid is required");
    }

    if (uid === otherUid) {
      throw new HttpsError("invalid-argument", "Cannot create DM with yourself");
    }

    // Get tenant IDs for both users
    const [callerTenantId, otherTenantId] = await Promise.all([
      getTenantId(uid),
      getTenantId(otherUid).catch(() => null),
    ]);

    if (!otherTenantId) {
      throw new HttpsError("not-found", "Other user not found or not onboarded");
    }

    // Verify same tenant
    if (callerTenantId !== otherTenantId) {
      throw new HttpsError(
        "permission-denied",
        "Cannot create DM with user from different organization"
      );
    }

    // Deterministic DM ID: dm_{minUid}_{maxUid}
    const [minUid, maxUid] = uid < otherUid ? [uid, otherUid] : [otherUid, uid];
    const conversationId = `dm_${minUid}_${maxUid}`;

    const convRef = db.collection("conversations").doc(conversationId);

    const now = admin.firestore.FieldValue.serverTimestamp();

    // Use transaction to ensure atomicity
    const result = await db.runTransaction(async (transaction) => {
      const convDoc = await transaction.get(convRef);

      if (convDoc.exists) {
        // Conversation exists - ensure both members are active
        const member1Ref = convRef.collection("members").doc(uid);
        const member2Ref = convRef.collection("members").doc(otherUid);

        const [member1Doc, member2Doc] = await Promise.all([
          transaction.get(member1Ref),
          transaction.get(member2Ref),
        ]);

        // Reactivate members if they left
        if (!member1Doc.exists || member1Doc.data()?.status !== "active") {
          transaction.set(member1Ref, {
            status: "active" as MemberStatus,
            role: "member" as MemberRole,
            joinedAt: member1Doc.exists ? member1Doc.data()?.joinedAt : now,
            updatedAt: now,
            lastReadAt: now,
          }, { merge: true });
        }

        if (!member2Doc.exists || member2Doc.data()?.status !== "active") {
          transaction.set(member2Ref, {
            status: "active" as MemberStatus,
            role: "member" as MemberRole,
            joinedAt: member2Doc.exists ? member2Doc.data()?.joinedAt : now,
            updatedAt: now,
            lastReadAt: now,
          }, { merge: true });
        }

        return { conversationId, created: false };
      }

      // Create new conversation with tenantId
      transaction.set(convRef, {
        type: "dm" as ConversationType,
        tenantId: callerTenantId,
        participantIds: [uid, otherUid],
        createdAt: now,
        lastMessagePreview: null,
        lastMessageAt: null,
      });

      // Create member docs for both users
      const epochTime = admin.firestore.Timestamp.fromMillis(0);

      transaction.set(convRef.collection("members").doc(uid), {
        status: "active" as MemberStatus,
        role: "member" as MemberRole,
        joinedAt: now,
        updatedAt: now,
        lastReadAt: epochTime,
      });

      transaction.set(convRef.collection("members").doc(otherUid), {
        status: "active" as MemberStatus,
        role: "member" as MemberRole,
        joinedAt: now,
        updatedAt: now,
        lastReadAt: epochTime,
      });

      return { conversationId, created: true };
    });

    console.log(
      `DM ${conversationId} ${result.created ? "created" : "retrieved"} ` +
      `for tenant ${callerTenantId}`
    );

    return result;
  }
);

// ============================================================
// createGroupConversation
// Creates a group conversation with specified members
// Global path: /conversations/{cid} with tenantId boundary
// ============================================================

export const createGroupConversation = functions.https.onCall(
  async (data: CreateGroupRequest, context): Promise<CreateGroupResponse> => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { title, memberUids } = data;

    if (!title) {
      throw new HttpsError("invalid-argument", "title is required");
    }

    if (!memberUids || !Array.isArray(memberUids)) {
      throw new HttpsError("invalid-argument", "memberUids must be an array");
    }

    // Ensure creator is included and deduplicate
    const allMemberUids = [...new Set([uid, ...memberUids])];

    if (allMemberUids.length < 2) {
      throw new HttpsError("invalid-argument", "Group must have at least 2 members");
    }

    if (allMemberUids.length > 50) {
      throw new HttpsError("invalid-argument", "Group cannot have more than 50 members");
    }

    // Get caller's tenantId
    const callerTenantId = await getTenantId(uid);

    // Verify all members have same tenantId
    const memberTenantIds = await Promise.all(
      allMemberUids.map(async (memberUid) => {
        try {
          return await getTenantId(memberUid);
        } catch {
          return null;
        }
      })
    );

    const invalidMembers = allMemberUids.filter(
      (_, i) => memberTenantIds[i] !== callerTenantId
    );

    if (invalidMembers.length > 0) {
      throw new HttpsError(
        "permission-denied",
        `Some users are not in your organization: ${invalidMembers.join(", ")}`
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const epochTime = admin.firestore.Timestamp.fromMillis(0);

    // Generate unique conversation ID (global path)
    const convRef = db.collection("conversations").doc();
    const conversationId = convRef.id;

    // Use batch write for efficiency
    const batch = db.batch();

    // Create conversation doc with tenantId
    batch.set(convRef, {
      type: "group" as ConversationType,
      tenantId: callerTenantId,
      title: title.trim(),
      participantIds: allMemberUids,
      createdAt: now,
      lastMessagePreview: null,
      lastMessageAt: null,
    });

    // Create member docs
    for (const memberUid of allMemberUids) {
      const memberRef = convRef.collection("members").doc(memberUid);
      batch.set(memberRef, {
        status: "active" as MemberStatus,
        role: (memberUid === uid ? "admin" : "member") as MemberRole,
        joinedAt: now,
        updatedAt: now,
        lastReadAt: epochTime,
      });
    }

    await batch.commit();

    console.log(
      `Group "${title}" created with ${allMemberUids.length} members ` +
      `for tenant ${callerTenantId}`
    );

    return { conversationId };
  }
);

// ============================================================
// sendMessage
// Sends a message to a conversation (idempotent by messageId)
// Global path: /conversations/{cid}/messages/{mid}
// ============================================================

export const sendMessage = functions.https.onCall(
  async (data: SendMessageRequest, context): Promise<SendMessageResponse> => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { conversationId, messageId, text, imageUrl } = data;

    if (!conversationId || !messageId) {
      throw new HttpsError("invalid-argument", "conversationId and messageId are required");
    }

    // Validate message content
    const hasText = text && text.trim().length > 0;
    const hasImage = imageUrl && imageUrl.trim().length > 0;

    if (!hasText && !hasImage) {
      throw new HttpsError("invalid-argument", "Message must have text or imageUrl");
    }

    // Verify caller is active member
    const isMember = await isActiveMember(conversationId, uid);
    if (!isMember) {
      throw new HttpsError("permission-denied", "You are not an active member of this conversation");
    }

    // Defense-in-depth: verify conversation tenantId matches caller
    const [callerTenantId, convTenantId] = await Promise.all([
      getTenantId(uid),
      getConversationTenantId(conversationId),
    ]);

    if (convTenantId && callerTenantId !== convTenantId) {
      throw new HttpsError("permission-denied", "Tenant mismatch");
    }

    const messageRef = db
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .doc(messageId);

    // Check for idempotency - if message exists, return existing
    const existingMessage = await messageRef.get();
    if (existingMessage.exists) {
      const msgData = existingMessage.data();
      console.log(`Message ${messageId} already exists (idempotent return)`);
      return {
        messageId,
        createdAt: msgData?.createdAt,
      };
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const nowTimestamp = admin.firestore.Timestamp.now();

    // Create the message and update sender's lastReadAt in a batch
    // This ensures the sender doesn't see their own message as "unread"
    const batch = db.batch();

    // Create the message
    batch.set(messageRef, {
      senderId: uid,
      text: hasText ? text!.trim() : null,
      imageUrl: hasImage ? imageUrl!.trim() : null,
      createdAt: now,
      clientCreatedAt: null,
      editedAt: null,
      deletedAt: null,
    });

    // Update sender's lastReadAt to current time
    // This prevents the sender from seeing their own message as unread
    const senderMemberRef = db
      .collection("conversations")
      .doc(conversationId)
      .collection("members")
      .doc(uid);

    batch.update(senderMemberRef, {
      lastReadAt: nowTimestamp,
      updatedAt: now,
    });

    await batch.commit();

    console.log(`Message ${messageId} sent in conversation ${conversationId}`);

    // Note: conversation lastMessageAt/Preview is updated by onMessageCreate trigger

    return {
      messageId,
      createdAt: nowTimestamp,
    };
  }
);

// ============================================================
// updateLastRead
// Updates the lastReadAt timestamp (monotonic - can only move forward)
// Global path: /conversations/{cid}/members/{uid}
// ============================================================

export const updateLastRead = functions.https.onCall(
  async (data: UpdateLastReadRequest, context): Promise<{ success: boolean }> => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { conversationId, lastReadAt } = data;

    if (!conversationId || !lastReadAt) {
      throw new HttpsError("invalid-argument", "conversationId and lastReadAt are required");
    }

    const memberRef = db
      .collection("conversations")
      .doc(conversationId)
      .collection("members")
      .doc(uid);

    // Use transaction to enforce monotonic update
    await db.runTransaction(async (transaction) => {
      const memberDoc = await transaction.get(memberRef);

      if (!memberDoc.exists) {
        throw new HttpsError("not-found", "You are not a member of this conversation");
      }

      const memberData = memberDoc.data();
      if (memberData?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this conversation");
      }

      const currentLastReadAt = memberData?.lastReadAt as admin.firestore.Timestamp;

      // Convert lastReadAt to Timestamp if needed
      let newLastReadAt: admin.firestore.Timestamp;
      if (lastReadAt instanceof admin.firestore.Timestamp) {
        newLastReadAt = lastReadAt;
      } else if (typeof lastReadAt === "object" && "_seconds" in lastReadAt) {
        // Handle serialized timestamp from client
        newLastReadAt = new admin.firestore.Timestamp(
          (lastReadAt as { _seconds: number })._seconds,
          (lastReadAt as { _nanoseconds: number })._nanoseconds || 0
        );
      } else {
        throw new HttpsError("invalid-argument", "Invalid lastReadAt format");
      }

      // Monotonic check: only update if new timestamp is greater
      if (currentLastReadAt && newLastReadAt.toMillis() <= currentLastReadAt.toMillis()) {
        console.log(
          `lastReadAt not updated (monotonic): new=${newLastReadAt.toMillis()}, ` +
          `current=${currentLastReadAt.toMillis()}`
        );
        return;
      }

      transaction.update(memberRef, {
        lastReadAt: newLastReadAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { success: true };
  }
);

// ============================================================
// onMessageCreate (Firestore Trigger)
// Updates conversation lastMessageAt and lastMessagePreview
// Sends push notifications to other participants
// Global path: /conversations/{cid}/messages/{mid}
// ============================================================

export const onMessageCreate = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const { conversationId } = context.params;
    const messageData = snapshot.data();

    if (!messageData) {
      console.error("No message data found");
      return;
    }

    // Build preview
    let preview: string;
    if (messageData.deletedAt) {
      preview = "[deleted]";
    } else if (messageData.text) {
      preview = messageData.text.length > 100 ?
        messageData.text.substring(0, 100) + "..." :
        messageData.text;
    } else if (messageData.imageUrl) {
      preview = "[image]";
    } else {
      preview = "";
    }

    // Update conversation
    const convRef = db.collection("conversations").doc(conversationId);

    await convRef.update({
      lastMessageAt: messageData.createdAt,
      lastMessagePreview: preview,
    });

    console.log(`Conversation ${conversationId} updated with new message preview`);

    // Send push notifications to other participants
    try {
      const convDoc = await convRef.get();
      const convData = convDoc.data();

      if (!convData) {
        console.log("No conversation data for push notifications");
        return;
      }

      const senderId = messageData.senderId;
      const participantIds: string[] = convData.participantIds || [];

      // Get sender's display name for notification
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName = senderDoc.data()?.displayName || "Someone";

      // Build notification title based on conversation type
      let notificationTitle: string;
      if (convData.type === "group" && convData.title) {
        notificationTitle = `${senderName} in ${convData.title}`;
      } else {
        notificationTitle = senderName;
      }

      // Get FCM tokens for all participants except sender
      const recipientIds = participantIds.filter((id: string) => id !== senderId);

      if (recipientIds.length === 0) {
        console.log("No recipients for push notification");
        return;
      }

      // Fetch FCM tokens for all recipients
      const tokenPromises = recipientIds.map(async (uid: string) => {
        const userDoc = await db.collection("users").doc(uid).get();
        const userData = userDoc.data();
        return userData?.fcmToken as string | undefined;
      });

      const tokens = (await Promise.all(tokenPromises)).filter(
        (token): token is string => !!token
      );

      if (tokens.length === 0) {
        console.log("No FCM tokens found for recipients");
        return;
      }

      // Build the message payload
      const payload: admin.messaging.MulticastMessage = {
        tokens: tokens,
        notification: {
          title: notificationTitle,
          body: preview || "New message",
        },
        data: {
          conversationId: conversationId,
          messageId: context.params.messageId,
          senderId: senderId,
          type: "chat_message",
        },
        apns: {
          payload: {
            aps: {
              "sound": "default",
              "badge": 1,
              "mutable-content": 1,
            },
          },
        },
        android: {
          notification: {
            sound: "default",
            channelId: "chat_messages",
          },
        },
      };

      // Send the notifications
      const response = await admin.messaging().sendEachForMulticast(payload);

      console.log(
        `Push notifications sent: ${response.successCount} success, ` +
        `${response.failureCount} failed`
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];

        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            // Remove invalid/unregistered tokens
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });

        // Remove invalid tokens from user documents
        if (invalidTokens.length > 0) {
          console.log(`Cleaning up ${invalidTokens.length} invalid tokens`);

          const cleanupPromises = recipientIds.map(async (uid: string, idx: number) => {
            if (invalidTokens.includes(tokens[idx])) {
              await db.collection("users").doc(uid).update({
                fcmToken: admin.firestore.FieldValue.delete(),
              });
            }
          });

          await Promise.all(cleanupPromises);
        }
      }
    } catch (error) {
      console.error("Error sending push notifications:", error);
      // Don't throw - push notification failure shouldn't fail the message creation
    }
  });

// ============================================================
// submitNoiseReport
// Callable by any hall member to submit a noise report
// Creates a noise_report document and notifies on-duty RA
// ============================================================

interface NoiseReportRequest {
  hallId: string;
  location: string;
  description?: string;
  urgency: "low" | "medium" | "high";
}

interface NoiseReportResponse {
  success: boolean;
  reportId: string;
  message: string;
}

export const submitNoiseReport = functions.https.onCall(
  async (data: NoiseReportRequest, context): Promise<NoiseReportResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { hallId, location, description, urgency } = data;

    // Validate required fields
    if (!hallId) {
      throw new HttpsError("invalid-argument", "hallId is required");
    }

    if (!location || location.trim().length === 0) {
      throw new HttpsError("invalid-argument", "location is required");
    }

    if (!urgency || !["low", "medium", "high"].includes(urgency)) {
      throw new HttpsError("invalid-argument", "urgency must be low, medium, or high");
    }

    // Verify user is a member of the hall
    const memberDoc = await db
      .collection("halls")
      .doc(hallId)
      .collection("members")
      .doc(uid)
      .get();

    if (!memberDoc.exists || !memberDoc.data()?.isActive) {
      throw new HttpsError("permission-denied", "You are not a member of this hall");
    }

    // Get reporter's display name
    const userDoc = await db.collection("users").doc(uid).get();
    const reporterName = userDoc.data()?.displayName || "Anonymous";

    // Create the noise report
    const now = admin.firestore.FieldValue.serverTimestamp();
    const reportRef = db
      .collection("halls")
      .doc(hallId)
      .collection("noise_reports")
      .doc();

    await reportRef.set({
      location: location.trim(),
      description: description?.trim() || null,
      urgency: urgency,
      reportedBy: uid,
      reporterName: reporterName,
      status: "pending",
      createdAt: now,
      resolvedAt: null,
      resolvedBy: null,
    });

    console.log(`Noise report ${reportRef.id} created by ${uid} in hall ${hallId}`);

    // Find on-duty RA to notify
    try {
      const nowDate = new Date();
      const dutyShiftsSnapshot = await db
        .collection("halls")
        .doc(hallId)
        .collection("duty_shifts")
        .where("start", "<=", admin.firestore.Timestamp.fromDate(nowDate))
        .where("end", ">", admin.firestore.Timestamp.fromDate(nowDate))
        .limit(1)
        .get();

      if (!dutyShiftsSnapshot.empty) {
        const dutyShift = dutyShiftsSnapshot.docs[0].data();
        const onDutyRaUid = dutyShift.odRAuid || dutyShift.userId;

        if (onDutyRaUid) {
          // Get RA's FCM token
          const raDoc = await db.collection("users").doc(onDutyRaUid).get();
          const fcmToken = raDoc.data()?.fcmToken;

          if (fcmToken) {
            // Send push notification to on-duty RA
            const urgencyLabel = urgency.charAt(0).toUpperCase() + urgency.slice(1);
            const payload: admin.messaging.Message = {
              token: fcmToken,
              notification: {
                title: `${urgencyLabel} Priority Noise Report`,
                body: `${reporterName} reported noise at ${location.trim()}`,
              },
              data: {
                type: "noise_report",
                reportId: reportRef.id,
                hallId: hallId,
                urgency: urgency,
              },
              apns: {
                payload: {
                  aps: {
                    sound: urgency === "high" ? "critical" : "default",
                    badge: 1,
                  },
                },
              },
              android: {
                notification: {
                  sound: "default",
                  channelId: "noise_reports",
                  priority: urgency === "high" ? "high" : "default",
                },
              },
            };

            await admin.messaging().send(payload);
            console.log(`Push notification sent to on-duty RA ${onDutyRaUid}`);
          }
        }
      } else {
        console.log("No on-duty RA found for notification");
      }
    } catch (error) {
      // Don't fail the report if notification fails
      console.error("Error sending notification to on-duty RA:", error);
    }

    return {
      success: true,
      reportId: reportRef.id,
      message: "Noise report submitted successfully",
    };
  }
);

// ============================================================
// seedKnowledgeBaseDocs
// Admin-only function to seed /docs collection with knowledge base entries
// ============================================================

// Knowledge base data - embedded for seeding
// Topic slugs matching KBTopic.slug in iOS
const KB_TOPIC_SLUGS: Record<string, string> = {
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
  "Training": "training",
};

const KB_TOPIC_INFO: Record<string, { title: string; category: string }> = {
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
  "training": { title: "Training", category: "training" },
};

interface KBEntry {
  canonical_id: string;
  topic: string;
  section: string;
  text: string;
  sources: Array<{
    source_doc_id: string;
    path: string;
    location: string;
  }>;
}

interface SeedDocsRequest {
  entries: KBEntry[];
  dryRun?: boolean;
}

interface SeedDocsResponse {
  success: boolean;
  docsCreated: number;
  entriesCreated: number;
  errors: string[];
  dryRun: boolean;
}

// ============================================================
// submitMaintenanceRequest
// Callable by any hall member to submit a maintenance request
// Creates a maintenance_request document
// ============================================================

interface MaintenanceRequestInput {
  hallId: string;
  category: "plumbing" | "electrical" | "hvac" | "furniture" | "appliance" | "pest" | "locksmith" | "other";
  title: string;
  description: string;
  location: string;
  urgency: "low" | "medium" | "high" | "emergency";
  allowEntry: boolean;
}

interface MaintenanceRequestResponse {
  success: boolean;
  requestId: string;
  message: string;
}

export const submitMaintenanceRequest = functions.https.onCall(
  async (data: MaintenanceRequestInput, context): Promise<MaintenanceRequestResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { hallId, category, title, description, location, urgency, allowEntry } = data;

    // Validate required fields
    if (!hallId) {
      throw new HttpsError("invalid-argument", "hallId is required");
    }

    const validCategories = ["plumbing", "electrical", "hvac", "furniture", "appliance", "pest", "locksmith", "other"];
    if (!category || !validCategories.includes(category)) {
      throw new HttpsError("invalid-argument", "Invalid category");
    }

    if (!title || title.trim().length === 0) {
      throw new HttpsError("invalid-argument", "title is required");
    }

    if (!location || location.trim().length === 0) {
      throw new HttpsError("invalid-argument", "location is required");
    }

    const validUrgencies = ["low", "medium", "high", "emergency"];
    if (!urgency || !validUrgencies.includes(urgency)) {
      throw new HttpsError("invalid-argument", "Invalid urgency");
    }

    // Verify user is a member of the hall
    const memberDoc = await db
      .collection("halls")
      .doc(hallId)
      .collection("members")
      .doc(uid)
      .get();

    if (!memberDoc.exists || !memberDoc.data()?.isActive) {
      throw new HttpsError("permission-denied", "You are not a member of this hall");
    }

    // Get requester's info
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    const requesterName = userData?.displayName || "Anonymous";
    const requesterRoom = userData?.roomNumber || null;

    // Create the maintenance request
    const now = admin.firestore.FieldValue.serverTimestamp();
    const requestRef = db
      .collection("halls")
      .doc(hallId)
      .collection("maintenance_requests")
      .doc();

    await requestRef.set({
      category: category,
      title: title.trim(),
      description: description?.trim() || null,
      location: location.trim(),
      urgency: urgency,
      allowEntry: allowEntry ?? false,
      requestedBy: uid,
      requesterName: requesterName,
      requesterRoom: requesterRoom,
      status: "pending",
      createdAt: now,
      updatedAt: now,
      assignedTo: null,
      resolvedAt: null,
      notes: null,
    });

    console.log(`Maintenance request ${requestRef.id} created by ${uid} in hall ${hallId}`);

    // Notify staff if emergency
    if (urgency === "emergency") {
      try {
        // Find staff members in the hall
        const staffSnapshot = await db
          .collection("halls")
          .doc(hallId)
          .collection("members")
          .where("role", "in", ["staff", "ra"])
          .where("isActive", "==", true)
          .get();

        const staffUids = staffSnapshot.docs.map((doc) => doc.id);

        // Get FCM tokens for staff
        const tokenPromises = staffUids.map(async (staffUid) => {
          const staffDoc = await db.collection("users").doc(staffUid).get();
          return staffDoc.data()?.fcmToken as string | undefined;
        });

        const tokens = (await Promise.all(tokenPromises)).filter(
          (token): token is string => !!token
        );

        if (tokens.length > 0) {
          const payload: admin.messaging.MulticastMessage = {
            tokens: tokens,
            notification: {
              title: "Emergency Maintenance Request",
              body: `${requesterName}: ${title.trim()} at ${location.trim()}`,
            },
            data: {
              type: "maintenance_emergency",
              requestId: requestRef.id,
              hallId: hallId,
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
            android: {
              notification: {
                sound: "default",
                channelId: "maintenance_emergency",
                priority: "high",
              },
            },
          };

          await admin.messaging().sendEachForMulticast(payload);
          console.log(`Emergency notification sent to ${tokens.length} staff members`);
        }
      } catch (error) {
        console.error("Error sending emergency notification:", error);
      }
    }

    return {
      success: true,
      requestId: requestRef.id,
      message: "Maintenance request submitted successfully",
    };
  }
);

// ============================================================
// seedKnowledgeBaseDocs
// Admin-only function to seed /docs collection with knowledge base entries
// ============================================================

export const seedKnowledgeBaseDocs = functions.https.onCall(
  async (data: SeedDocsRequest, context): Promise<SeedDocsResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const callerEmail = context.auth.token.email?.toLowerCase().trim();
    if (!callerEmail) {
      throw new HttpsError("invalid-argument", "Caller email is required");
    }

    // Check if user is staff via manifest OR via their user doc role
    let isStaff = false;

    // Check staff manifest first
    const staffManifest = await db
      .collection("role_manifests")
      .doc("staff")
      .collection("emails")
      .doc(callerEmail)
      .get();

    if (staffManifest.exists) {
      isStaff = true;
    } else {
      // Check user doc for staff role (dev staff who used DEVLEAD code)
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists && userDoc.data()?.role === "staff") {
        isStaff = true;
      }
    }

    if (!isStaff) {
      throw new HttpsError(
        "permission-denied",
        "Only staff members can seed docs"
      );
    }

    const entries = data.entries || [];
    const dryRun = data.dryRun ?? false;

    if (entries.length === 0) {
      throw new HttpsError("invalid-argument", "No entries provided");
    }

    console.log(`Starting seed: ${entries.length} entries, dryRun=${dryRun}`);

    let docsCreated = 0;
    let entriesCreated = 0;
    const errors: string[] = [];
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Group entries by topic
    const entriesByTopic: Record<string, KBEntry[]> = {};
    for (const entry of entries) {
      const topic = entry.topic;
      if (!entriesByTopic[topic]) {
        entriesByTopic[topic] = [];
      }
      entriesByTopic[topic].push(entry);
    }

    // Create doc for each topic
    for (const [topicName, topicEntries] of Object.entries(entriesByTopic)) {
      const slug = KB_TOPIC_SLUGS[topicName];

      if (!slug) {
        errors.push(`Unknown topic: ${topicName}`);
        continue;
      }

      const info = KB_TOPIC_INFO[slug];

      try {
        if (!dryRun) {
          // Create the doc metadata
          const docRef = db.collection("docs").doc(slug);
          await docRef.set({
            title: info.title,
            slug: slug,
            category: info.category,
            isPublished: true,
            createdAt: now,
            updatedAt: now,
            entryCount: topicEntries.length,
          });
          docsCreated++;

          // Create entries subcollection
          const entriesRef = docRef.collection("entries");

          let order = 0;
          for (const entry of topicEntries) {
            order++;
            const entryId = entry.canonical_id || `entry_${order}`;

            await entriesRef.doc(entryId).set({
              order: order,
              topic: topicName,
              section: entry.section || "General",
              text: entry.text,
              sources: entry.sources || [],
              createdAt: now,
              updatedAt: now,
            });
            entriesCreated++;
          }
        } else {
          docsCreated++;
          entriesCreated += topicEntries.length;
        }

        console.log(`Created /docs/${slug} with ${topicEntries.length} entries`);
      } catch (error) {
        errors.push(`Error creating ${slug}: ${error}`);
      }
    }

    // Ensure all 12 topics exist (even if empty)
    for (const [slug, info] of Object.entries(KB_TOPIC_INFO)) {
      try {
        const docRef = db.collection("docs").doc(slug);
        const doc = await docRef.get();

        if (!doc.exists && !dryRun) {
          await docRef.set({
            title: info.title,
            slug: slug,
            category: info.category,
            isPublished: true,
            createdAt: now,
            updatedAt: now,
            entryCount: 0,
          });
          docsCreated++;
          console.log(`Created empty /docs/${slug}`);
        }
      } catch (error) {
        errors.push(`Error creating empty ${slug}: ${error}`);
      }
    }

    console.log(
      `Seed complete: docs=${docsCreated}, entries=${entriesCreated}, ` +
      `errors=${errors.length}, dryRun=${dryRun}`
    );

    return {
      success: errors.length === 0,
      docsCreated,
      entriesCreated,
      errors,
      dryRun,
    };
  }
);
