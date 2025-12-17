# HallPals Backend Contract v1 (Final)

## 1. Firestore Schema

### Global Collections

#### `/users/{userId}`
- email: string
- displayName: string
- role: "ra" | "staff" | "resident"
- hallId: string
- createdAt: timestamp
- updatedAt: timestamp

#### `/users/{userId}/devices/{deviceId}`
- fcmToken: string
- platform: "ios" | "android" | "web"
- lastSeenAt: timestamp
- createdAt: timestamp

---

### Hall-Scoped Collections

#### `/halls/{hallId}`
- name: string
- building: string
- createdAt: timestamp

#### `/halls/{hallId}/members/{userId}`
- role: "ra" | "staff" | "resident"
- userId: string (Synced for Collection Group Queries)
- roomNumber: string?
- assignedRaEmail: string?
- joinedAt: timestamp
- isActive: boolean

#### `/halls/{hallId}/profiles/{userId}` (Public Read)
- displayName: string
- role: "ra" | "staff" | "resident"
- isHallDirector: boolean?
- updatedAt: timestamp

#### `/halls/{hallId}/roster/{email}` (Pending Roster)
- email: string (ID)
- firstName: string
- lastName: string
- roomNumber: string
- floor: string
- wing: string?
- role: "resident" | "ra"
- assignedRaEmail: string?
- isClaimed: boolean
- claimedByUid: string?
- claimedAt: timestamp?
- importedBy: string
- importedAt: timestamp

#### `/halls/{hallId}/residents/{residentId}`
- name: string
- room: string
- email: string
- phone: string
- moveOutStatus: "none" | "requested" | "approved" | "scheduled" | "completed" | "cancelled"
- moveOutDate: timestamp?
- syncSource: "roompact" | "msgraph" | "manual"
- updatedAt: timestamp

#### `/halls/{hallId}/rooms/{roomId}`
- roomNumber: string
- floor: string?
- residentIds: string[]

---

## 2. Room Inspections

#### `/halls/{hallId}/room_inspections/{inspectionId}`
- roomId: string
- inspectorId: string
- checklist: [{ id: string, name: string, checked: boolean }]
- notes: string
- photoUrls: string[]
- isComplete: boolean
- inspectedAt: timestamp?
- createdAt: timestamp

---

## 3. Bulletin & Shifts

#### `/halls/{hallId}/bulletin_tasks/{taskId}`
- title: string
- createdBy: string
- isCompleted: boolean
- completedBy: string?
- completedAt: timestamp?
- deadline: timestamp?
- notes: string?
- createdAt: timestamp

#### `/halls/{hallId}/shifts/{shiftId}`
- userId: string
- start: timestamp
- end: timestamp
- syncedAt: timestamp

---

## 4. Rounds (High-Volume Subcollections)

#### `/halls/{hallId}/rounds_sessions/{sessionId}`
- userId: string
- status: "notStarted" | "inProgress" | "paused" | "completed" | "cancelled"
- startTime: timestamp
- endTime: timestamp?
- startingFloor: number
- currentFloor: number
- totalSteps: number
- baselineAltitude: number?
- overallCoverage: number (0.0–1.0)

#### `/halls/{hallId}/rounds_sessions/{sessionId}/floor_visits/{visitId}`
- floorNumber: number
- entryTime: timestamp
- exitTime: timestamp?
- estimatedCoverage: number (0.0–1.0)
- totalSteps: number

#### `/halls/{hallId}/rounds_sessions/{sessionId}/floor_visits/{visitId}/segments/{segmentId}`
- startTime: timestamp
- endTime: timestamp
- motionState: "idle" | "walking" | "stationary" | "unknown"
- stepCount: number
- zone: "eastWing" | "westWing" | "stairwell" | "unknown"
- classification: "hallwayCoverage" | "stairwellTraversal" | "idlePause" | "transitioning"
- altitudeChange: number

---

## 5. Unified Conversations

#### `/halls/{hallId}/conversations/{conversationId}`
- type: "group" | "dm"
- name: string?
- icon: string?
- participantIds: string[]
- lastMessage: string
- lastMessageAt: timestamp
- createdAt: timestamp

#### `/halls/{hallId}/conversations/{conversationId}/messages/{messageId}`
- senderId: string
- text: string
- imageUrl: string?
- createdAt: timestamp

#### `/halls/{hallId}/conversations/{conversationId}/unread/{userId}`
- count: number
- lastReadAt: timestamp

---

## 6. Required Indexes

- rounds_sessions: userId ASC, status ASC
- rounds_sessions: userId ASC, startTime DESC
- shifts: userId ASC, start ASC
- bulletin_tasks: isCompleted ASC, deadline ASC
- room_inspections: isComplete ASC, createdAt DESC
- conversations: participantIds ARRAY_CONTAINS, lastMessageAt DESC
- messages: createdAt DESC

---

## 7. Storage Paths

- /room_inspections/{hallId}/{inspectionId}/photo_{n}.jpg
- /chat_attachments/{hallId}/{conversationId}/{messageId}.jpg
- /profile_images/{userId}/avatar.jpg

---

## 8. AI Functions

#### `askAI` (Callable)
- **Input**:
  - `prompt` (string): The user's input/question.
  - `model` (string, optional): Gemini model (default: "gemini-2.5-flash").
- **Output**:
  - `response` (string): The AI generated text.
  - `model` (string): The model used.
- **Errors**:
  - `unauthenticated`: User must be logged in.
  - `internal`: API configuration missing or upstream error.

## 9. Management Functions

#### `importRoster` (Callable)
- **Input**:
  - `hallId` (string)
  - `data` (Apply[]): Array of roster entries.
- **Output**:
  - `success` (boolean)
  - `count` (number)
- **Permissions**: Staff or RA of the hall only.

#### `joinHallWithCode` (Callable - Updated)
- **Logic**: Now performs "Roster Claim". Checks `roster/{email}`. If found, marks claimed and copies `roomNumber` + `assignedRaEmail` to member record.
