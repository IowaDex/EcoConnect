# Eco Connect — Implementation Report

**Date:** 2026-11-14
**Project:** `ecoconnect-ecaf8` (Flutter 3.x + Firebase Auth + Cloud Firestore)
**Scope:** Extend the existing Eco Connect application with the role, workflow and UI requirements in the project brief, without replacing working modules.

---

## 1. Approach

The existing source was audited before any change: 161 Dart files (~43.6k lines), the Firestore rules, the auth/session model, every role dashboard, and the existing services. Most of the operational backbone already existed and was **kept intact**:

- Trip tickets with a three-signature chain (driver → barangay → Iswim → City Hall).
- Delay reports, memos/endorsements and the email log.
- Wave 1 / Wave 2 collection requests, waste upload + validation, events, announcements.
- GPS truck tracking with a 100 m radius + hysteresis guard and connection-state handling.
- Single-session enforcement and deleted-user tombstones.

Work was limited to the genuine gaps: manuals, direct complaints, shared City Hall replies, the ticket audit trail and revision/rejection states, a real points ledger, and the resident registration decision.

---

## 2. Features implemented

### 2.1 ISWIM Manual Management (new)
| Requirement | Implementation |
|---|---|
| Manuals with categories, current file, version history | `manuals/{id}` + `manuals/{id}/versions/{vN}`; version bump is transactional |
| Manual updates go straight to City Hall | City Hall desk channel notification on publish and on new manual |
| City Hall acknowledges receipt | `acknowledge()` → `acknowledgedBy/At`, version status `acknowledged` |
| City Hall requests a manual from Iswim | `manual_requests` with `MR-YYYY-NNNN` counter, fulfilled / cancelled |
| Notifications for every step | Iswim desk + City Hall desk channels |

Screens: `manuals_screen`, `manual_detail_screen`, `manual_requests_screen`.

### 2.2 Resident complaints to DSQC (new)
- Separate request type from incidents and from collection requests (`complaints` collection, `CMP-YYYY-NNNNNN`).
- Resident picks a category, description, location and up to 3 photos.
- City Hall / DSQC desk lists open complaints, searches, replies, sets status.
- The thread is private to the complainant and City Hall; barangay staff cannot read it.
- Resident sees status changes and replies in **My complaints**.

### 2.3 Trip ticket workflow hardening
- Added statuses `revisionRequired` and `rejected`, relabelled the chain to the brief's vocabulary (Issued by Iswim → Received by driver → In progress → Awaiting barangay verification → Barangay approved → Iswim verified → Completed).
- **Audit trail**: every transition appends `{status, previousStatus, byUid, byName, note, at}` to `history`; rendered as a timeline on the ticket detail screen.
- Barangay can **return for revision** (reason required) and **reject**; Iswim can **reject after barangay approval**; the driver can **resubmit** a corrected ticket.
- The status guard is unchanged: each hop can only be advanced by the role that owns it, and the rules reject writes that skip a step.

### 2.4 Shared City Hall responses on resident requests
- City Hall can reply to any collection request; the reply is appended to `responses` and is visible to **both** the requesting resident and the barangay staff.
- The composer states explicitly that the barangay will see the reply.
- Wave 2 pass-through now notifies City Hall; the City Hall decision notifies the resident.

### 2.5 Waste validation → reward points ledger
- `validate()` is now transactional: it refuses an already-validated submission, writes `points_transactions/waste_{submissionId}` (deterministic id → no double credit), increments `users.points`, stamps `pointsAwarded` and notifies the resident.
- The wallet shows the ledger with source, points and date; the ledger is immutable in the rules.

### 2.6 Resident registration approval → resident decision (new)
- New resident sign-ups start at `registrationStatus: 'pending'` and the barangay desk receives a **New resident registration** alert.
- Barangay staff review the resident in **User validation → Residents**: the card now shows both the verification badge and the registration badge (Registration pending / Awaiting resident / Registration accepted / Resident declined).
- Approving sets `registrationStatus: 'approved'`, `registrationApprovedAt` and notifies the resident to answer.
- The resident dashboard shows a decision card: **Accept** or **Decline** (declining asks for confirmation). The answer is written with `registrationDecidedAt` (server time) and the barangay desk is notified either way.
- Accounts that existed before this workflow default to `accepted`, so nobody is asked to re-approve an old account. A rejected registration stays open for correction and re-review.

