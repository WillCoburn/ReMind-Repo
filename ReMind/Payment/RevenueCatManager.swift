// ============================
// File: ReMind/Payment/RevenueCatManager.swift
// ============================
import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore

/// Client-side subscription state manager.
/// Lazily configures RevenueCat on first identify/restore to prevent early writes.
/// Defers ALL Firestore writes until we've explicitly identified with Firebase UID.
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    private override init() { super.init() }

    @Published var entitlementActive: Bool = false
    @Published var managementURL: URL?
    @Published var lastCustomerInfo: CustomerInfo?

    private let db = Firestore.firestore()
    private var activeCheckTimer: Timer?
    private var trialExpiryTimer: Timer?

    /// Gate: becomes true ONLY after `logIn(uid)` succeeds.
    private var isIdentified = false

    /// Track whether the SDK has been configured.
    private var isConfigured = false

    // MARK: - Lazy configure

    private func ensureConfigured() {
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: PaywallConfig.rcPublicSDKKey)
        Purchases.shared.delegate = self
        isConfigured = true

        // Periodic recompute (only acts when identified)
        scheduleActiveRecomputeTimer()
    }

    // MARK: - Identify (call this after user doc exists)
    func identifyIfPossible() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let docRef = db.collection("users").document(uid)
        docRef.getDocument { [weak self] snap, _ in
            guard
                let self,
                let phone = snap?.get("phoneE164") as? String,
                !phone.isEmpty
            else {
                return
            }

            self.ensureConfigured()
            Purchases.shared.logIn(uid) { [weak self] info, _, _ in
                guard let self else { return }
                self.isIdentified = true
                self.apply(info)
            }
        }
    }

    // MARK: - Restore

    func restore(completion: @escaping (Bool, String?) -> Void) {
        ensureConfigured()
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

        // 🔒 Hard gate: do nothing until we've explicitly identified.
        guard isIdentified else { return }

        // Safety: require identity match.
        guard let uid = Auth.auth().currentUser?.uid,
              Purchases.shared.appUserID == uid else { return }

        syncToFirestore(info: info, uid: uid)
    }

    /// Mirror essential RC state into Firestore and recompute `active` + `subscriptionStatus`.
    private func syncToFirestore(info: CustomerInfo, uid: String) {
        let ent = info.entitlements[PaywallConfig.entitlementId]

        let rcPayload: [String: Any?] = [
            "entitlementActive": ent?.isActive ?? false,
            "productId": ent?.productIdentifier,
            "expiresAt": ent?.expirationDate?.timeIntervalSince1970,
            "latestPurchaseAt": ent?.latestPurchaseDate?.timeIntervalSince1970,
            "store": "app_store",
            "lastSyncedAt": Date().timeIntervalSince1970
        ]

        let userRef = db.collection("users").document(uid)
        // Extra guard: only write if base doc exists (prevents creating doc from RC alone)
        userRef.getDocument { snap, _ in
            guard snap?.exists == true else { return }
            userRef.setData(["rc": rcPayload], merge: true) { _ in
                self.recomputeAndPersistActive(uid: uid, entitlement: ent?.isActive ?? false)
            }
        }
    }

    /// `active` = (Date() < trialEndsAt) || entitlementActive
    /// `subscriptionStatus` = "subscribed" if entitlementActive else "unsubscribed"
    func recomputeAndPersistActive(uid: String? = nil, entitlement: Bool? = nil) {
        let uidValue: String
        if let u = uid { uidValue = u }
        else if let u = Auth.auth().currentUser?.uid { uidValue = u }
        else { return }

        let docRef = db.collection("users").document(uidValue)
        docRef.getDocument { [weak self] snap, _ in
            guard let self else { return }
            guard let data = snap?.data() else {
                self.scheduleTrialExpiryTimer(trialEndsAt: nil)
                return
            }
            let ts = (data["trialEndsAt"] as? Timestamp)?.dateValue()
            let onTrial = ts.map { Date() < $0 } ?? false

            self.scheduleTrialExpiryTimer(trialEndsAt: ts)
            
            let entitled: Bool
            if let entitlement = entitlement {
                entitled = entitlement
            } else if
                let rc = data["rc"] as? [String: Any],
                let activeFromRC = rc["entitlementActive"] as? Bool {
                entitled = activeFromRC
            } else {
                entitled = false
            }

            // If neither trial nor entitlement is known/true yet, avoid writing a misleading `active`.
            if ts == nil && !entitled { return }

            let isActive = onTrial || entitled
            let subscriptionStatus = entitled ? "subscribed" : "unsubscribed"

            docRef.setData([
                "active": isActive,
                "subscriptionStatus": subscriptionStatus
            ], merge: true)
        }
    }

    private func scheduleActiveRecomputeTimer() {
        activeCheckTimer?.invalidate()
        activeCheckTimer = Timer.scheduledTimer(withTimeInterval: 60 * 10, repeats: true) { [weak self] _ in
            guard let self, self.isIdentified else { return }
            self.recomputeAndPersistActive()
        }
    }
    
    private func scheduleTrialExpiryTimer(trialEndsAt: Date?) {
        DispatchQueue.main.async {
            self.trialExpiryTimer?.invalidate()
            self.trialExpiryTimer = nil

            guard let trialEndsAt else { return }

            let interval = trialEndsAt.timeIntervalSinceNow
            guard interval > 0 else { return }

            self.trialExpiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.recomputeAndPersistActive()
            }
        }
    }
    
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        apply(customerInfo)
    }
}
