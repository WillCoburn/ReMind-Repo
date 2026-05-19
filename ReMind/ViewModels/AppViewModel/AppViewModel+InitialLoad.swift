// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
extension AppViewModel {
    // MARK: - Initial load
    func loadUserAndEntries(_ uid: String?) async {
        guard let uid = uid else {
            detachUserListener()
            detachEntriesListener()
            self.user = nil
            self.entries = []
            self.applyLatestSentReminder(nil)
            self.smsOptOut = false
            self.isGodModeUser = false
            self.hasSeenFeatureTour = false
            self.featureTourStep = .settings
            self.showFeatureTour = false
            self.resetSubscriptionStateForAuthChange()
            self.hasLoadedInitialProfile = true
            return
        }

        hasLoadedInitialProfile = false
        applyLatestSentReminder(nil)
        defer { hasLoadedInitialProfile = true }

        
        // One-time fetch so UI has something immediately
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let serverRead = (snap.get("updatedAt") as? Timestamp
                            ?? snap.get("createdAt") as? Timestamp)?.dateValue()
                        updateServerTime(readAt: serverRead)

            // Base identity
            let phone = snap.get("phoneE164") as? String ?? ""

            // Optional timestamps
            let createdAtTS = snap.get("createdAt") as? Timestamp
            let updatedAtTS = snap.get("updatedAt") as? Timestamp
            let trialEndsAtTS = snap.get("trialEndsAt") as? Timestamp
            let planRaw = (snap.get("plan") as? String)?.lowercased()
            // Plan is server-owned. Missing legacy plan fields are treated as
            // free in the client until the backend entitlement mirror fills in.
            let plan = UserPlan(rawValue: planRaw ?? "")
            let subscriptionStatus = snap.get("subscriptionStatus") as? String
            let rcEntitlementActive = snap.get("rc.entitlementActive") as? Bool
            let rcExpiresAt = parseFirestoreDate(snap.get("rc.expiresAt"))

            // Active flag (backend gating)
            let active = snap.get("active") as? Bool

            // Counts and activity
            let receivedCount: Int?
            if let value = snap.get("receivedCount") as? Int {
                receivedCount = value
            } else if let number = snap.get("receivedCount") as? NSNumber {
                receivedCount = number.intValue
            } else {
                receivedCount = nil
            }

            let usageRaw = snap.get("usage") as? [String: Any]
            let instantUsage = InstantUsage(
                instantWeekKey: usageRaw?["instantWeekKey"] as? String,
                instantSendsThisWeek: (usageRaw?["instantSendsThisWeek"] as? Int)
                    ?? (usageRaw?["instantSendsThisWeek"] as? NSNumber)?.intValue
                    ?? 0
            )
            let lastReminder = parseLastReminder(from: snap.data() ?? [:])

            // Build model
            let profile = UserProfile(
                uid: uid,
                phoneE164: phone,
                createdAt: createdAtTS?.dateValue(),
                updatedAt: updatedAtTS?.dateValue(),
                trialEndsAt: trialEndsAtTS?.dateValue(),
                active: active,
                plan: plan,
                subscriptionStatus: subscriptionStatus,
                rcEntitlementActive: rcEntitlementActive,
                rcExpiresAt: rcExpiresAt,
                receivedCount: receivedCount,
                usage: instantUsage,
                lastReminder: lastReminder
            )

            self.user = profile
            applyLatestSentReminder(lastReminder)
            refreshEntitlementState()


            // Ancillary flags
            self.smsOptOut = snap.get("smsOptOut") as? Bool ?? false
            let hasSeenTour = snap.get("hasSeenFeatureTour") as? Bool ?? false
            applyFeatureTourFlag(hasSeenTour)
        } catch {
            print("❌ load user error:", error.localizedDescription)
            if self.user == nil { self.user = UserProfile(uid: uid, phoneE164: "") }
            self.smsOptOut = false
            applyFeatureTourFlag(false)
        }

        await fetchAndApplyUserSettings(uid: uid)

        attachUserListener(uid)
        attachEntriesListener(uid)

        refreshRevenueCatEntitlement(reason: "loadUserAndEntries")

        await refreshAll()
        await refreshLatestSentReminder()
    }

    // MARK: - User settings
    private func fetchAndApplyUserSettings(uid: String) async {
        do {
            let settingsSnap = try await db.collection("users")
                .document(uid)
                .collection("meta")
                .document("settings")
                .getDocument()

            guard settingsSnap.exists else { return }

            let defaults = UserDefaults.standard

            if let weekly = settingsSnap.get("remindersPerWeek") as? Double {
                let clampedWeekly = min(
                    max(weekly, SubscriptionLimits.minRemindersPerWeek),
                    maxRemindersPerWeekForCurrentSubscription
                )
                defaults.set(clampedWeekly, forKey: "remindersPerWeek")
            }

            if let tzIdentifier = settingsSnap.get("tzIdentifier") as? String {
                defaults.set(tzIdentifier, forKey: "tzIdentifier")
            }

            func clampHour(_ raw: Any?) -> Double? {
                if let value = raw as? Double { return max(0, min(24, value)) }
                if let value = raw as? Int { return max(0, min(24, Double(value))) }
                return nil
            }

            if let start = clampHour(settingsSnap.get("quietStartHour")) {
                defaults.set(start, forKey: "quietStartHour")
            }

            if let end = clampHour(settingsSnap.get("quietEndHour")) {
                defaults.set(end, forKey: "quietEndHour")
            }
        } catch {
            print("⚠️ fetchAndApplyUserSettings error:", error.localizedDescription)
        }
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
}
