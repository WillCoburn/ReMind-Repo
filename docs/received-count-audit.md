# Received Count Audit

## Current Pipeline Findings

### Data storage
- Cloud Functions increment `users/{uid}.receivedCount` whenever messages are delivered via the scheduler, one-off sends, or PDF export links, using an atomic `FieldValue.increment(1)` write with merge semantics.【F:functions/src/config/options.ts†L236-L242】【F:functions/src/scheduler/minuteCron.ts†L154-L187】【F:functions/src/user/sendOneNow.ts†L84-L121】【F:functions/src/exports/sendExportLink.ts†L118-L157】
- There is no evidence of server-side recomputation or reset; increments are append-only and run only on send paths.

### Local state & fetch/sync flow
- `UserProfile` stores `receivedCount` as an optional and no longer defaults the value to zero; it reflects whatever Firestore provides.【F:ReMind/Models/UserProfile.swift†L8-L36】
- The initial load path now reads `receivedCount` from the user document (handling `NSNumber` as well) and seeds the in-memory profile with the server value instead of a default.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L25-L73】
- The real-time user listener is attached after initial load and mirrors `receivedCount` from snapshots without defaulting to zero, falling back to the last known value only if the field is absent in the snapshot.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L76-L79】【F:ReMind/ViewModels/AppViewModel/AppViewModel+RealTimeUserListener.swift†L10-L36】
- Entry syncing is separate and unrelated; `sentEntriesCount` is computed locally from fetched entries and is not guaranteed to match the canonical `receivedCount`.【F:ReMind/ViewModels/AppViewModel/AppViewModel+Entries.swift†L9-L48】

### UI flow
- The “Received” tile binds directly to `appVM.user?.receivedCount ?? 0`, eliminating fallbacks to derived entry counts and keeping the UI aligned to Firestore truth.【F:ReMind/Views/RightPanel/RightPanelPlaceholderView.swift†L360-L386】

## Diagnosis: Why did the received count reset to zero on reinstall?
1. The initial load previously ignored `receivedCount`, leaving the local model at its initializer default of zero rather than the Firestore value.
2. The real-time Firestore listener was commented out during initial load, so no snapshot ever updated the local value after launch.
3. The UI hid the problem by falling back to a locally derived `sentEntriesCount` when the user model was missing data.

Together, those behaviors meant a reinstall or new device rebuilt state from local defaults instead of Firestore, making the received count appear to reset even though the server value never changed.

## Fix implemented
- Initial load now reads `receivedCount` from Firestore and seeds `UserProfile` with the server value, treating missing data as `nil` instead of zero.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L25-L73】【F:ReMind/Models/UserProfile.swift†L8-L36】
- The Firestore snapshot listener is re-attached after initial load and mirrors `receivedCount` without zero defaults, preserving the server’s authoritative value across sessions.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L76-L79】【F:ReMind/ViewModels/AppViewModel/AppViewModel+RealTimeUserListener.swift†L10-L36】
- UI binding now reads only `appVM.user?.receivedCount ?? 0`, removing derivations from entry counts so the on-screen value always reflects Firestore.【F:ReMind/Views/RightPanel/RightPanelPlaceholderView.swift†L360-L386】

## Recommended Canonical Model
- **Single source of truth:** `users/{uid}.receivedCount` in Firestore is authoritative; the app must only mirror it locally for display.
- **Read path:** Always load `receivedCount` from Firestore during initial fetch and via a real-time snapshot listener so late-arriving updates are applied.
- **Write path:** Continue using existing server-side atomic increments on delivery; the client must never derive or recompute the count from entries.
- **Local defaults:** Treat missing `receivedCount` as `nil` and surface `0` only as a presentation default to avoid overwriting server data.

## Implementation Plan
1. **Initial load:** Ensure `loadUserAndEntries` reads `receivedCount` from the user document and populates `UserProfile` accordingly (nil-safe handling, no default-to-zero writes).【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L11-L104】
2. **Real-time sync:** Keep `attachUserListener` active after initial fetch, ensuring the listener maps `receivedCount` from snapshots without defaulting to zero so Firestore remains authoritative.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L101-L103】【F:ReMind/ViewModels/AppViewModel/AppViewModel+RealTimeUserListener.swift†L10-L36】
3. **User model defaults:** Keep `receivedCount` optional and only presentationally default to zero to avoid silently overwriting missing server values during initialization.【F:ReMind/Models/UserProfile.swift†L8-L36】
4. **UI binding:** Keep the “Received” tile bound directly to `appVM.user?.receivedCount ?? 0` so the UI reflects Firestore and does not derive from entries.【F:ReMind/Views/RightPanel/RightPanelPlaceholderView.swift†L360-L386】
5. **Resilience:** Guard against nil/missing `receivedCount` by interpreting `nil` as `0` only for display, never writing zeros back to Firestore unless explicitly intended (no recomputation from entries).
6. **Testing:** Verify scenarios—fresh install, re-install, sign-out/in, multi-device login, and live receipt—ensure snapshots update the UI without resets.