### 2.7 Role dashboards and navigation
- Quick actions added for the new modules: Iswim (Manuals, Manual requests), City Hall (Complaints, Resident requests, Manuals, Manual requests), Resident (Complaints).
- The notification bell and notification list are desk-aware: residents see their own alerts, barangay staff see `staff`, City Hall sees `cityHall`, Iswim sees `iswim`. Tapping a notification routes to the right screen for the signed-in role.

---

## 3. Files added and modified

### Added
```
lib/features/manuals/models/manual.dart
lib/features/manuals/services/manual_service.dart
lib/features/manuals/screens/manuals_screen.dart
lib/features/manuals/screens/manual_detail_screen.dart
lib/features/manuals/screens/manual_requests_screen.dart
lib/features/complaints/models/complaint.dart
lib/features/complaints/services/complaint_service.dart
lib/features/complaints/screens/complaint_form_screen.dart
lib/features/complaints/screens/my_complaints_screen.dart
lib/features/complaints/screens/complaint_desk_screen.dart
lib/features/complaints/widgets/complaint_detail_sheet.dart
lib/features/recycling/models/points_transaction.dart
lib/features/cityhall/screens/cityhall_requests_screen.dart
```

### Modified (application)
```
lib/app.dart                                   routes + role route sets
lib/features/auth/models/user.dart             registrationStatus + helpers
lib/features/auth/services/auth_service.dart   registration decision, signup state, desk alert
lib/features/auth/providers/auth_provider.dart answerRegistration()
lib/features/verification/services/verification_service.dart  approve → registration approved
lib/features/staff/screens/verification_screen.dart           registration badge + actions
lib/features/user/screens/user_screen.dart     decision card + registration notices
lib/features/user/screens/wallet_screen.dart   points ledger
lib/features/tickets/models/trip_ticket.dart   statuses, history, revision/rejection reasons
lib/features/tickets/services/ticket_service.dart  audit trail, return/reject/resubmit
lib/features/tickets/screens/ticket_detail_screen.dart  audit timeline + actions
lib/features/waste/models/waste_submission.dart    pointsAwarded
lib/features/waste/services/waste_service.dart     transactional validation + ledger
lib/features/staff/screens/waste_validation_screen.dart  actor + points input
lib/features/recycling/services/recycling_service.dart   resident ledger stream
lib/features/requests/models/collection_request.dart     responses
lib/features/requests/services/collection_request_service.dart  shared reply + notifications
lib/features/requests/screens/my_requests_screen.dart   City Hall replies section
lib/features/staff/screens/collection_requests_screen.dart  City Hall replies section
lib/features/notifications/services/notification_service.dart  desk channels
lib/features/notifications/widgets/notification_bell.dart      desk-aware
lib/features/notifications/screens/notifications_screen.dart   role-aware navigation
lib/features/delay/services/delay_service.dart     City Hall desk routing
lib/features/iswim/screens/iswim_dashboard_screen.dart  quick actions
lib/features/cityhall/screens/cityhall_dashboard_screen.dart  quick actions
lib/features/driver/screens/driver_screen.dart     driver workflow polish
```

### Backend / rules / tests
```
firestore.rules                 new collections + resident decision transition
firestore-tests/rules.test.js   9 new suites + registration decision suites (57 tests)
```

---

## 4. Database changes

### New collections
| Collection | Purpose | Key fields |
|---|---|---|
| `manuals/{id}` | Manual record | `title, category, currentVersion, status, versions[]` metadata |
| `manuals/{id}/versions/{vN}` | Append-only version history | `version, file, notes, byUid, byName, createdAt, status` |
| `manual_requests/{id}` | City Hall → Iswim requests | `code (MR-YYYY-NNNN), title, details, neededBy, status` |
| `complaints/{id}` | Resident → DSQC complaints | `code (CMP-YYYY-NNNNNN), residentId, category, description, photos[], status, responses[]` |
| `points_transactions/{id}` | Reward ledger | `residentId, points, reason, sourceType, sourceId, byUid, createdAt` |

