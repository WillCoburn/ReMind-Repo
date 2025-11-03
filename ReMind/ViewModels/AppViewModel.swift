// ============================
// File: App/ViewModels/AppViewModel.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user: UserProfile?
    @Published var entries: [Entry] = []
    @Published var isLoading = false

    // Current SMS opt-out state for the signed-in user
    @Published var smsOptOut: Bool = false

    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions()

    // Live user listener (keeps smsOptOut in sync while the app runs)
    private var userListener: ListenerRegistration?

    var isOnboarded: Bool { user != nil }

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { await self.loadUserAndEntries(user?.uid) }
        }
    }

    // MARK: - Live user doc listener
    private func attachUserListener(_ uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let data = snap?.data() else { return }
                let phone = data["phoneE164"] as? String ?? self.user?.phoneE164 ?? ""
                self.user = UserProfile(uid: uid, phoneE164: phone)
                self.smsOptOut = data["smsOptOut"] as? Bool ?? false
            }
    }

    private func detachUserListener() {
        userListener?.remove()
        userListener = nil
    }

    // MARK: - Initial load
    private func loadUserAndEntries(_ uid: String?) async {
        guard let uid = uid else {
            detachUserListener()
            self.user = nil
            self.entries = []
            self.smsOptOut = false
            return
        }

        // One-time fetch so UI has something immediately
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let phone = snap.get("phoneE164") as? String ?? ""
            self.user = UserProfile(uid: uid, phoneE164: phone)
            self.smsOptOut = snap.get("smsOptOut") as? Bool ?? false
        } catch {
            print("❌ load user error:", error.localizedDescription)
            if self.user == nil { self.user = UserProfile(uid: uid, phoneE164: "") }
            self.smsOptOut = false
        }

        attachUserListener(uid)
        await refreshAll()
    }

    // MARK: - On-demand fresh read (used on every toolbar tap)
    /// Re-reads users/{uid}.smsOptOut and updates `smsOptOut`.
    /// Returns the fresh value (false if missing or signed out).
    func reloadSmsOptOut() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.smsOptOut = false
            return false
        }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let fresh = snap.get("smsOptOut") as? Bool ?? false
            self.smsOptOut = fresh
            return fresh
        } catch {
            print("❌ reloadSmsOptOut error:", error.localizedDescription)
            return self.smsOptOut
        }
    }

    // MARK: - User Profile
    func setPhoneProfileAndLoad(_ phoneDigits: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let profile = UserProfile(uid: uid, phoneE164: "+1\(phoneDigits)")
        self.user = profile

        do {
            try await db.collection("users").document(uid).setData([
                "uid": profile.uid,
                "phoneE164": profile.phoneE164,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            await refreshAll()
        } catch {
            print("❌ setPhoneProfileAndLoad error:", error.localizedDescription)
        }
    }
    
    // MARK: - Entries
    func submit(text: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try await db.collection("users")
                .document(uid)
                .collection("entries")
                .addDocument(data: [
                    "text": trimmed,
                    "createdAt": FieldValue.serverTimestamp(),
                    "sent": false
                ])
            await refreshAll()
        } catch {
            print("❌ submit error:", error.localizedDescription)
        }
    }

    func refreshAll() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("entries")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            self.entries = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let text = data["text"] as? String else { return nil }
                let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                return Entry(id: doc.documentID, text: text, createdAt: ts)
            }
        } catch {
            print("❌ refreshAll error:", error.localizedDescription)
        }
    }

    // MARK: - Send One Now (Cloud Function)
    func sendOneNow() async -> Bool {
        do {
            let result = try await functions.httpsCallable("sendOneNow").call([:])
            print("✅ sendOneNow result:", result.data)
            await refreshAll()
            return true
        } catch {
            print("❌ sendOneNow error:", error.localizedDescription)
            return false
        }
    }

    // MARK: - Logout
    func logout() {
        do { try Auth.auth().signOut() } catch {
            print("❌ signOut error:", error.localizedDescription)
        }
        detachUserListener()
        self.user = nil
        self.entries = []
        self.smsOptOut = false
    }
}
