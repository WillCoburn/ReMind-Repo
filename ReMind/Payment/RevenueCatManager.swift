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

        // IMPORTANT: do NOT include changing timestamps in the comparison payload
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

                // Compare existing rc (ignoring lastSyncedAt)
                let existingRC = (data["rc"] as? [String: Any]) ?? [:]
                var existingStable = existingRC
                existingStable.removeValue(forKey: "lastSyncedAt")

                // If nothing changed, do nothing (prevents spam)
                guard NSDictionary(dictionary: existingStable).isEqual(to: rcStable) == false else {
                    return
                }

                // Write rc + a timestamp ONLY when rc actually changed
                
                
                try await userRef.setData([
                    
                    
                    "rc": rcStable.merging(["lastSyncedAt": Date().timeIntervalSince1970]) { _, new in new }
                ], merge: true)

                await self._recomputeAndPersistActiveAsync(uid: uid, entitlement: ent?.isActive ?? false)

            } catch {
                print("⚠️ syncToFirestore error:", error.localizedDescription)
            }
        }
    }


    // MARK: - Derived state

    // Drop-in replacement (same name/params) — no callbacks, no detaching, no cancellation.
    // Requires: import FirebaseAuth, import FirebaseFirestore

    @MainActor
    private var _recomputeActiveInFlight = false

    @MainActor
    func recomputeAndPersistActive(uid: String? = nil, entitlement: Bool? = nil) {
        let now = Date()
        if let last = lastActiveRecomputeAt, now.timeIntervalSince(last) < activeRecomputeCooldownSec {
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
            // Read once to compute derived state
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

            // Transaction = idempotent write (stops spam)
            _ = try await db.runTransaction { txn, errorPtr in
                do {
                    let current = try txn.getDocument(docRef)
                    let existingActive = current.get("active") as? Bool
                    let existingStatus = current.get("subscriptionStatus") as? String

                    guard existingActive != isActive || existingStatus != status else {
                        return nil
                    }

                    txn.setData(
                        [
                            "active": isActive,
                            "subscriptionStatus": status
                        ],
                        forDocument: docRef,
                        merge: true
                    )

                    return nil
                } catch {
                    errorPtr?.pointee = error as NSError
                    return nil
                }
            }

        } catch {
            print("❌ recomputeAndPersistActive error:", error.localizedDescription)
        }
    }




    // MARK: - Trial timer

    // MARK: - Trial timer
    @MainActor
    private var lastScheduledTrialEndsAt: Date? = nil

    private func scheduleTrialExpiryTimer(trialEndsAt: Date?) {
        DispatchQueue.main.async {
            self.trialExpiryTimer?.invalidate()
            self.trialExpiryTimer = nil

            guard let trialEndsAt else { return }

            // ✅ If we've already scheduled for this exact trial end, don't reschedule.
            if let last = self.lastScheduledTrialEndsAt, last == trialEndsAt { return }
            self.lastScheduledTrialEndsAt = trialEndsAt

            let interval = trialEndsAt.timeIntervalSinceNow

            // ✅ IMPORTANT: If trial already expired, DO NOT call recompute here.
            // Calling recompute here causes an infinite loop (recompute -> schedule -> recompute -> ...).
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