### Fields added to existing documents
| Path | Field | Meaning |
|---|---|---|
| `users/{uid}` | `registrationStatus` | `pending → approved → accepted / declined` |
| `users/{uid}` | `registrationApprovedAt` | When the barangay approved (staff-only write) |
| `users/{uid}` | `registrationDecidedAt` | When the resident answered (server time) |
| `trip_tickets/{id}` | `history[]` | Audit trail entries |
| `trip_tickets/{id}` | `revisionReason`, `rejectionReason` | Why a ticket went back |
| `waste_submissions/{id}` | `pointsAwarded` | Points credited on validation |
| `collection_requests/{id}` | `responses[]` | Shared City Hall replies |
| `collection_requests/{id}` | `wave`, `cityHallStatus` | Wave 1/2 and City Hall decision (existing, now parsed correctly) |

### Security rules
- `manuals` read by any signed-in account; write by Iswim, acknowledgement by City Hall; versions are append-only.
- `manual_requests` read/write by Iswim and City Hall only.
- `complaints` create by a verified resident (`role == 'user'`), read by the owner or City Hall; replies by City Hall only.
- `points_transactions` created by admin (staff), read by the owner, **immutable** (no update/delete).
- `notifications` extended for the `cityHall` and `iswim` desk channels.
- `users` self-update now blocks `registrationApprovedAt` and only permits the `approved → accepted / declined` transition, stamped with `request.time`; everything else about a resident's status stays staff-only.

No destructive migration is required. Existing documents keep working because every new field has a safe default (`registrationStatus` → `accepted`, `pointsAwarded` → 0, `history` → empty list).

---

## 5. "API endpoints" (service operations → Firestore paths)

The app talks to Firestore directly; there is no custom REST server. The equivalent contract is:

| Operation | Path | Who |
|---|---|---|
| `ManualService.createManual` | `manuals/{id}` | Iswim |
| `ManualService.publishVersion` | `manuals/{id}` + `versions/{vN}` (transaction) | Iswim |
| `ManualService.acknowledge` | `manuals/{id}` | City Hall |
| `ManualService.requestManual` | `manual_requests/{id}` (counter `MR-YYYY-NNNN`) | City Hall |
| `ManualService.fulfillRequest` | `manual_requests/{id}` | Iswim |
| `ComplaintService.submit` | `complaints/{id}` (counter `CMP-YYYY-NNNNNN`) | Resident |
| `ComplaintService.respond` | `complaints/{id}` | City Hall |
| `TicketService.accept/decline/markRunning/submit/sign` | `trip_tickets/{id}` | Driver / Barangay / Iswim / City Hall |
| `TicketService.returnForRevision/reject/resubmit` | `trip_tickets/{id}` | Barangay / Iswim / Driver |
| `WasteService.validate` | `waste_submissions/{id}`, `points_transactions/waste_{id}`, `users/{uid}.points` (transaction) | Barangay staff |
| `CollectionRequestService.addCityHallResponse` | `collection_requests/{id}.responses` | City Hall |
| `AuthService.answerRegistration` | `users/{uid}` + staff notification | Resident |
| `VerificationService.setUserVerification` | `users/{uid}` + resident notification | Barangay staff |

---

## 6. Role permissions

| Capability | Resident | Driver / Guide | Barangay staff | Iswim | City Hall |
|---|---|---|---|---|---|
| Track truck, view events/announcements | ✔ | ✔ (assigned route) | ✔ | ✔ | ✔ |
| Upload waste / earn points | ✔ | — | — | — | — |
| Validate waste, credit points | — | — | ✔ | — | — |
| Wave 1 request / Wave 2 report | ✔ | — | review + pass | — | final decision |
| File a complaint to DSQC | ✔ | — | — | — | answer |
| View complaints | own only | — | — | — | all |
| View manuals | — | — | — | ✔ | ✔ |
| Create / version a manual | — | — | — | ✔ | acknowledge |
| Request a manual | — | — | — | fulfil | ✔ |
| Trip ticket: receive, start/pause/complete | — | ✔ | — | — | — |
| Trip ticket: verify collection | — | — | ✔ | — | — |
| Trip ticket: issue, verify after barangay | — | — | — | ✔ | — |
| Trip ticket: final sign / receive at City Hall | — | — | — | — | ✔ |
| Approve resident registration | accept / decline | — | ✔ | — | — |
| Provision driver accounts | — | — | ✔ | request | ✔ |
| Delay reports | receive announcement | — | receive | file | review + route |

