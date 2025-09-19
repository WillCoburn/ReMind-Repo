// ============================
// File: Services/FirebasePing.swift
// ============================
import FirebaseFirestore

enum FirebasePing {
    static func writeHello() {
        let db = Firestore.firestore()
        db.collection("diagnostics").document("ping").setData([
            "msg": "hello from iOS",
            "ts": Date()
        ]) { error in
            if let error = error {
                print("❌ Firestore write failed: \(error.localizedDescription)")
            } else {
                print("✅ Firestore write OK")
            }
        }
    }
}
