import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class DocsService: ObservableObject {
    static let shared = DocsService()
    private let db = Firestore.firestore()

    // Cache for known doc titles to update UI quickly
    @Published var docTitles: [String: String] = [:]

    private init() {}

    #if DEBUG
    /// Debug helper to check current user's role in Firestore
    func debugCheckUserRole() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("🔍 DEBUG: No authenticated user")
            return
        }

        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            if userDoc.exists {
                let data = userDoc.data() ?? [:]
                print("🔍 DEBUG: User document found for \(uid)")
                print("   Role: \(data["role"] ?? "nil")")
                print("   HallId: \(data["hallId"] ?? "nil")")
                print("   TenantId: \(data["tenantId"] ?? "nil")")
                print("   Email: \(data["email"] ?? "nil")")
            } else {
                print("🔍 DEBUG: ⚠️ No user document exists for \(uid)")
            }
        } catch {
            print("🔍 DEBUG: ❌ Failed to read user document: \(error)")
        }
    }
    #endif
    
    /// Fetches the metadata for a specific document slug
    func fetchDocMeta(docId: String) async throws -> DocMeta {
        let snapshot = try await db.collection("docs").document(docId).getDocument()
        return try snapshot.data(as: DocMeta.self)
    }
    
    /// Listens to document metadata updates
    func listenToDocMeta(docId: String, completion: @escaping (Result<DocMeta, Error>) -> Void) -> ListenerRegistration {
        return db.collection("docs").document(docId).addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let snapshot = snapshot else {
                completion(.failure(NSError(domain: "DocsService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
                return
            }
            
            do {
                let doc = try snapshot.data(as: DocMeta.self)
                DispatchQueue.main.async {
                    self.docTitles[docId] = doc.title
                }
                completion(.success(doc))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Fetches all documents metadata
    func fetchAllDocs() async throws -> [DocMeta] {
        #if DEBUG
        print("🔥 DocsService: Fetching all docs from Firestore...")
        if let user = Auth.auth().currentUser {
            print("🔥 DocsService: Current user UID: \(user.uid)")
            print("🔥 DocsService: User email: \(user.email ?? "nil")")
        } else {
            print("🔥 DocsService: ⚠️ No authenticated user!")
        }
        #endif

        do {
            let snapshot = try await db.collection("docs").getDocuments()
            #if DEBUG
            print("🔥 DocsService: Got \(snapshot.documents.count) raw documents")
            for doc in snapshot.documents {
                print("   Raw doc ID: \(doc.documentID), data keys: \(doc.data().keys)")
            }
            #endif
            let docs = snapshot.documents.compactMap { doc -> DocMeta? in
                do {
                    let meta = try doc.data(as: DocMeta.self)
                    return meta
                } catch {
                    #if DEBUG
                    print("   ❌ Failed to decode doc \(doc.documentID): \(error)")
                    #endif
                    return nil
                }
            }
            #if DEBUG
            print("🔥 DocsService: Successfully decoded \(docs.count) docs")
            #endif
            return docs
        } catch {
            #if DEBUG
            print("🔥 DocsService: ❌ Query failed with error: \(error)")
            print("🔥 DocsService: Error details: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    /// Fetches all entries for a document, ordered by 'order'
    func fetchEntries(docId: String) async throws -> [DocEntry] {
        #if DEBUG
        print("📄 DocsService: Fetching entries for doc: \(docId)")
        #endif

        let snapshot = try await db.collection("docs").document(docId)
            .collection("entries")
            .order(by: "order")
            .getDocuments()

        #if DEBUG
        print("📄 DocsService: Got \(snapshot.documents.count) entries for \(docId)")
        for doc in snapshot.documents {
            print("   Entry ID: \(doc.documentID), keys: \(doc.data().keys)")
        }
        #endif

        let entries = snapshot.documents.compactMap { doc -> DocEntry? in
            do {
                return try doc.data(as: DocEntry.self)
            } catch {
                #if DEBUG
                print("   ❌ Failed to decode entry \(doc.documentID): \(error)")
                #endif
                return nil
            }
        }

        #if DEBUG
        print("📄 DocsService: Successfully decoded \(entries.count) entries")
        #endif

        return entries
    }
    
    /// Updates the text of a specific entry (Staff/Leadership only)
    func updateEntryText(docId: String, entryId: String, newText: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DocsService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let entryRef = db.collection("docs").document(docId).collection("entries").document(entryId)
        let docRef = db.collection("docs").document(docId)
        
        let batch = db.batch()
        
        // Update Entry
        batch.updateData([
            "text": newText,
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedBy": userId
        ], forDocument: entryRef)
        
        // Touch Parent Doc
        batch.updateData([
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedBy": userId
        ], forDocument: docRef)
        
        try await batch.commit()
    }
}