Every rule above is enforced in `firestore.rules`, not only by hiding UI.

---

## 7. Testing performed

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Unit / widget tests | `flutter test` | **134 passed** |
| Firestore rules tests | `npm run test:emulator` (firestore-tests) | **57 passed** |
| Release build | `flutter build web --release` | **Built `build/web`** |
| Rules deployment | `firebase deploy --only firestore:rules --project ecoconnect-ecaf8` | **Compiled and released** |

### Representative test cases
1. A pending registration cannot be accepted by the resident; an approved one can, exactly once.
2. A resident cannot write `registrationApprovedAt`; staff can.
3. A driver may append an audit entry when accepting a ticket but cannot alter the plate number.
4. A manual version can be published by Iswim; a resident cannot read `manual_requests`.
5. A complaint can be created only by a resident and read only by its owner or City Hall.
6. A points ledger row is create-only for staff, readable by its owner, and immutable.
7. `waste_{submissionId}` cannot credit the same submission twice.
8. City Hall and Iswim each read only their own desk channel.
9. Wave 2 pass and City Hall decisions notify the right desk.
10. Route guards: a resident cannot open `/cityhall`, `/iswim`, `/driver`, `/admin`.

### Bugs found and fixed during the work
| Bug | Fix |
|---|---|
| `TicketService._advanceFromAny` recorded `previousStatus: null` before the transaction, so a multi-step rejection had a wrong trail | The entry is now built with `entry.toMap()` and `previousStatus` is overwritten with the real current status **inside** the transaction |
| `CollectionRequest.copyWith` dropped `wave` and `cityHallStatus`, so a status change reset the Wave 2 flag | Both fields are carried through `copyWith` |
| Complaint creation allowed any active account to name itself as `residentId` | Rule tightened to `profile(uid).role == 'user'` |
| Publishing an announcement returned `PERMISSION_DENIED` because the deployed rules predated the collection | Rules redeployed (2026-11-07) covering every collection the app touches |
| Unused local variable in the notification screen after the desk refactor | Removed; analyzer clean |

---

## 8. Remaining issues and external configuration

1. **Email is recorded, not delivered.** `email_log` is an in-app record of what *would* be sent to District Officers; there is no Cloud Function or SMTP relay, so no real message leaves the system. Wiring a mail provider requires a Cloud Function (or an external service) and credentials.
2. **No Firebase Storage bucket.** All uploads (manual files, complaint photos, IDs) are inline base64 data URLs capped below Firestore's 1 MiB document limit. Large PDFs will be rejected; moving to Storage is the long-term fix.
3. **Web is the only runnable target here.** The Android SDK is not installed in this environment, so the Android build was not exercised.
4. **No live browser walkthrough.** Verification was static analysis + unit tests + rules tests + a release build. The screens were not clicked through in a browser in this session, so visual/layout regressions on unusual screen sizes remain unverified.
5. **Notifications are in-app only.** There is no push (FCM) or SMS channel.
6. **Real-email verification depends on Firebase's quota.** Sign-up sends Firebase's built-in verification mail; delivery is subject to the project's Firebase Auth limits.

---

## 9. Workflow verification (end-to-end, by layer)

| Workflow | Data layer | Rules | UI wired | Verified by tests |
|---|---|---|---|---|
| Resident signup → barangay review → resident accept/decline | ✔ | ✔ | ✔ | ✔ rules |
| Trip ticket issue → receive → run → submit → barangay → Iswim → City Hall | ✔ | ✔ | ✔ | ✔ rules |
| Return for revision / reject / resubmit | ✔ | ✔ | ✔ | ✔ rules |
| Delay report → DSQC → District Officer → barangay → resident | ✔ | ✔ | ✔ | ✔ rules |
| Manual create → version → acknowledge; manual request → fulfil | ✔ | ✔ | ✔ | ✔ rules |
| Resident complaint → DSQC reply → resident sees status | ✔ | ✔ | ✔ | ✔ rules |
| Resident request → barangay → City Hall → shared reply | ✔ | ✔ | ✔ | ✔ rules |
| Waste upload → staff validation → points ledger → wallet | ✔ | ✔ | ✔ | ✔ rules |
| Driver route start/pause/resume/complete + geofence/connection guard | ✔ | ✔ | ✔ | ✔ unit |

