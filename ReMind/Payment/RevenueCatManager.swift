// ============================
// File: ReMind/Payment/RevenueCatManager.swift
// ============================
import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore



/// Client-side subscription state manager.
/// - Forces RC identity BEFORE purchase
/// - Always syncs RC → Firestore on CustomerInfo updates
/// - Avoids state deadlocks caused by identity gating
final class RevenueCatManager: NSObject, ObservableObject {

    static let shared = RevenueCatManager()
    private override init() { super.init() }

    // MARK: - UI-observable state

    @Published var entitlementActive: Bool = false
    @Published var entitlementWillRenew: Bool = false
    @Published var entitlementExpirationDate: Date?
    @Published var managementURL: URL?
    @Published var lastCustomerInfo: CustomerInfo?

    // MARK: - Infra

    private let db = Firestore.firestore()
    private var isConfigured = false
    private var trialExpiryTimer: Timer?

    // MARK: - Configuration

    private func ensureConfigured() {
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: PaywallConfig.rcPublicSDKKey)
        Purchases.shared.delegate = self
        isConfigured = true
    }

    // MARK: - 🔑 Force identity BEFORE purchase

    /// Call this before showing PaywallView
    func forceIdentify(completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        ensureConfigured()

        Purchases.shared.logIn(uid) { [weak self] info, _, error in
            guard let self else { return }

            if let error {
                print("❌ RevenueCat logIn failed:", error.localizedDescription)
                return
            }

            print("✅ RevenueCat appUserID:", Purchases.shared.appUserID)

            if let info {
                self.apply(info)
            }

            completion?()
        }
    }

    // MARK: - Restore

    func restore(completion: @escaping (Bool, String?) -> Void) {
        ensureConfigured()
        forceIdentify()

        Purchases.shared.restorePurchases { [weak self] info, err in
            guard let self else { return }

            if let err {
                completion(false, err.localizedDescription)
                return
            }

            if let info { self.apply(info) }

            let active = info?.entitlements[PaywallConfig.entitlementId]?.isActive == true
            completion(active, nil)
        }
    }

    // MARK: - Refresh

    func refreshEntitlementState() {
        ensureConfigured()

        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self else { return }

            if let info {
                self.apply(info)
            } else if let error {
                print("⚠️ RevenueCat refresh error:", error.localizedDescription)
            }
        }
    }

    // MARK: - Apply RC snapshot (🔥 critical path)

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[PaywallConfig.entitlementId]

        let isActive = entitlement?.isActive == true
        let willRenew = entitlement?.willRenew ?? false
        let expirationDate = entitlement?.expirationDate

        print(
            "🧾 RC snapshot:",
            "active=\(isActive)",
            "willRenew=\(willRenew)",
            "expires=\(String(describing: expirationDate))",
            "product=\(String(describing: entitlement?.productIdentifier))"
        )

        DispatchQueue.main.async {
            self.lastCustomerInfo = info
            self.managementURL = info.managementURL
            self.entitlementActive = isActive
            self.entitlementWillRenew = willRenew
            self.entitlementExpirationDate = expirationDate
        }

        // 🔥 DO NOT GATE THIS — always sync when RC updates
        guard let uid = Auth.auth().currentUser?.uid else { return }

        syncToFirestore(info: info, uid: uid)
    }

    // MARK: - Firestore sync

    private func syncToFirestore(info: CustomerInfo, uid: String) {
        let ent = info.entitlements[PaywallConfig.entitlementId]

        let rcPayload: [String: Any?] = [
            "entitlementActive": ent?.isActive ?? false,
            "willRenew": ent?.willRenew ?? false,
            "productId": ent?.productIdentifier,
            "expiresAt": ent?.expirationDate?.timeIntervalSince1970,
            "latestPurchaseAt": ent?.latestPurchaseDate?.timeIntervalSince1970,
            "store": "app_store",
            "lastSyncedAt": Date().timeIntervalSince1970
        ]

        let userRef = db.collection("users").document(uid)

        userRef.getDocument { snap, _ in
            guard snap?.exists == true else { return }

            userRef.setData(["rc": rcPayload], merge: true) { _ in
                self.recomputeAndPersistActive(
                    uid: uid,
                    entitlement: ent?.isActive ?? false
                )
            }
        }
    }

    // MARK: - Derived state

    func recomputeAndPersistActive(uid: String? = nil, entitlement: Bool? = nil) {
        let uidValue = uid ?? Auth.auth().currentUser?.uid
        guard let uidValue else { return }

        let docRef = db.collection("users").document(uidValue)

        docRef.getDocument { [weak self] snap, _ in
            guard let self,
                  let data = snap?.data()
            else { return }

            let trialEndsAt = (data["trialEndsAt"] as? Timestamp)?.dateValue()
            let onTrial = trialEndsAt.map { Date() < $0 } ?? false

            self.scheduleTrialExpiryTimer(trialEndsAt: trialEndsAt)

            let rc = data["rc"] as? [String: Any] ?? [:]
            let entitled = entitlement ?? (rc["entitlementActive"] as? Bool ?? false)
            let willRenew = rc["willRenew"] as? Bool ?? false
            let expiresAt = (rc["expiresAt"] as? TimeInterval)
                .map { Date(timeIntervalSince1970: $0) }

            let now = Date()
            let inPaidPeriod = entitled && ((expiresAt ?? now) >= now)
            let isActive = onTrial || inPaidPeriod

            let status: String
            if inPaidPeriod && willRenew {
                status = "subscribed"
            } else if inPaidPeriod {
                status = "cancelled"
            } else {
                status = "unsubscribed"
            }

            
            let existingActive = data["active"] as? Bool
            let existingStatus = data["subscriptionStatus"] as? String

            // Avoid spamming writes when nothing changed (e.g., Settings onAppear)
            guard existingActive != isActive || existingStatus != status else { return }
            
            docRef.setData([
                "active": isActive,
                "subscriptionStatus": status
            ], merge: true)
        }
    }

    // MARK: - Trial timer

    private func scheduleTrialExpiryTimer(trialEndsAt: Date?) {
        DispatchQueue.main.async {
            self.trialExpiryTimer?.invalidate()
            self.trialExpiryTimer = nil

            guard let trialEndsAt else { return }

            let interval = trialEndsAt.timeIntervalSinceNow
            guard interval > 0 else {
                self.recomputeAndPersistActive()
                return
            }

            self.trialExpiryTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false
            ) { [weak self] _ in
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
