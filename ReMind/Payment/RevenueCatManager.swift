// ============================
// File: ReMind/Payment/RevenueCatManager.swift
// ============================
import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore

final class RevenueCatManager: NSObject, ObservableObject {

    static let shared = RevenueCatManager()
    private override init() { super.init() }

    // MARK: - UI-observable state

    @Published var entitlementActive: Bool = false
    @Published var entitlementWillRenew: Bool = false
    @Published var entitlementExpirationDate: Date?
    @Published var managementURL: URL?
    @Published var lastCustomerInfo: CustomerInfo?
    @MainActor private var lastActiveRecomputeAt: Date? = nil
    private let activeRecomputeCooldownSec: TimeInterval = 10

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

    // MARK: - Force identity

    func forceIdentify(completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        ensureConfigured()

        Purchases.shared.logIn(uid) { [weak self] info, _, error in
            guard let self else { return }
            if let error {
                print("❌ RevenueCat logIn failed:", error.localizedDescription)
                return
            }
            if let info { self.apply(info) }
            completion?()
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

    // MARK: - Apply RC snapshot

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[PaywallConfig.entitlementId]

        DispatchQueue.main.async {
            self.lastCustomerInfo = info
            self.managementURL = info.managementURL
            self.entitlementActive = entitlement?.isActive == true
            self.entitlementWillRenew = entitlement?.willRenew ?? false
            self.entitlementExpirationDate = entitlement?.expirationDate
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        syncToFirestore(info: info, uid: uid)
    }

    // MARK: - Firestore sync

    private func syncToFirestore(info: CustomerInfo, uid: String) {
        let ent = info.entitlements[PaywallConfig.entitlementId]

        let rcStable: [String: Any] = [
            "entitlementActive": ent?.isActive ?? false,
            "willRenew": ent?.willRenew ?? false,
            "productId": ent?.productIdentifier as Any,
            "expiresAt": ent?.expirationDate?.timeIntervalSince1970 as Any,
            "latestPurchaseAt": ent?.latestPurchaseDate?.timeIntervalSince1970 as Any,
            "store": "app_store"
        ]

        let userRef = db.collection("users").document(uid)

        Task { [weak self] in
            guard let self else { return }
            do {
                let snap = try await userRef.getDocument()
                guard snap.exists, let data = snap.data() else { return }

                let existingRC = (data["rc"] as? [String: Any]) ?? [:]
                var existingStable = existingRC
                existingStable.removeValue(forKey: "lastSyncedAt")

                guard NSDictionary(dictionary: existingStable).isEqual(to: rcStable) == false else {
                    return
                }

                
                try await userRef.setData(
                    ["rc": rcStable.merging(["lastSyncedAt": Date().timeIntervalSince1970]) { _, new in new }],
                    merge: true
                )
               

                await self._recomputeAndPersistActiveAsync(
                    uid: uid,
                    entitlement: ent?.isActive ?? false
                )

            } catch {
                print("⚠️ syncToFirestore error:", error.localizedDescription)
            }
        }
    }

    // MARK: - Derived state

    @MainActor private var _recomputeActiveInFlight = false

    @MainActor
    func recomputeAndPersistActive(uid: String? = nil, entitlement: Bool? = nil) {
        let now = Date()
        if let last = lastActiveRecomputeAt,
           now.timeIntervalSince(last) < activeRecomputeCooldownSec {
            return
        }
        lastActiveRecomputeAt = now

        Task { [weak self] in
            await self?._recomputeAndPersistActiveAsync(uid: uid, entitlement: entitlement)
        }
    }

    @MainActor
    private func _recomputeAndPersistActiveAsync(
        uid: String? = nil,
        entitlement: Bool? = nil
    ) async {
        guard !_recomputeActiveInFlight else { return }
        _recomputeActiveInFlight = true
        defer { _recomputeActiveInFlight = false }

        let uidValue = uid ?? Auth.auth().currentUser?.uid
        guard let uidValue else { return }

        let docRef = db.collection("users").document(uidValue)

        do {
            let snap = try await docRef.getDocument()
            guard let data = snap.data() else { return }

            let trialEndsAt = (data["trialEndsAt"] as? Timestamp)?.dateValue()
            let onTrial = trialEndsAt.map { Date() < $0 } ?? false

            if let trialEndsAt {
                scheduleTrialExpiryTimer(trialEndsAt: trialEndsAt)
            }

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

            
            
            let current = try await docRef.getDocument()

            let existingActive = current.get("active") as? Bool
            let existingStatus = current.get("subscriptionStatus") as? String

            // Idempotent guard — prevents write spam
            guard existingActive != isActive || existingStatus != status else {
                return
            }

            try await docRef.setData(
                [
                    "active": isActive,
                    "subscriptionStatus": status
                ],
                merge: true
            )



        } catch {
            print("❌ recomputeAndPersistActive error:", error.localizedDescription)
        }
    }

    // MARK: - Trial timer

    @MainActor private var lastScheduledTrialEndsAt: Date? = nil

    private func scheduleTrialExpiryTimer(trialEndsAt: Date?) {
        DispatchQueue.main.async {
            self.trialExpiryTimer?.invalidate()
            self.trialExpiryTimer = nil

            guard let trialEndsAt else { return }
            if let last = self.lastScheduledTrialEndsAt, last == trialEndsAt { return }
            self.lastScheduledTrialEndsAt = trialEndsAt

            let interval = trialEndsAt.timeIntervalSinceNow
            guard interval > 0 else { return }

            self.trialExpiryTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false
            ) { [weak self] _ in
                self?.recomputeAndPersistActive()
            }
        }
    }
    
    //restore
    func restore(completion: @escaping (_ success: Bool, _ errorMessage: String?) -> Void) {
        Purchases.shared.restorePurchases { customerInfo, error in
            if let error {
                completion(false, error.localizedDescription)
                return
            }

            guard let info = customerInfo else {
                completion(false, "Nothing to restore.")
                return
            }

            // Update local entitlement state ONLY (no Firestore writes)
            self.apply(info)

            completion(true, nil)
        }
    }

}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        apply(customerInfo)
    }
}


