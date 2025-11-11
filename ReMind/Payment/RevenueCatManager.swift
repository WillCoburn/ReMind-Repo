// ReMind/Payment/RevenueCatManager.swift
import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore

/// Client-side subscription state manager.
/// - Initializes RevenueCat
/// - Links RC identity to Firebase UID
/// - Tracks entitlement state
/// - Mirrors a lightweight rc.* payload into Firestore
/// - Computes & persists `active = (now < trialEndsAt) || entitlementActive`
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    private override init() { super.init() }

    @Published var entitlementActive: Bool = false
    @Published var managementURL: URL?
    @Published var lastCustomerInfo: CustomerInfo?

    private let db = Firestore.firestore()
    private var activeCheckTimer: Timer?

    // MARK: - Bootstrap

    func configure() {
        Purchases.configure(withAPIKey: PaywallConfig.rcPublicSDKKey)

        // Delegate gives us live updates across SDK versions
        Purchases.shared.delegate = self

        // Initial status
        Purchases.shared.getCustomerInfo { [weak self] info, _ in
            self?.apply(info)
        }

        // Attach to Firebase identity if already signed in
        identifyIfPossible()

        // Periodic recompute so trials flip without relaunch
        scheduleActiveRecomputeTimer()
    }

    /// Call this right after Firebase sign-in completes.
    func identifyIfPossible() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Purchases.shared.logIn(uid) { [weak self] info, _, _ in
            self?.apply(info)
        }
    }

    // MARK: - Restore (RCUI handles purchase automatically)

    func restore(completion: @escaping (Bool, String?) -> Void) {
        Purchases.shared.restorePurchases { info, err in
            if let err = err { completion(false, err.localizedDescription); return }
            completion(info?.entitlements[PaywallConfig.entitlementId]?.isActive == true, nil)
        }
    }

    // MARK: - Internal sync

    private func apply(_ info: CustomerInfo?) {
        guard let info else { return }
        lastCustomerInfo = info
        managementURL = info.managementURL
        entitlementActive = info.entitlements[PaywallConfig.entitlementId]?.isActive == true
        syncToFirestore(info: info)
    }

    /// Mirror essential RC state into Firestore and recompute `active`.
    private func syncToFirestore(info: CustomerInfo) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ent = info.entitlements[PaywallConfig.entitlementId]

        let rcPayload: [String: Any?] = [
            "entitlementActive": ent?.isActive ?? false,
            "productId": ent?.productIdentifier,
            "expiresAt": ent?.expirationDate?.timeIntervalSince1970,
            "latestPurchaseAt": ent?.latestPurchaseDate?.timeIntervalSince1970,
            "store": "app_store",
            "lastSyncedAt": Date().timeIntervalSince1970
        ]

        db.collection("users").document(uid).setData(["rc": rcPayload], merge: true) { _ in
            self.recomputeAndPersistActive(uid: uid, entitlement: ent?.isActive ?? false)
        }
    }

    /// Compute `active = trialNotOver || entitlementActive`, and write it.
    func recomputeAndPersistActive(uid: String? = nil, entitlement: Bool? = nil) {
        let uidValue: String
        if let u = uid { uidValue = u }
        else if let u = Auth.auth().currentUser?.uid { uidValue = u }
        else { return }

        let docRef = db.collection("users").document(uidValue)
        docRef.getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            let ts = (data["trialEndsAt"] as? Timestamp)?.dateValue()
            let onTrial = ts.map { Date() < $0 } ?? false
            let entitled = entitlement ?? ((data["rc"] as? [String: Any])?["entitlementActive"] as? Bool ?? false)
            let active = onTrial || entitled
            docRef.setData(["active": active], merge: true)
        }
    }

    private func scheduleActiveRecomputeTimer() {
        activeCheckTimer?.invalidate()
        activeCheckTimer = Timer.scheduledTimer(withTimeInterval: 60 * 10, repeats: true) { [weak self] _ in
            self?.recomputeAndPersistActive()
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        apply(customerInfo)
    }
}
