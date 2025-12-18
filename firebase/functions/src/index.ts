/**
 * HallPals Cloud Functions
 * V1 Release: Push, Roster, Chat, Privacy
 *
 * Key V1 Contracts:
 * - Single FCM token per user at /users/{uid}.fcmToken
 * - Roster import preserves claims, last row wins
 * - No hall switching once assigned
 * - /users self-read only (privacy)
 * - email_index for RA lookup
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
  hallId?: string; // Optional - if not provided, discover from roster or admin assigns later
  code?: string; // Optional - special access code for staff promotion (e.g., "DEVLEAD")
}

// Staff promotion access code
const STAFF_ACCESS_CODE = "DEVLEAD";

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
    hallDirector?: {
      uid?: string;
      name: string;
      email?: string;
      phone?: string;
    };
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
// ROLE CODES REMOVED - Roles now determined by roster lookup
// During signup:
// 1. Search roster for user's email
// 2. If found: use role from roster (ra or resident)
// 3. If not found: default to resident
// ============================================================

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
// V2: Role determined by roster lookup, no access codes required
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

    // 2. Determine hall ID - priority order:
    //    a) Explicitly provided hallId
    //    b) Existing user's hallId (if they already have one)
    //    c) Discover from roster collection group query (email -> hallId)
    let hallId = data.hallId || null;

    // 3. V1 CRITICAL: No hall switching - check if user already has a different hall
    const userRef = db.collection("users").doc(uid);
    const existingUserDoc = await userRef.get();
    const existingHallId = existingUserDoc.data()?.hallId;

    console.log(`joinHallWithCode: uid=${uid}, email=${email}`);
    console.log(`joinHallWithCode: userDoc.exists=${existingUserDoc.exists}`);
    console.log(`joinHallWithCode: existingHallId=${JSON.stringify(existingHallId)}`);
    console.log(`joinHallWithCode: providedHallId=${JSON.stringify(hallId)}`);

    // Only check for hall switching if a new hallId is being assigned
    if (hallId && existingHallId && existingHallId !== "" && existingHallId !== hallId) {
      console.log(`User ${uid} tried to switch from hall ${existingHallId} to ${hallId} - blocked`);
      throw new HttpsError(
        "failed-precondition",
        "Hall switching disabled in V1. Contact staff to change your hall assignment."
      );
    }

    // 4. Check for staff access code (DEVLEAD)
    const accessCode = data.code?.toUpperCase().trim();
    const isStaffPromotion = accessCode === STAFF_ACCESS_CODE;

    if (isStaffPromotion) {
      console.log(`Staff promotion: ${email} used access code ${accessCode}`);
    }

    // 5. Role determination via roster lookup or staff code
    //    Priority: staff code > roster role > default resident
    let finalRole: UserRole = isStaffPromotion ? "staff" : "resident";
    let rosterDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    // 6. Search roster for user's email to discover both hallId AND role
    //    Note: Staff role from access code takes priority over roster role
    const shouldSearchRoster = !hallId && !existingHallId;
    console.log(`joinHallWithCode: shouldSearchRoster=${shouldSearchRoster}`);
    console.log(`joinHallWithCode: !hallId=${!hallId}, !existingHallId=${!existingHallId}`);

    if (shouldSearchRoster) {
      console.log(`No hallId for ${email} - searching roster for hallId and role...`);

      try {
        const rosterQuery = await db.collectionGroup("roster")
          .where("email", "==", email)
          .limit(1)
          .get();

        if (!rosterQuery.empty) {
          rosterDoc = rosterQuery.docs[0];
          const rosterData = rosterDoc.data();

          // Extract hallId from path: halls/{hallId}/roster/{email}
          const discoveredHallId = rosterDoc.ref.parent.parent?.id;

          if (discoveredHallId) {
            hallId = discoveredHallId;
            console.log(`Roster discovery: Found ${email} in hall ${hallId}`);
          }

          // Get role from roster document (only if not staff via access code)
          if (!isStaffPromotion) {
            const rosterRole = rosterData?.role?.toLowerCase();
            if (rosterRole === "ra") {
              finalRole = "ra";
              console.log(`Roster discovery: ${email} has RA role`);
            } else {
              finalRole = "resident";
              console.log(`Roster discovery: ${email} has resident role`);
            }
          } else {
            console.log(`Roster discovery: ${email} keeping staff role from access code`);
          }
        } else {
          console.log(`Roster discovery: ${email} not found - keeping current role: ${finalRole}`);
        }
      } catch (rosterError) {
        console.error("Roster discovery error:", rosterError);
        // Continue with default resident role
      }
    } else if (hallId || existingHallId) {
      // User already has a hall - check their roster entry for role
      const targetHallId = hallId || existingHallId;
      console.log(`Checking roster in hall ${targetHallId} for ${email}...`);

      try {
        const rosterRef = db.collection("halls").doc(targetHallId).collection("roster").doc(email);
        const rosterDocSnap = await rosterRef.get();

        if (rosterDocSnap.exists) {
          // Get role from roster document (only if not staff via access code)
          if (!isStaffPromotion) {
            const rosterData = rosterDocSnap.data();
            const rosterRole = rosterData?.role?.toLowerCase();

            if (rosterRole === "ra") {
              finalRole = "ra";
              console.log(`Roster lookup: ${email} is RA in hall ${targetHallId}`);
            } else {
              finalRole = "resident";
              console.log(`Roster lookup: ${email} is resident in hall ${targetHallId}`);
            }
          } else {
            console.log(`Roster lookup: ${email} keeping staff role from access code`);
          }
        } else {
          console.log(`Roster lookup: ${email} not in hall ${targetHallId} roster - keeping role: ${finalRole}`);
        }
      } catch (lookupError) {
        console.error("Roster lookup error:", lookupError);
      }
    }

    // 6. Verify hall exists if hallId is provided/discovered
    if (hallId) {
      const hallRef = db.collection("halls").doc(hallId);
      const hallDoc = await hallRef.get();

      if (!hallDoc.exists) {
        console.log(`Hall ${hallId} does not exist - clearing hallId`);
        hallId = null;
      }
    }

    // 8. Create/update user document (with tenantId for global chat)
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Determine final hallId: use provided hallId, or keep existing, or empty string for unassigned
    const finalHallId = hallId || existingHallId || "";

    if (existingUserDoc.exists) {
      // Update existing user - also ensure tenantId is set
      // Only update hallId if a new one is provided or user doesn't have one
      const updateData: Record<string, unknown> = {
        role: finalRole,
        tenantId: DEFAULT_TENANT_ID,
        updatedAt: now,
      };
      // Sync displayName from Auth profile (may have been set after user doc was created)
      const authDisplayName = context.auth.token.name;
      if (authDisplayName) {
        updateData.displayName = authDisplayName;
      }
      // Only set hallId if we have one to set (don't overwrite existing with empty)
      if (hallId) {
        updateData.hallId = hallId;
      } else if (!existingHallId) {
        updateData.hallId = ""; // New user with no hall assignment
      }
      await userRef.update(updateData);
    } else {
      // Create new user with tenantId
      await userRef.set({
        email: email,
        displayName: context.auth.token.name || "",
        role: finalRole,
        hallId: finalHallId,
        tenantId: DEFAULT_TENANT_ID,
        createdAt: now,
        updatedAt: now,
      });
    }

    // 9. V1: Update email_index for reverse lookup (email -> uid)
    // This enables resident "My RA" feature
    await db.collection("email_index").doc(email).set({
      uid: uid,
      updatedAt: now,
    });
    console.log(`email_index updated: ${email} -> ${uid}`);

    // 10. Create hall membership (only if user has a hall assigned)
    if (finalHallId) {
      const memberRef = db
        .collection("halls")
        .doc(finalHallId)
        .collection("members")
        .doc(uid);

      const memberDoc = await memberRef.get();

      // ROSTER CLAIM LOGIC: Check if this user is in the pending roster
      // We treat the roster as the source of truth for assignments
      const rosterRef = db.collection("halls").doc(finalHallId).collection("roster").doc(email);
      const rosterDoc = await rosterRef.get();

      let roomNumber = "";
      let floor: number | null = null;
      let wing: string | null = null;
      let assignedRaEmail: string | null = null;
      let assignedRaUid: string | null = null;

      // Get display name from roster or auth token
      let rosterDisplayName = "";

      if (rosterDoc.exists) {
        const rosterData = rosterDoc.data();

        // Always try to get display name from roster
        if (rosterData?.firstName && rosterData?.lastName) {
          rosterDisplayName = `${rosterData.firstName} ${rosterData.lastName}`.trim();
        } else if (rosterData?.name) {
          rosterDisplayName = rosterData.name;
        } else if (rosterData?.displayName) {
          rosterDisplayName = rosterData.displayName;
        }

        // Only claim roster if not already claimed
        if (!rosterData?.isClaimed) {
          roomNumber = rosterData?.roomNumber || "";
          floor = rosterData?.floor ? parseInt(rosterData.floor, 10) : null;
          wing = rosterData?.wing || null;
          assignedRaEmail = rosterData?.assignedRaEmail?.toLowerCase().trim() || null;

          // Mark roster as claimed
          await rosterRef.update({
            isClaimed: true,
            claimedByUid: uid,
            claimedAt: now,
          });

          // V1: Resolve assigned RA email to UID via email_index
          if (assignedRaEmail) {
            const raIndexDoc = await db.collection("email_index").doc(assignedRaEmail).get();
            if (raIndexDoc.exists) {
              const raUid = raIndexDoc.data()?.uid;
              // Validate that this RA is actually in the hall with role "ra"
              if (raUid) {
                const raMemberDoc = await db
                  .collection("halls")
                  .doc(finalHallId)
                  .collection("members")
                  .doc(raUid)
                  .get();

                if (raMemberDoc.exists &&
                  raMemberDoc.data()?.role === "ra" &&
                  raMemberDoc.data()?.isActive !== false) {
                  assignedRaUid = raUid;
                  console.log(`Resolved assignedRaEmail ${assignedRaEmail} to UID ${raUid}`);
                } else {
                  console.log(`assignedRaEmail ${assignedRaEmail} resolved to ${raUid} but not an active RA in hall`);
                }
              }
            } else {
              console.log(`assignedRaEmail ${assignedRaEmail} not found in email_index`);
            }
          }
        }
      }

      // Determine final display name: roster name > auth token name > empty
      const finalDisplayName = rosterDisplayName || context.auth.token.name || "";

      // Update user document with roster display name if available
      // This ensures /users/{uid}.displayName shows the proper name from roster
      if (finalDisplayName) {
        await userRef.update({
          displayName: finalDisplayName,
          updatedAt: now,
        });
        console.log(`Updated /users/${uid} displayName to: ${finalDisplayName}`);
      }

      // Build member data
      const memberData: Record<string, unknown> = {
        role: finalRole,
        isActive: true,
        userId: uid,
        updatedAt: now,
      };

      // Add display name if available
      if (finalDisplayName) memberData.displayName = finalDisplayName;

      // Add roster data if available
      if (roomNumber) memberData.roomNumber = roomNumber;
      if (floor !== null) memberData.floor = floor;
      if (wing) memberData.wing = wing;
      if (assignedRaEmail) memberData.assignedRaEmail = assignedRaEmail;
      if (assignedRaUid) memberData.assignedRaUid = assignedRaUid;

      if (!memberDoc.exists) {
        memberData.joinedAt = now;
        await memberRef.set(memberData);
      } else {
        // Update existing membership
        await memberRef.update(memberData);
      }

      // 11. Create/update public profile (privacy: no email, limited fields)
      // Use the same finalDisplayName computed earlier
      const profileRef = db
        .collection("halls")
        .doc(finalHallId)
        .collection("profiles")
        .doc(uid);

      await profileRef.set({
        displayName: finalDisplayName,
        role: finalRole,
        updatedAt: now,
      }, { merge: true });

      // 12. V1: Backfill assignedRaUid for residents when RA signs up
      // If this user is an RA, find all residents who have this RA's email as assignedRaEmail
      // and update their assignedRaUid
      if (finalRole === "ra") {
        try {
          console.log(`RA ${uid} (${email}) joined hall ${finalHallId} - checking for residents to backfill`);

          // Query members where assignedRaEmail == this RA's email
          const residentsToBackfill = await db
            .collection("halls")
            .doc(finalHallId)
            .collection("members")
            .where("assignedRaEmail", "==", email)
            .where("role", "==", "resident")
            .get();

          if (!residentsToBackfill.empty) {
            console.log(`Found ${residentsToBackfill.size} residents to backfill with assignedRaUid`);

            // Batch update all matching residents
            let batchCount = 0;
            let batch = db.batch();
            let totalUpdated = 0;

            for (const residentDoc of residentsToBackfill.docs) {
              // Only update if assignedRaUid is not already set
              const currentRaUid = residentDoc.data().assignedRaUid;
              if (!currentRaUid) {
                batch.update(residentDoc.ref, {
                  assignedRaUid: uid,
                  updatedAt: now,
                });
                batchCount++;
                totalUpdated++;

                // Commit every 450 writes (Firestore batch limit is 500)
                if (batchCount >= 450) {
                  await batch.commit();
                  batch = db.batch();
                  batchCount = 0;
                }
              }
            }

            // Commit remaining updates
            if (batchCount > 0) {
              await batch.commit();
            }

            console.log(`Backfilled assignedRaUid for ${totalUpdated} residents`);
          } else {
            console.log(`No residents found with assignedRaEmail=${email}`);
          }
        } catch (backfillError) {
          // Don't fail the join if backfill fails - log and continue
          console.error("Error during assignedRaUid backfill:", backfillError);
        }
      }

      console.log(`User ${uid} joined hall ${finalHallId} as ${finalRole}`);
    } else {
      console.log(`User ${uid} registered as ${finalRole} (no hall assigned - admin will assign later)`);
    }

    return {
      success: true,
      role: finalRole,
      hallId: finalHallId,
      message: finalHallId ?
        `Successfully joined as ${finalRole}` :
        `Registered as ${finalRole}. You will be assigned to a hall by your administrator.`,
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
        hallDirector: hallData?.hallDirector || null,
        createdAt: now,
        updatedAt: now,
        createdBy: uid,
      });

      // CRITICAL: Add creator as a staff member so they can see/manage the hall
      await db.collection("halls").doc(hallId).collection("members").doc(uid).set({
        role: "staff",
        isActive: true,
        joinedAt: now,
        userId: uid,
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

      // If hall director is specified and has a uid, grant them staff status
      if (hallData?.hallDirector?.uid) {
        const hdUid = hallData.hallDirector.uid;
        const hdName = hallData.hallDirector.name;

        // Add hall director as staff member in the hall
        await db.collection("halls").doc(hallId).collection("members").doc(hdUid).set({
          role: "staff",
          isActive: true,
          isHallDirector: true,
          joinedAt: now,
          userId: hdUid,
        });

        // Create/update hall director's profile in the hall
        await db.collection("halls").doc(hallId).collection("profiles").doc(hdUid).set({
          displayName: hdName,
          role: "staff",
          isHallDirector: true,
          updatedAt: now,
        }, { merge: true });

        // Update hall director's user document to staff role
        await db.collection("users").doc(hdUid).update({
          role: "staff",
          hallId: hallId,
          updatedAt: now,
        });

        console.log(`Hall director ${hdUid} (${hdName}) granted staff status for hall ${hallId}`);
      }

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
      if (hallData.hallDirector !== undefined) updateData.hallDirector = hallData.hallDirector;

      await db.collection("halls").doc(hallId).update(updateData);

      // If hall director is being updated and has a uid, grant them staff status
      if (hallData.hallDirector?.uid) {
        const hdUid = hallData.hallDirector.uid;
        const hdName = hallData.hallDirector.name;
        const now = admin.firestore.FieldValue.serverTimestamp();

        // Get the old hall director to potentially remove their HD flag
        const oldHallDoc = hallDoc.data();
        const oldHdUid = oldHallDoc?.hallDirector?.uid;

        // If there was a previous hall director, remove their isHallDirector flag
        if (oldHdUid && oldHdUid !== hdUid) {
          const oldHdMemberRef = db.collection("halls").doc(hallId).collection("members").doc(oldHdUid);
          const oldHdMember = await oldHdMemberRef.get();
          if (oldHdMember.exists) {
            await oldHdMemberRef.update({
              isHallDirector: false,
              updatedAt: now,
            });
          }

          const oldHdProfileRef = db.collection("halls").doc(hallId).collection("profiles").doc(oldHdUid);
          const oldHdProfile = await oldHdProfileRef.get();
          if (oldHdProfile.exists) {
            await oldHdProfileRef.update({
              isHallDirector: false,
              updatedAt: now,
            });
          }

          console.log(`Removed hall director status from ${oldHdUid}`);
        }

        // Add new hall director as staff member in the hall
        await db.collection("halls").doc(hallId).collection("members").doc(hdUid).set({
          role: "staff",
          isActive: true,
          isHallDirector: true,
          joinedAt: now,
          userId: hdUid,
        }, { merge: true });

        // Create/update hall director's profile in the hall
        await db.collection("halls").doc(hallId).collection("profiles").doc(hdUid).set({
          displayName: hdName,
          role: "staff",
          isHallDirector: true,
          updatedAt: now,
        }, { merge: true });

        // Update hall director's user document to staff role
        await db.collection("users").doc(hdUid).update({
          role: "staff",
          hallId: hallId,
          updatedAt: now,
        });

        console.log(`Hall director ${hdUid} (${hdName}) granted staff status for hall ${hallId}`);
      }

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
// importRoster
// Callable function for staff to import Excel/CSV roster data
// V1 Contract:
// - Preserve claims on re-import (never overwrite isClaimed/claimedByUid/claimedAt)
// - Last row wins (deduplicate by email within payload)
// - Proper batch handling (new batch after each commit)
// ============================================================

interface RosterEntry {
  email: string;
  firstName: string;
  lastName: string;
  roomNumber: string;
  floor: string;
  wing?: string;
  role: "resident" | "ra";
  assignedRaEmail?: string;
}

interface ImportRosterRequest {
  hallId: string;
  data: RosterEntry[];
}

export const importRoster = functions.https.onCall(
  async (data: ImportRosterRequest, context): Promise<{ success: boolean; count: number }> => {
    // 1. Auth & Perms
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    // Check if user is staff/ra in the hall using a helper or raw db check
    const uid = context.auth.uid;
    const { hallId, data: rosterData } = data;

    if (!hallId || !rosterData || !Array.isArray(rosterData)) {
      throw new HttpsError("invalid-argument", "Valid hallId and roster data required");
    }

    // Check membership role: must be 'staff' or 'ra'
    const memberDoc = await db.collection("halls").doc(hallId).collection("members").doc(uid).get();
    const userRole = memberDoc.data()?.role;
    const isGlobalAdmin = (await db.collection("users").doc(uid).get()).data()?.role === "admin";

    if (!isGlobalAdmin && (!memberDoc.exists || !["staff", "ra"].includes(userRole))) {
      throw new HttpsError("permission-denied", "Only Staff/RAs can import rosters");
    }

    // V1: Last row wins - deduplicate by email, keeping last occurrence
    const deduplicatedMap: Map<string, RosterEntry> = new Map();
    for (const entry of rosterData) {
      const normalizedEmail = entry.email.toLowerCase().trim();
      if (normalizedEmail) {
        deduplicatedMap.set(normalizedEmail, entry);
      }
    }

    const uniqueEntries = Array.from(deduplicatedMap.entries());
    let count = 0;
    let batchCount = 0;
    let batch = db.batch();

    // 2. Process deduplicated entries
    for (const [email, entry] of uniqueEntries) {
      const ref = db.collection("halls").doc(hallId).collection("roster").doc(email);

      // V1 CRITICAL: Never touch claim fields during import
      // Import only writes: firstName, lastName, roomNumber, floor, wing, role, assignedRaEmail, importedBy, updatedAt
      // Claim fields (isClaimed, claimedByUid, claimedAt) are NEVER written by import
      const rosterPayload = {
        email: email,
        firstName: entry.firstName || "",
        lastName: entry.lastName || "",
        roomNumber: entry.roomNumber || "",
        floor: entry.floor || "",
        wing: entry.wing || "",
        role: entry.role || "resident",
        assignedRaEmail: entry.assignedRaEmail?.toLowerCase().trim() || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        importedBy: uid,
        // NOTE: isClaimed, claimedByUid, claimedAt are intentionally NOT included
        // They will be preserved if doc exists, or absent for new docs (unclaimed by default)
      };

      batch.set(ref, rosterPayload, { merge: true });
      batchCount++;
      count++;

      // V1: Correct batch handling - commit and create NEW batch every 450 writes
      if (batchCount >= 450) {
        await batch.commit();
        batch = db.batch(); // Create new batch after commit
        batchCount = 0;
        console.log(`importRoster: Committed batch, ${count} entries processed so far`);
      }
    }

    // Commit remaining entries
    if (batchCount > 0) {
      await batch.commit();
    }

    console.log(
      `importRoster: Imported ${count} unique entries ` +
      `(from ${rosterData.length} input rows) into hall ${hallId}`
    );
    return { success: true, count };
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
      // Set lastMessageAt = createdAt so conversations appear in queries immediately
      transaction.set(convRef, {
        type: "dm" as ConversationType,
        tenantId: callerTenantId,
        participantIds: [uid, otherUid],
        createdAt: now,
        lastMessagePreview: null,
        lastMessageAt: now, // Always set to createdAt for query consistency
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
    // Set lastMessageAt = createdAt so conversations appear in queries immediately
    batch.set(convRef, {
      type: "group" as ConversationType,
      tenantId: callerTenantId,
      title: title.trim(),
      participantIds: allMemberUids,
      createdAt: now,
      lastMessagePreview: null,
      lastMessageAt: now, // Always set to createdAt for query consistency
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
//
// V1 Push Token Contract:
// - Read token from /users/{uid}.fcmToken (single token per user)
// - Build {uid, token} pairs to track ownership correctly
// - Clean up invalid tokens by UID, not by array index
// - Always send badge = 1 (not accurate, acceptable for V1)
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

      // V1 FIX: Build {uid, token} pairs to track ownership correctly
      // This prevents the index mismatch bug when cleaning up tokens
      interface TokenPair {
        uid: string;
        token: string;
      }

      const tokenPairs: TokenPair[] = [];

      for (const uid of recipientIds) {
        const userDoc = await db.collection("users").doc(uid).get();
        const token = userDoc.data()?.fcmToken;
        // Only include users with valid tokens
        if (token && typeof token === "string" && token.length > 0) {
          tokenPairs.push({ uid, token });
        } else {
          console.log(`No FCM token for user ${uid}, skipping`);
        }
      }

      if (tokenPairs.length === 0) {
        console.log("No FCM tokens found for any recipients");
        return;
      }

      console.log(`Found ${tokenPairs.length} FCM tokens for ${recipientIds.length} recipients`);

      // Extract just tokens for the multicast call
      const tokens = tokenPairs.map((p) => p.token);

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
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              "alert": {
                "title": notificationTitle,
                "body": preview || "New message",
              },
              "sound": "default",
              "badge": 1, // V1: Always badge=1 (not accurate, acceptable)
              "mutable-content": 1,
              "content-available": 1,
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

      // V1 FIX: Clean up invalid tokens using the paired UID (not array index)
      if (response.failureCount > 0) {
        const cleanupPromises: Promise<void>[] = [];

        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            const errorMsg = resp.error?.message;
            const pair = tokenPairs[idx]; // Correct mapping via pairs array

            console.error(
              `FCM send failed for user ${pair.uid} (token ${pair.token.substring(0, 20)}...): ` +
              `code=${errorCode}, message=${errorMsg}`
            );

            // Remove invalid/unregistered tokens
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              console.log(`Cleaning up invalid token for user ${pair.uid}`);
              cleanupPromises.push(
                db.collection("users").doc(pair.uid).update({
                  fcmToken: admin.firestore.FieldValue.delete(),
                }).then(() => {
                  console.log(`Deleted fcmToken for user ${pair.uid}`);
                }).catch((err) => {
                  console.error(`Failed to delete fcmToken for user ${pair.uid}:`, err);
                })
              );
            }
          }
        });

        if (cleanupPromises.length > 0) {
          await Promise.all(cleanupPromises);
          console.log(`Cleaned up ${cleanupPromises.length} invalid tokens`);
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
    // V1 FIX: Firestore cannot do inequality filters on two fields.
    // Query by startTime <= now, then filter in-memory for endTime > now
    // NOTE: Collection is "shifts" (not "duty_shifts"), fields are startTime/endTime
    try {
      const nowDate = new Date();
      const nowTimestamp = admin.firestore.Timestamp.fromDate(nowDate);

      const dutyShiftsSnapshot = await db
        .collection("halls")
        .doc(hallId)
        .collection("shifts")
        .where("startTime", "<=", nowTimestamp)
        .orderBy("startTime", "desc")
        .limit(10)
        .get();

      // Find first active shift (in-memory filter for endTime > now)
      let activeShift: FirebaseFirestore.DocumentData | null = null;
      for (const doc of dutyShiftsSnapshot.docs) {
        const shiftData = doc.data();
        const endTime = shiftData.endTime as admin.firestore.Timestamp | undefined;
        if (endTime && endTime.toMillis() > nowTimestamp.toMillis()) {
          activeShift = shiftData;
          break;
        }
      }

      if (activeShift) {
        // V1: Support both field names (userId is canonical)
        const onDutyRaUid = activeShift.userId || activeShift.odRAuid;

        if (onDutyRaUid) {
          // Get RA's FCM token
          const raDoc = await db.collection("users").doc(onDutyRaUid).get();
          const fcmToken = raDoc.data()?.fcmToken;

          if (fcmToken) {
            // Send push notification to on-duty RA
            const urgencyLabel = urgency.charAt(0).toUpperCase() + urgency.slice(1);
            const notificationTitle = `${urgencyLabel} Priority Noise Report`;
            const notificationBody = `Noise reported at ${location.trim()}`;

            const payload: admin.messaging.Message = {
              token: fcmToken,
              notification: {
                title: notificationTitle,
                body: notificationBody,
              },
              data: {
                type: "noise_report",
                reportId: reportRef.id,
                hallId: hallId,
                urgency: urgency,
              },
              apns: {
                headers: {
                  "apns-priority": urgency === "high" ? "10" : "5",
                  "apns-push-type": "alert",
                },
                payload: {
                  aps: {
                    "alert": {
                      title: notificationTitle,
                      body: notificationBody,
                    },
                    "sound": urgency === "high" ? "default" : "default",
                    "badge": 1,
                    "mutable-content": 1,
                    "content-available": 1,
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
            console.log(`Push notification sent to on-duty RA ${onDutyRaUid} for noise report`);
          } else {
            // On-duty RA has no FCM token, fall through to notify all RAs
            console.log("On-duty RA has no FCM token, will notify all RAs");
          }
        }
      }

      // If no on-duty RA found or no token, notify all RAs/staff in the hall
      if (!activeShift || !activeShift.userId) {
        const fcmTokens: string[] = [];

        // Query for RAs and staff (both can handle concerns)
        const membersSnapshot = await db
          .collection("halls")
          .doc(hallId)
          .collection("members")
          .where("role", "in", ["ra", "staff"])
          .where("isActive", "==", true)
          .get();

        console.log(`Found ${membersSnapshot.size} active RA/staff members in hall ${hallId}`);

        for (const memberDoc of membersSnapshot.docs) {
          const raUid = memberDoc.data().userId || memberDoc.id;
          const memberRole = memberDoc.data().role;
          console.log(`Checking member ${raUid} (role: ${memberRole})`);
          if (raUid) {
            const raUserDoc = await db.collection("users").doc(raUid).get();
            const fcmToken = raUserDoc.data()?.fcmToken;
            if (fcmToken && !fcmTokens.includes(fcmToken)) {
              fcmTokens.push(fcmToken);
              console.log(`Added FCM token for ${raUid}`);
            } else if (!fcmToken) {
              console.log(`No FCM token for ${raUid}`);
            }
          }
        }

        if (fcmTokens.length > 0) {
          const urgencyLabel = urgency.charAt(0).toUpperCase() + urgency.slice(1);
          const notificationTitle = `${urgencyLabel} Priority Noise Report`;
          const notificationBody = `Noise reported at ${location.trim()}`;

          const sendPromises = fcmTokens.map((token) => {
            const payload: admin.messaging.Message = {
              token: token,
              notification: {
                title: notificationTitle,
                body: notificationBody,
              },
              data: {
                type: "noise_report",
                reportId: reportRef.id,
                hallId: hallId,
                urgency: urgency,
              },
              apns: {
                headers: {
                  "apns-priority": urgency === "high" ? "10" : "5",
                  "apns-push-type": "alert",
                },
                payload: {
                  aps: {
                    "alert": {
                      title: notificationTitle,
                      body: notificationBody,
                    },
                    "sound": "default",
                    "badge": 1,
                    "mutable-content": 1,
                    "content-available": 1,
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

            return admin.messaging().send(payload).catch((err) => {
              console.error(`Failed to send notification to token: ${err}`);
              return null;
            });
          });

          await Promise.all(sendPromises);
          console.log(`Push notifications sent to ${fcmTokens.length} RA(s) for noise report (no on-duty RA)`);
        } else {
          console.log("No RA FCM tokens found for notification");
        }
      }
    } catch (error) {
      // Don't fail the report if notification fails
      console.error("Error sending notification to RA(s):", error);
    }

    return {
      success: true,
      reportId: reportRef.id,
      message: "Noise report submitted successfully",
    };
  }
);

// ============================================================
// getOnDutyRa
// V1: Callable function for residents to get current on-duty RA info
// Used by "Contact Duty RA" feature
//
// V1 FIX: Firestore cannot do inequality filters on two fields.
// We query by start <= now, then filter in-memory for end > now.
// ============================================================

interface GetOnDutyRaRequest {
  hallId: string;
}

interface GetOnDutyRaResponse {
  success: boolean;
  onDuty: boolean;
  raUid?: string;
  displayName?: string;
  email?: string;
  shiftStart?: admin.firestore.Timestamp;
  shiftEnd?: admin.firestore.Timestamp;
}

export const getOnDutyRa = functions.https.onCall(
  async (data: GetOnDutyRaRequest, context): Promise<GetOnDutyRaResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { hallId } = data;

    if (!hallId) {
      throw new HttpsError("invalid-argument", "hallId is required");
    }

    // Verify user is a member of the hall
    const memberDoc = await db
      .collection("halls")
      .doc(hallId)
      .collection("members")
      .doc(uid)
      .get();

    if (!memberDoc.exists) {
      throw new HttpsError("permission-denied", "You are not a member of this hall");
    }

    // V1 FIX: Firestore does not allow inequality filters on two fields.
    // Query: where("startTime", "<=", now) + orderBy("startTime", "desc") + limit(10)
    // Then filter in-memory for endTime > now
    // NOTE: Collection is "shifts" (not "duty_shifts"), fields are startTime/endTime
    const nowDate = new Date();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(nowDate);

    const dutyShiftsSnapshot = await db
      .collection("halls")
      .doc(hallId)
      .collection("shifts")
      .where("startTime", "<=", nowTimestamp)
      .orderBy("startTime", "desc")
      .limit(10)
      .get();

    // Find the first shift where endTime > now (in-memory filter)
    let activeShift: FirebaseFirestore.DocumentData | null = null;
    for (const doc of dutyShiftsSnapshot.docs) {
      const shiftData = doc.data();
      const endTime = shiftData.endTime as admin.firestore.Timestamp | undefined;
      if (endTime && endTime.toMillis() > nowTimestamp.toMillis()) {
        activeShift = shiftData;
        break;
      }
    }

    if (!activeShift) {
      console.log(`No on-duty RA found for hall ${hallId} at ${nowDate.toISOString()}`);
      return {
        success: true,
        onDuty: false,
      };
    }

    // V1: Support both field names during transition (userId is canonical)
    const onDutyRaUid = activeShift.userId || activeShift.odRAuid;

    if (!onDutyRaUid) {
      console.log(`Duty shift found but no RA UID in hall ${hallId}`);
      return {
        success: true,
        onDuty: false,
      };
    }

    // Get RA's profile from the hall for displayName
    const raProfileDoc = await db
      .collection("halls")
      .doc(hallId)
      .collection("profiles")
      .doc(onDutyRaUid)
      .get();

    let displayName = "";
    if (raProfileDoc.exists) {
      displayName = raProfileDoc.data()?.displayName || "";
    }

    // V1: Email exposure is allowed - get from /users/{raUid}
    let email = "";
    const raUserDoc = await db.collection("users").doc(onDutyRaUid).get();
    if (raUserDoc.exists) {
      email = raUserDoc.data()?.email || "";
    }

    console.log(`On-duty RA for hall ${hallId}: ${onDutyRaUid} (${displayName})`);

    return {
      success: true,
      onDuty: true,
      raUid: onDutyRaUid,
      displayName: displayName,
      email: email,
      shiftStart: activeShift.startTime || activeShift.start || undefined,
      shiftEnd: activeShift.endTime || activeShift.end || undefined,
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

// ============================================================
// getTenantUsers
// Returns all users in the same tenant for chat search
// Callable by any authenticated user in the tenant
// ============================================================

interface TenantUserInfo {
  uid: string;
  displayName: string;
  email: string | null;
  firstName: string | null;
  lastName: string | null;
}

interface GetTenantUsersRequest {
  excludeSelf?: boolean;
}

interface GetTenantUsersResponse {
  users: TenantUserInfo[];
}

export const getTenantUsers = functions.https.onCall(
  async (data: GetTenantUsersRequest, context): Promise<GetTenantUsersResponse> => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const excludeSelf = data?.excludeSelf !== false; // Default to true

    // Get caller's tenantId
    const callerTenantId = await getTenantId(uid);

    // Query all users in the same tenant
    const usersSnapshot = await db
      .collection("users")
      .where("tenantId", "==", callerTenantId)
      .limit(500) // Reasonable limit for chat search
      .get();

    const users: TenantUserInfo[] = [];

    for (const doc of usersSnapshot.docs) {
      // Skip self if excludeSelf is true
      if (excludeSelf && doc.id === uid) {
        continue;
      }

      const userData = doc.data();
      const email = userData.email || null;

      // Build display name from available sources
      let displayName = userData.displayName || "";
      const firstName = userData.firstName || null;
      const lastName = userData.lastName || null;

      // If no displayName, try to build from firstName + lastName
      if (!displayName && (firstName || lastName)) {
        displayName = [firstName, lastName].filter(Boolean).join(" ").trim();
      }

      // Fallback to email prefix if no name available
      if (!displayName && email) {
        displayName = email.split("@")[0];
      }

      // Ultimate fallback to first 8 chars of uid (shouldn't happen often)
      if (!displayName) {
        displayName = doc.id.substring(0, 8);
      }

      users.push({
        uid: doc.id,
        displayName,
        email,
        firstName,
        lastName,
      });
    }

    console.log(`getTenantUsers: Returned ${users.length} users for tenant ${callerTenantId}`);

    return { users };
  }
);

// ============================================================
// getUserDisplayName
// Returns display name for a specific user (for chat sender names)
// Callable by any authenticated user in the same tenant
// ============================================================

interface GetUserDisplayNameRequest {
  uid: string;
}

interface GetUserDisplayNameResponse {
  uid: string;
  displayName: string;
}

export const getUserDisplayName = functions.https.onCall(
  async (data: GetUserDisplayNameRequest, context): Promise<GetUserDisplayNameResponse> => {
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const callerUid = context.auth.uid;
    const targetUid = data?.uid;

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "uid is required");
    }

    // Get caller's tenantId
    const callerTenantId = await getTenantId(callerUid);

    // Get target user's data
    const userDoc = await db.collection("users").doc(targetUid).get();

    if (!userDoc.exists) {
      // Return fallback for non-existent user
      return {
        uid: targetUid,
        displayName: targetUid.substring(0, 8),
      };
    }

    const userData = userDoc.data()!;

    // Verify same tenant (security check)
    if (userData.tenantId !== callerTenantId) {
      throw new HttpsError(
        "permission-denied",
        "Cannot get user info from different organization"
      );
    }

    const email = userData.email || null;

    // Build display name from available sources
    let displayName = userData.displayName || "";
    const firstName = userData.firstName || null;
    const lastName = userData.lastName || null;

    // If no displayName, try to build from firstName + lastName
    if (!displayName && (firstName || lastName)) {
      displayName = [firstName, lastName].filter(Boolean).join(" ").trim();
    }

    // Fallback to email prefix if no name available
    if (!displayName && email) {
      displayName = email.split("@")[0];
    }

    // Ultimate fallback to first 8 chars of uid
    if (!displayName) {
      displayName = targetUid.substring(0, 8);
    }

    return {
      uid: targetUid,
      displayName,
    };
  }
);

// ============================================================
// submitConcern
// Callable function for residents to submit concerns/complaints
// Sends push notification to on-duty RA (or all RAs in hall)
// ============================================================

interface SubmitConcernRequest {
  hallId: string;
  category: string; // "noise" | "maintenance" | "safety" | "roommate" | "other"
  message: string;
  location?: string;
  isAnonymous?: boolean;
}

interface SubmitConcernResponse {
  success: boolean;
  concernId: string;
  message: string;
}

export const submitConcern = functions.https.onCall(
  async (data: SubmitConcernRequest, context): Promise<SubmitConcernResponse> => {
    // Require authentication
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const uid = context.auth.uid;
    const { hallId, category, message, location, isAnonymous } = data;

    // Validate required fields
    if (!hallId) {
      throw new HttpsError("invalid-argument", "hallId is required");
    }

    if (!category) {
      throw new HttpsError("invalid-argument", "category is required");
    }

    const validCategories = ["noise", "maintenance", "safety", "roommate", "other"];
    if (!validCategories.includes(category)) {
      throw new HttpsError("invalid-argument", "Invalid category");
    }

    if (!message || message.trim().length === 0) {
      throw new HttpsError("invalid-argument", "message is required");
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

    // Get reporter's info (unless anonymous)
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    const reporterName = isAnonymous ? "Anonymous" : (userData?.displayName || "Resident");
    const reporterRoom = isAnonymous ? null : (memberDoc.data()?.roomNumber || null);

    // Find on-duty RA
    // NOTE: Collection is "shifts" (not "duty_shifts"), fields are startTime/endTime
    let onDutyRaUid: string | null = null;
    let onDutyRaName: string | null = null;

    try {
      const nowDate = new Date();
      const nowTimestamp = admin.firestore.Timestamp.fromDate(nowDate);

      const dutyShiftsSnapshot = await db
        .collection("halls")
        .doc(hallId)
        .collection("shifts")
        .where("startTime", "<=", nowTimestamp)
        .orderBy("startTime", "desc")
        .limit(10)
        .get();

      // Find first active shift (in-memory filter for endTime > now)
      for (const doc of dutyShiftsSnapshot.docs) {
        const shiftData = doc.data();
        const endTime = shiftData.endTime as admin.firestore.Timestamp | undefined;
        if (endTime && endTime.toMillis() > nowTimestamp.toMillis()) {
          onDutyRaUid = shiftData.userId || shiftData.odRAuid || null;
          onDutyRaName = shiftData.displayName || shiftData.name || null;
          break;
        }
      }
    } catch (error) {
      console.error("Error finding on-duty RA:", error);
    }

    // Create the concern
    const now = admin.firestore.FieldValue.serverTimestamp();
    const concernRef = db
      .collection("halls")
      .doc(hallId)
      .collection("concerns")
      .doc();

    await concernRef.set({
      category: category,
      message: message.trim(),
      location: location?.trim() || null,
      residentUid: isAnonymous ? null : uid,
      residentName: reporterName,
      residentRoom: reporterRoom,
      onDutyRAUid: onDutyRaUid,
      onDutyRAName: onDutyRaName,
      isAnonymous: isAnonymous || false,
      status: "pending",
      createdAt: now,
      resolvedAt: null,
      resolvedBy: null,
      raNote: null,
    });

    console.log(`Concern ${concernRef.id} created by ${isAnonymous ? "anonymous" : uid} in hall ${hallId}`);

    // Send push notification to on-duty RA (if available), otherwise all RAs in hall
    try {
      const fcmTokens: string[] = [];

      if (onDutyRaUid) {
        // Get on-duty RA's FCM token
        const raDoc = await db.collection("users").doc(onDutyRaUid).get();
        const fcmToken = raDoc.data()?.fcmToken;
        if (fcmToken) {
          fcmTokens.push(fcmToken);
        }
      }

      // If no on-duty RA or no token, notify all RAs/staff in the hall
      if (fcmTokens.length === 0) {
        console.log(`No on-duty RA FCM token, falling back to all RAs/staff in hall ${hallId}`);

        // Query for RAs and staff (both can handle concerns)
        const membersSnapshot = await db
          .collection("halls")
          .doc(hallId)
          .collection("members")
          .where("role", "in", ["ra", "staff"])
          .where("isActive", "==", true)
          .get();

        console.log(`Found ${membersSnapshot.size} active RA/staff members in hall ${hallId}`);

        for (const memberDoc of membersSnapshot.docs) {
          const raUid = memberDoc.data().userId || memberDoc.id;
          const memberRole = memberDoc.data().role;
          console.log(`Checking member ${raUid} (role: ${memberRole})`);
          if (raUid) {
            const raUserDoc = await db.collection("users").doc(raUid).get();
            const fcmToken = raUserDoc.data()?.fcmToken;
            if (fcmToken && !fcmTokens.includes(fcmToken)) {
              fcmTokens.push(fcmToken);
              console.log(`Added FCM token for ${raUid}`);
            } else if (!fcmToken) {
              console.log(`No FCM token for ${raUid}`);
            }
          }
        }
      }

      if (fcmTokens.length > 0) {
        // Format category for display
        const categoryLabels: Record<string, string> = {
          noise: "Noise",
          maintenance: "Maintenance",
          safety: "Safety",
          roommate: "Roommate",
          other: "General",
        };
        const categoryLabel = categoryLabels[category] || "General";

        const notificationTitle = `New ${categoryLabel} Concern`;
        const msgPreview = message.trim().substring(0, 100) + (message.length > 100 ? "..." : "");
        const notificationBody = isAnonymous ?
          `Anonymous report: ${msgPreview}` :
          `${reporterName}: ${msgPreview}`;

        // Send to all collected tokens
        const sendPromises = fcmTokens.map((token) => {
          const payload: admin.messaging.Message = {
            token: token,
            notification: {
              title: notificationTitle,
              body: notificationBody,
            },
            data: {
              type: "concern",
              concernId: concernRef.id,
              hallId: hallId,
              category: category,
            },
            apns: {
              headers: {
                "apns-priority": category === "safety" ? "10" : "5",
                "apns-push-type": "alert",
              },
              payload: {
                aps: {
                  "alert": {
                    title: notificationTitle,
                    body: notificationBody,
                  },
                  "sound": "default",
                  "badge": 1,
                  "mutable-content": 1,
                  "content-available": 1,
                },
              },
            },
            android: {
              notification: {
                sound: "default",
                channelId: "concerns",
                priority: category === "safety" ? "high" : "default",
              },
            },
          };

          return admin.messaging().send(payload).catch((err) => {
            console.error(`Failed to send notification to token: ${err}`);
            return null;
          });
        });

        await Promise.all(sendPromises);
        console.log(`Push notifications sent to ${fcmTokens.length} RA(s) for concern`);
      } else {
        console.log("No RA FCM tokens found for notification");
      }
    } catch (error) {
      // Don't fail the concern if notification fails
      console.error("Error sending notification to RA(s):", error);
    }

    return {
      success: true,
      concernId: concernRef.id,
      message: "Concern submitted successfully",
    };
  }
);
