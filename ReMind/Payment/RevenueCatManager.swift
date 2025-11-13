// ============================
// File: ReMind/Payment/RevenueCatManager.swift
// ============================
import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore

/// Client-side subscription state manager.
/// - Lazily configures RevenueCat only when needed (identify/restore)
/// - Defers ALL Firestore writes until we've explicitly identified with Firebase UID
/// - Uses a one-shot timer to flip `active` exactly at trial end (no periodic heartbeat)
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    private override init() { super.init() }

    // UI-observable bits
    @Published var entitlementActive: Bool = false
    @Published var entitlementWillRenew: Bool = false
    @Published var entitlementExpirationDate: Date?
    @Published var managementURL: URL?
    @Published var lastCustomerInfo: CustomerInfo?

    // Infra
    private let db = Firestore.firestore()

    // Timers
    private var trialExpiryTimer: Timer?

    // Gates
    private var isIdentified = false        // true only after Purchases.logIn(uid) succeeds
    private var isConfigured = false        // true after Purchases.configure(...)

    // MARK: - Lazy configure

    private func ensureConfigured() {
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: PaywallConfig.rcPublicSDKKey)
        Purchases.shared.delegate = self
        isConfigured = true
        // NOTE: No periodic timer — only the trialExpiryTimer remains.
    }

    // MARK: - Identify (call this after user doc exists)

    /// Attempts to identify with RC, but only after confirming the Firestore user doc
    /// exists and has a non-empty `phoneE164` (prevents RC from being first writer).
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



        let entitlement = info.entitlements[PaywallConfig.entitlementId]

        let isActive = entitlement?.isActive == true
        let willRenew = entitlement?.willRenew ?? false
        let expirationDate = entitlement?.expirationDate

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastCustomerInfo = info
            self.managementURL = info.managementURL
            self.entitlementActive = isActive
            self.entitlementWillRenew = willRenew
            self.entitlementExpirationDate = expirationDate
        }

        // 🔒 Hard gates before any Firestore writes
        guard isIdentified else { return }
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

        // Don't let RC create the doc by itself.
        userRef.getDocument { snap, _ in
            guard snap?.exists == true else { return }
            userRef.setData(["rc": rcPayload], merge: true) { _ in
                self.recomputeAndPersistActive(uid: uid, entitlement: ent?.isActive ?? false)
            }
        }
    }

    /// `active` = (Date() < trialEndsAt) || entitlementActive
    /// `subscriptionStatus` = "subscribed" if entitlementActive else "unsubscribed"
    /// Also (re)schedules a one-shot timer to fire exactly at `trialEndsAt`.
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

            // Trial window
            let ts = (data["trialEndsAt"] as? Timestamp)?.dateValue()
            let onTrial = ts.map { Date() < $0 } ?? false

            // Always keep the one-shot timer aligned to the current trial end.
            self.scheduleTrialExpiryTimer(trialEndsAt: ts)

            // Determine entitlement
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

            // Derived fields
            let isActive = onTrial || entitled
            let subscriptionStatus = entitled ? "subscribed" : "unsubscribed"

            docRef.setData([
                "active": isActive,
                "subscriptionStatus": subscriptionStatus
            ], merge: true)
        }
    }

    // MARK: - One-shot timer for precise trial flip

    private func scheduleTrialExpiryTimer(trialEndsAt: Date?) {
        DispatchQueue.main.async {
            self.trialExpiryTimer?.invalidate()
            self.trialExpiryTimer = nil

            guard let trialEndsAt else { return }

            let interval = trialEndsAt.timeIntervalSinceNow
            guard interval > 0 else {
                // If it has already passed, recompute now to flip immediately.
                self.recomputeAndPersistActive()
                return
            }

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