No workflow is claimed as "bug-free". The table states what was exercised and at which layer; item 4 in section 8 lists what was **not** exercised.

---

## 10. Language and motion pass (2026-11-14)

### 10.1 Filipino/Tagalog → English
Every user-facing Tagalog string was translated. 21 files were affected, mainly the crew-account console, trip tickets, fleet, delay, memos, City Hall and Iswim dashboards.

| Before | After |
|---|---|
| `Wala pang trip ticket. Iswim ang gumagawa…` | `No trip ticket yet. Iswim creates it — you cannot start the trip without one.` |
| `Tanggihan ang ticket?` | `Decline this ticket?` |
| `Napirmahan na — automatic na napasa sa susunod` | `Signed — automatically forwarded to the next signer` |
| `Mga pirma` / `Daloy ng ticket` | `Signatures` / `Ticket flow` |
| `Ipadala sa DSQC` / `Ipadala ang copy sa Barangay` | `Send to DSQC` / `Send a copy to the Barangay` |
| `Nagawa na ang account` | `Account created` |
| `Hindi na-save: …` | `Could not save: …` |
| `Salamat!` | `Thank you!` |

Notes:
- **`Barangay` is kept.** It is the official name of the smallest Philippine administrative division and is used as a proper noun throughout the rules, collections and role names. Translating it to "village" would misname a government unit. The same applies to `Iswim`, `DSQC` and `City Hall`.
- Barangay names, street names and person names were left untouched.
- No data keys, collection names or enum wire values changed — this is display text only.

### 10.2 Motion and hover system
A small motion layer was added in `lib/core/widgets/motion.dart` and applied across the app.

| Component | Behaviour |
|---|---|
| `HoverLift` | Scales up on pointer hover, lifts 2 px, dips on press. Pure visual wrapper, so the child keeps its own tap handling. |
| `FadeSlideIn` | Staggered fade + rise on first build, driven by a curve `Interval` (no timers, so widget tests stay deterministic). |
| `CountUpText` | Numbers count up when they appear. |
| `GrowBar` | Progress bars grow from zero. |
| `EcoCard` | Now interactive: hover raises the shadow (`AppColors.cardShadowHover`), warms the border, and scales 1.2 %. Applied to every tappable card in the app. |
| `TicketCard` | Same lift treatment, used by every ticket list. |
| `AppBottomNav` | Icons pop on selection (`easeOutBack`), items get a hover pill, and the Ask AI button grows and deepens its glow on hover. |
| `NotificationBell` | Unread badge scales in when it appears; the round bell lifts on hover. |
| Route transitions | `EcoPageTransitionsBuilder` fades and slides every page on all six platforms. |
| Dashboards | Resident, City Hall, Barangay staff and Iswim quick-action grids fade in with a per-tile stagger. |
| Wallet | Points balance counts up; ledger rows keep their existing layout. |

All motion is decorative: nothing depends on an animation completing, and `MediaQuery.disableAnimations` / reduced-motion is respected by Flutter's implicit animations where the platform reports it.

### 10.3 Re-verification after this pass
| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 134 passed |
| `flutter build web --release` | Built `build/web` |

---

## 11. Summary

The brief's missing modules are now implemented on top of the existing application: manuals and manual requests, direct complaints to DSQC, shared City Hall replies, the trip-ticket audit trail with revision and rejection, a real points ledger, and the resident registration acceptance flow. Existing features were preserved, all new permissions are enforced server-side, and the project passes analysis, 134 unit/widget tests, 57 rules tests, and a release web build with the updated rules deployed to `ecoconnect-ecaf8`.

The interface is now fully in English, with a shared motion system (hover lift, staggered entrances, animated counters and bars, page transitions) applied through `EcoCard` and the core widgets so new screens inherit it automatically.
