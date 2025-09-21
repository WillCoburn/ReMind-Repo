// ============================
// File: App/ViewModels/AppViewModel.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Published state
    @Published var user: UserProfile?
    @Published var affirmations: [Affirmation] = []
    @Published var isLoading = false

    // MARK: - Services
    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions()

    // Optional convenience if your views want it:
    var isOnboarded: Bool { user != nil }

    // MARK: - Init
    init() {
        // Observe auth state and refresh when it changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { await self.loadUserAndEntries(user?.uid) }
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

    private func loadUserAndEntries(_ uid: String?) async {
        guard let uid = uid else {
            self.user = nil
            self.affirmations = []
            return
        }
        // Load minimal profile (phone may already be set)
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            if snap.exists {
                let phone = snap.get("phoneE164") as? String ?? ""
                self.user = UserProfile(uid: uid, phoneE164: phone)
            } else {
                self.user = UserProfile(uid: uid, phoneE164: "")
            }
        } catch {
            print("❌ load user error:", error.localizedDescription)
        }
        await refreshAll()
    }

    // MARK: - Entries
    func submit(text: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            // Write straight to Firestore; no need to construct local model first
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

            self.affirmations = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let text = data["text"] as? String else { return nil }
                let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                // Construct with required id
                return Affirmation(
                    id: doc.documentID,
                    text: text,
                    createdAt: ts
                )
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
        self.user = nil
        self.affirmations = []
    }
}
