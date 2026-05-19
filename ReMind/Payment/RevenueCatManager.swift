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
    @Published var isCustomerInfoLoading: Bool = false
    @Published var lastRefreshError: String?
    @Published var identifiedAppUserID: String?
    @MainActor private var lastActiveRecomputeAt: Date? = nil
    private let activeRecomputeCooldownSec: TimeInterval = 10

    // MARK: - Infra

    private let db = Firestore.firestore()
    private var isConfigured = false
    private var trialExpiryTimer: Timer?
    private var identifyInFlight = false
    private var pendingIdentifyCompletions: [() -> Void] = []
    private var refreshInFlight = false
    private var lastRefreshStartedAt: Date?
    private let refreshCooldownSec: TimeInterval = 5

    // MARK: - Configuration

    private func ensureConfigured() {
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: PaywallConfig.rcPublicSDKKey)
        Purchases.shared.delegate = self
        isConfigured = true
        debugLog("configured RevenueCat")
    }

    // MARK: - Force identity

    func forceIdentify(reason: String = "manual", completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?()
            return
        }
        ensureConfigured()

        if identifiedAppUserID == uid {
            debugLog("identify skipped; already identified", uid: uid, reason: reason)
            completion?()
            return
        }

        if identifyInFlight {
            debugLog("identify skipped; already in flight", uid: uid, reason: reason)
            if let completion {
                pendingIdentifyCompletions.append(completion)
            }
            return
        }

        identifyInFlight = true
        DispatchQueue.main.async {
            self.isCustomerInfoLoading = true
            self.lastRefreshError = nil
        }
        debugLog("identify start", uid: uid, reason: reason)

        Purchases.shared.logIn(uid) { [weak self] info, _, error in
            guard let self else { return }
            self.identifyInFlight = false
            let completions = self.pendingIdentifyCompletions
            self.pendingIdentifyCompletions = []
            if let error {
                self.applyRefreshError(error, context: "logIn", uid: uid, reason: reason)
                completion?()
                completions.forEach { $0() }
                return
            }
            DispatchQueue.main.async {
                self.identifiedAppUserID = uid
            }
            if let info { self.apply(info) }
            self.debugLog("identify complete", uid: uid, reason: reason)
            completion?()
            completions.forEach { $0() }
        }
    }

    // MARK: - Refresh

    func refreshEntitlementState(reason: String = "manual", force: Bool = false) {
        ensureConfigured()
        if refreshInFlight {
            debugLog("refresh skipped; already in flight", uid: Auth.auth().currentUser?.uid, reason: reason)
            return
        }
        if !force,
           let lastRefreshStartedAt,
           Date().timeIntervalSince(lastRefreshStartedAt) < refreshCooldownSec {
            debugLog("refresh skipped; cooldown", uid: Auth.auth().currentUser?.uid, reason: reason)
            return
        }

        refreshInFlight = true
        lastRefreshStartedAt = Date()
        DispatchQueue.main.async {
            self.isCustomerInfoLoading = true
            self.lastRefreshError = nil
        }
        debugLog("refresh start", uid: Auth.auth().currentUser?.uid, reason: reason)

        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self else { return }
            self.refreshInFlight = false
            if let info {
                self.apply(info)
            } else if let error {
                self.applyRefreshError(error, context: "getCustomerInfo", uid: Auth.auth().currentUser?.uid, reason: reason)
            }
        }
    }

    func clearForLogout() {
        DispatchQueue.main.async {
            self.entitlementActive = false
            self.entitlementWillRenew = false
            self.entitlementExpirationDate = nil
            self.managementURL = nil
            self.lastCustomerInfo = nil
            self.lastRefreshError = nil
            self.isCustomerInfoLoading = false
            self.identifiedAppUserID = nil
        }
        ensureConfigured()
        Purchases.shared.logOut { [weak self] _, error in
            if let error {
                self?.debugLog("logOut error: \(error.localizedDescription)")
            } else {
                self?.debugLog("logOut complete")
            }
        }
    }

    // MARK: - Apply RC snapshot

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[PaywallConfig.entitlementId]

        DispatchQueue.main.async {
            self.entitlementActive = entitlement?.isActive == true
            self.entitlementWillRenew = entitlement?.willRenew ?? false
            self.entitlementExpirationDate = entitlement?.expirationDate
            self.managementURL = info.managementURL
            self.isCustomerInfoLoading = false
            self.lastRefreshError = nil
            self.lastCustomerInfo = info
        }
        debugLog(
            "apply customerInfo entitlementActive=\(entitlement?.isActive == true) willRenew=\(entitlement?.willRenew ?? false) expiresAt=\(entitlement?.expirationDate?.description ?? "nil")",
            uid: Auth.auth().currentUser?.uid
        )

        guard let uid = Auth.auth().currentUser?.uid else { return }
        syncToFirestore(info: info, uid: uid)
    }

    // MARK: - Firestore sync

    private func syncToFirestore(info: CustomerInfo, uid: String) {
        debugLog("skipping client Firestore entitlement mirror; RevenueCat webhook is authoritative", uid: uid)
    }

    // MARK: - Derived state

    @MainActor private var _recomputeActiveInFlight = false

    @MainActor
    func recomputeAndPersistActive(uid: String? = nil, entitlement: Bool? = nil) {
        debugLog("skipping client plan/active recompute; server-owned fields are webhook controlled", uid: uid ?? Auth.auth().currentUser?.uid)
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
            if let trialEndsAt { scheduleTrialExpiryTimer(trialEndsAt: trialEndsAt) }

            let rc = data["rc"] as? [String: Any] ?? [:]
            let entitled = entitlement ?? (rc["entitlementActive"] as? Bool ?? false)
            let willRenew = rc["willRenew"] as? Bool ?? false
            let expiresAt = dateFromFirestoreValue(rc["expiresAt"])

            let now = Date()
            let inPaidPeriod = entitled && ((expiresAt ?? now) >= now)
            // plan is the tier source of truth; active remains operational for scheduler/STOP compatibility.
            let isActive = (data["smsOptOut"] as? Bool == true) ? false : true
            let plan: String = inPaidPeriod ? UserPlan.pro.rawValue : UserPlan.free.rawValue

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
            let existingPlan = current.get("plan") as? String

            // Idempotent guard — prevents write spam
            guard existingActive != isActive || existingStatus != status || existingPlan != plan else {
                return
            }

            try await docRef.setData(
                [
                    "active": isActive,
                    "subscriptionStatus": status,
                    "plan": plan
                ],
                merge: true
            )



        } catch {
            print("❌ recomputeAndPersistActive error:", error.localizedDescription)
        }
    }

    private func stableRCMirror(from ent: EntitlementInfo?) -> [String: Any] {
        var rcStable: [String: Any] = [
            "entitlementActive": ent?.isActive ?? false,
            "willRenew": ent?.willRenew ?? false,
            "store": "app_store"
        ]

        rcStable["productId"] = ent?.productIdentifier ?? NSNull()
        if let expirationDate = ent?.expirationDate {
            rcStable["expiresAt"] = Timestamp(date: expirationDate)
        } else {
            rcStable["expiresAt"] = NSNull()
        }

        if let latestPurchaseDate = ent?.latestPurchaseDate {
            rcStable["latestPurchaseAt"] = Timestamp(date: latestPurchaseDate)
        } else {
            rcStable["latestPurchaseAt"] = NSNull()
        }

        return rcStable
    }

    private func comparableRCMirror(from rc: [String: Any]) -> [String: Any] {
        [
            "entitlementActive": rc["entitlementActive"] ?? NSNull(),
            "willRenew": rc["willRenew"] ?? NSNull(),
            "store": rc["store"] ?? NSNull(),
            "productId": rc["productId"] ?? NSNull(),
            "expiresAt": rc["expiresAt"] ?? NSNull(),
            "latestPurchaseAt": rc["latestPurchaseAt"] ?? NSNull()
        ]
    }

    private func dateFromFirestoreValue(_ raw: Any?) -> Date? {
        if let timestamp = raw as? Timestamp { return timestamp.dateValue() }
        if let date = raw as? Date { return date }
        if let number = raw as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let string = raw as? String, let seconds = TimeInterval(string) {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    private func applyRefreshError(_ error: Error, context: String, uid: String?, reason: String) {
        DispatchQueue.main.async {
            self.isCustomerInfoLoading = false
            self.lastRefreshError = error.localizedDescription
        }
        debugLog("\(context) error: \(error.localizedDescription)", uid: uid, reason: reason)
    }

    private func debugLog(_ message: String, uid: String? = nil, reason: String? = nil) {
#if DEBUG
        let uidPart = uid.map { " uid=\($0)" } ?? ""
        let reasonPart = reason.map { " reason=\($0)" } ?? ""
        print("🔐 [Subscription][RC]\(uidPart)\(reasonPart) \(message)")
#endif
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
                Task { @MainActor [weak self] in
                    self?.recomputeAndPersistActive()
                }
            }
        }
    }
    
    //restore
    func restore(completion: @escaping (_ success: Bool, _ errorMessage: String?) -> Void) {
        ensureConfigured()

        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, "Please sign in to restore purchases.")
            return
        }

        Purchases.shared.logIn(uid) { [weak self] info, _, error in
            guard let self else { return }

            if let error {
                completion(false, "Unable to sign in: \(error.localizedDescription)")
                return
            }

            if let info {
                self.apply(info)
            }

            Purchases.shared.restorePurchases { customerInfo, error in
                if let error {
                    completion(false, error.localizedDescription)
                    return
                }

                guard let info = customerInfo else {
                    completion(false, "Nothing to restore.")
                    return
                }

                // Apply and mirror the restored RevenueCat snapshot.
                self.apply(info)

                completion(true, nil)
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
