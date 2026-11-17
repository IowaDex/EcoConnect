# Eco Connect — Implementation Report

**Date:** 2026-11-17
**Project:** `ecoconnect-ecaf8` — Flutter (web build verified) + Firebase Auth + Cloud Firestore
**Codebase at time of writing:** 193 Dart files, ~55,100 lines under `lib/`, 29 test files
**Verification:** `flutter analyze` clean · 187 Dart tests passing · 66 Firestore rules tests passing · `firestore.rules` deployed · `flutter build web --release` succeeded
**Service area:** Barangay Batasan Hills, Quezon City — one barangay only

---

## 0. Service area (single barangay)

The deployment is scoped to **Barangay Batasan Hills, Quezon City**. A resident from any other barangay cannot register or use the app. The rule is enforced in four places, not just in the UI:

| Layer | Behaviour |
|---|---|
| `lib/core/constants/service_area.dart` | Single source for the name/city/province and `ServiceArea.covers()` |
| Sign-up (`signup_screen.dart`) | City and barangay pickers removed; a fixed address card shows Batasan Hills, Quezon City, Metro Manila. The profile writes those constants |
| Login (`auth_service.dart`) | A resident whose stored `barangay` is non-empty and not Batasan Hills is signed out with `AuthErrorType.outOfArea` |
| Session restore (`auth_provider.dart`) | The same check blocks an already-saved session, so an old account cannot slip in |
| `firestore.rules` | Resident self-sign-up requires `barangay == 'Batasan Hills'` **and** an attached `barangayId` photo under 900 KB |
| Rules test | *"only Batasan Hills residents can register"* — another barangay fails, a missing barangay fails, Batasan Hills without an ID fails, Batasan Hills with an ID succeeds |

**Proof of residence at sign-up.** The profile step now requires one photo (`ImagePickerField`, document mode) labelled *Barangay ID or proof of residence*. It is stored as `users/{uid}.barangayId` and shown to the barangay desk from **Resident verification → View submitted ID**, so the person reviewing the registration sees the same document the resident uploaded.

### 0.1 Account provisioning — ISWIM only

| Role | Can create accounts |
|---|---|
| ISWIM | **Yes** — drivers, guides and its own colleagues, from `/accounts` |
| Barangay Staff | No — the quick action and the route were removed |
| City Hall | No — the quick action and the route were removed |
| Driver / Guide / Resident | No |

Enforced in three layers: the `/accounts` route is only in `_iswimRoutes`; `accounts_screen.dart` shows the create button only for ISWIM; and `firestore.rules` `users` create has just two paths — resident self sign-up and `isIswim()` provisioning `iswim`/`driver`. Barangay and City Hall logins are now seeded outside the app (Firebase console). Rules test *"only Iswim may create an account"* covers this.

---

## 1. Summary

The application was **extended, not rebuilt**. The existing operational backbone was audited first and kept intact:

- Trip tickets with the multi-signature chain (driver → barangay → Iswim → City Hall)
- Delay reports, memos/endorsements, email log
- Wave 1 / Wave 2 collection requests, waste upload + validation, events, announcements
- GPS truck tracking with a 100 m radius, hysteresis guard and connection-state handling
- Single-session enforcement, deleted-user tombstones, in-app notification desk channels

This pass closed the genuine gaps: the ISWIM account desk, Wave 2 end-to-end status wording, duty scheduling with conflict detection and reminders, a shared search/filter/pagination layer, notification de-duplication and ordering, the registration/security rework (birthdate, no province, strong passwords), the removal of the recycling wallet (truck tracking stays with residents), and the responsive/redesign polish.

Nothing working was removed. `RecyclingService`, `/dropoff`, `TruckProximityHost` and all live-route/GPS infrastructure remain in the codebase — only their resident-facing entry points were removed.

---

## 2. Role model and access control

| Role | Enum | Dashboard | Can create accounts | Can create manuals | Can sign tickets |
|---|---|---|---|---|---|
| Resident | `user` | `/user` | no | no | no |
| ISWIM | `iswim` | `/iswim` | yes — drivers, guides **and other ISWIM accounts** | yes | yes (2nd signature) |
| Truck Driver | `driver` + `crewRole.driver` | `/driver` | no | no | accepts ticket |
| Truck Driver Guide | `driver` + `crewRole.guide` | `/driver` (read-only run info) | no | no | no |
| Barangay Staff | `admin` | `/admin-dashboard` | yes — residents only | no | yes (1st signature) |
| City Hall / DSQC | `cityHall` | `/cityhall` | yes — barangay staff / residents | no | yes (final signature) |

Enforcement is **server-side** in `firestore.rules`, not only in navigation:

- `isAdmin()`, `isIswim()`, `isCityHall()`, `isActive()`, `isVerifiedGovernment()`, `isSelf()` helpers.
- `users` create has four explicit paths (self sign-up, admin, City Hall, ISWIM). The ISWIM path added this pass:

```js
|| (isIswim()
  && !isRemoved(userId)
  && request.resource.data.role in ['iswim', 'driver']
  && request.resource.data.accountStatus == 'active'
  && (!('accountType' in request.resource.data)
      || request.resource.data.accountType in ['resident', 'government'])
  && !('points' in request.resource.data)
  && photoOk(request.resource.data))
```

- The UI never offers admin/City Hall creation to ISWIM (`canCreateIswim` is `role == iswim`; the role dropdown is filtered by the caller).
- `incidents` update/delete is now `isAdmin() || isCityHall()`, matching the desk that actually owns them.
- Route allow-lists in `lib/app.dart` are per role; `/accounts` was added to `_iswimRoutes`; `/wallet` was removed from the resident set. `/tracking` stays in the resident set.

Rules were compiled and released to `ecoconnect-ecaf8` on **2026-11-17**.

---

## 3. Feature status

### 3.1 Resident

| Requirement | Status | Where |
|---|---|---|
| Events / announcements list + apply | Fully implemented | `features/community`, `features/events` |
| Delay notifications | Fully implemented | `features/delay`, resident notification stream |
| Profile with birthdate (no province) | Fully implemented | `signup_screen.dart`, `models/user.dart` |
| Special requests | Fully implemented | `request_form_screen.dart` (`kind: special`) |
| Registration result notification | Fully implemented | `auth_service.dart`, dedupe key `registration_$uid` |
| Wave 1 garbage tracking | Fully implemented | `/waste-upload`, `/waste-history`, `/my-requests` |
| Wave 2 uncollected garbage | Fully implemented | `/request-collection?wave=2`, `wave2StageLabel` |
| Complaints to DSQC + tracking | Fully implemented | `/complaints/new`, `/my-complaints` |
| Track the Truck | Fully implemented | `/tracking` route, Track tab in `app_bottom_nav.dart`, and a "Track truck" quick action on the resident home |
| Recycling wallet removed | Done | `wallet_screen.dart` deleted, `/wallet` route removed |

Wave 2 stage wording is now a single derived getter (`CollectionRequest.wave2StageLabel`) so the resident, barangay and City Hall all read the same words:

`Submitted → Under barangay review → Verified by barangay → Forwarded to City Hall → Approved by City Hall / Declined by City Hall → Scheduled → In progress → Collected → Completed`, with `Rejected` as the terminal negative state. Each transition appends a `RequestHistoryEntry`, so the thread shows who did what and when.

### 3.2 ISWIM

| Requirement | Status | Notes |
|---|---|---|
| Trip ticket generation | Fully implemented | `create_ticket_screen.dart`, `ticket_service.dart` |
| Assignment to driver + truck | Fully implemented | ticket carries `driverId`, `truckId`, `plateNumber` |
| Monitoring | Fully implemented | `ticket_queue_screen` (searchable, paginated), `driver_tickets_screen` |
| Receive completed & signed tickets | Fully implemented | `iswimSigned` hop |
| Forward to City Hall + barangay copies | Fully implemented | desk notifications `notifyCityHall`, `notifyStaff` |
| Search & filter tickets | Fully implemented | code / driver / plate / zone / route / date |
| Delay reports → DSQC → District Officer → Barangay | Fully implemented | `delay_service.dart`, barangay copy now created at filing |
| Manual upload + version history | Fully implemented | `manuals/{id}` + `manuals/{id}/versions/{vN}` |
| City Hall notification on publish | Fully implemented | City Hall desk channel |
| Centralized manual synchronization | Fully implemented | single `manuals` source, acknowledgement recorded |
| Create driver accounts | Fully implemented | `/accounts` |
| Create its own ISWIM accounts | Fully implemented this pass | `/accounts` + rules branch |
| Truck schedule management | Fully implemented | `route_plans_screen.dart` |

### 3.3 City Hall / DSQC

| Requirement | Status | Notes |
|---|---|---|
| Receive ISWIM notices | Fully implemented | desk channel `cityHall` |
| Request a manual | Fully implemented | `manual_requests` (`MR-YYYY-NNNN`) |
| Receive signed trip tickets | Fully implemented | `iswimSigned → completed` |
| Memos/endorsements in & out | Fully implemented | `memo_service.dart`, signature + acknowledgement + history |
| Resident complaints with attachments | Fully implemented | `complaint_desk_screen` (search, status filter, pagination) |
| Wave 2 approvals with full history | Fully implemented | `wave_approval_screen`, `passToCityHall` / `cityHallDecision` |
| Reflect decision in both accounts | Fully implemented | resident + barangay notifications, both list the new stage |
| Monitor operations | Fully implemented | `/cityhall`, `/cityhall-requests` |

### 3.4 Barangay Staff

| Requirement | Status | Notes |
|---|---|---|
| Community events / announcements | Fully implemented | create + edit |
| Event applications approve / reject | Fully implemented | |
| Resident account validation | Fully implemented | `pending_accounts_screen` (search + role chips + pagination) |
| Verification review with remarks | Fully implemented | `verification_screen` (search + status chips + pagination) |
| Special requests | Fully implemented | |
| Wave 1 & Wave 2 handling | Fully implemented | `wave_approval_screen` (barangay face) |
| Memo inbox with acknowledge | Fully implemented | |
| Truck & driver assignment | Fully implemented | `route_plans_screen` |
| Prevent route conflicts | Fully implemented this pass | `RouteConflictException` on window overlap |
| Notify drivers on assignment | Fully implemented this pass | `plan_${id}_assigned` / `plan_${id}_cancelled` |
| Sync assignment to driver account | Fully implemented | driver sees plan immediately via `watchUpcomingPlans` |
| User management: search / filter / pagination | Fully implemented | |

### 3.5 Driver and Guide

| Requirement | Status | Notes |
|---|---|---|
| Receive assignments & tickets | Fully implemented | |
| Schedules / routes | Fully implemented | `/driver-routes` |
| Start / Pause / Resume / End | Fully implemented | backend timestamps + driver/truck/ticket ids |
| GPS vs connectivity warnings | Fully implemented | `_LocationWarning` vs `_ServiceWarning` |
| Offline buffering + sync | Fully implemented | existing queue retained |
| My Schedule / upcoming duties incl. next day | Fully implemented this pass | `_UpcomingDuties` section + `_NextDutyReminder` banner |
| Guide sees only own truck/route/ticket | Fully implemented | role resolved from `TruckCrewRole.guide` |

The reminder banner (`_NextDutyReminder` in `driver_screen.dart`) shows the next scheduled duty that is **not** today — "Next duty · Tomorrow", window and zone — and taps through to `/driver-routes`. It is in-app only (see §6).

### 3.6 Registration and password security

| Requirement | Status | Notes |
|---|---|---|
| Birthdate replaces Age | Fully implemented | date picker, stored as ISO string, `ageYears` derived |
| ID upload proving Batasan Hills residence | Fully implemented | required at sign-up, reviewed by the barangay desk |
| Province field removed | Fully implemented | province resolved from the chosen city (PSGC `parentCode`) |
| Password policy 8+ / upper / lower / number / special | Fully implemented | `Validators.passwordChecks`, shared by signup and account creation |
| Live requirement display | Fully implemented | `PasswordStrengthChecklist` |
| Show / hide password | Fully implemented | both password and confirm fields |
| Copy password in authorised creation UIs | Fully implemented | copy icon on the created-password sheet and handover rows |
| Never log or store plaintext | Fully implemented | passwords only ever passed to Firebase Auth |
| Meaningful validation + refresh after verification | Fully implemented | `auth_service` reloads the profile, `authRedirect` re-routes once |
| No repeated verification | Fully implemented | verification email gated on `emailVerified` |

### 3.7 Search, filtering, pagination

Shared layer: `lib/core/utils/paging.dart` (`pageCount`, `clampPage`, `pageSlice`, `pageRangeLabel`) and `lib/core/widgets/eco_pagination.dart` (`EcoSearchField`, `EcoPaginationBar`).

| Screen | Search | Filter | Page size | Reset on filter |
|---|---|---|---|---|
| Accounts (`/accounts`) | yes | role chips | 10/25/50 | yes |
| Pending accounts | yes | role chips | yes | yes |
| Resident verification | yes | status chips | yes | yes |
| Complaint desk | yes | status chips | yes | yes |
| My complaints | yes | status chips | yes | yes |
| My requests | yes | open-only | yes | yes |
| Ticket queue | yes | — | yes | yes |
| Driver tickets | yes | needs-action grouping | yes | yes |
| Manual library | yes | status chips | yes | yes |
| Wave 2 approvals | yes | — | yes | yes |

Pagination is client-side over the watched collection: it prevents rendering thousands of rows, but the underlying `StreamBuilder` still holds the list. Server-side cursors are listed as pending in §6.

### 3.8 Notifications

- Deterministic document ids make writes idempotent: `notifications/{safe(userId)}__{safe(dedupeKey)}` written inside a transaction, so a retry or double-tap cannot create a second row.
- `collapseDuplicates` hides legacy duplicate rows already in Firestore.
- `newestFirst` treats a pending `serverTimestamp()` as *now*, so a fresh notification appears at the top instead of the bottom.
- Desk channels (`staff`, `cityHall`, `iswim`) are separate from personal streams; `NotificationBannerHost` now subscribes per role, keyed on `uid:role`, so City Hall and ISWIM actually receive banners.
- Dedupe keys were added at every call site: registration, announcements, events, complaints (filing + each reply), delays, all ticket transitions, manuals, memos, collection requests, plans.

### 3.9 Backend / database

- Real Firestore reads and writes only; no mock data in the production paths.
- Transactions for: notification `_writeOnce`, manual version bump, points ledger, ticket transitions.
- Validation: client form validation + rules `photoOk()`, role/status enums, ownership checks.
- Indexes: the queries in use are single-field or already covered; composite index requirements are noted where a new equality+orderBy pair was introduced.

### 3.10 UI / UX

- Palette applied consistently: `#2E7D32`, `#1B5E20`, `#4CAF50`, `#E8F5E9`, `#F7FAF7`, `#FFFFFF`, `#263238`, `#607D68`, `#F9A825`, `#D32F2F`.
- Professional headers, summary cards, pending-task blocks, recent activity, bottom navigation for residents, drawers for the desks.
- Responsive: `LayoutBuilder` breakpoints at 520 px and 720 px; quick-action grid switches 3 → 6 columns; filter bars scroll horizontally with 44 px hit targets.
- Forms: labelled fields, inline validation, 46 px primary buttons, disabled state while busy.
- Status indicators: shared `StatusBadge` with per-status colour and icon.
- **Resident "At a glance"** (`user_screen.dart`): two live counters — open requests and open complaints — with animated figures and a dot when something is pending; each card taps through to its list.
- **Skeleton loaders** (`core/widgets/eco_skeleton.dart`): `SkeletonBox` / `SkeletonList` replace bare spinners on My requests, Trip tickets, Driver tickets, My complaints and the manual library.
- **Design tokens** (`core/design/eco_tokens.dart`): shared spacing, radius and motion durations so new screens share one rhythm.
- **Animated empty states** (`empty_state.dart`): the mark breathes and fades in; still under reduced motion.
- **Button micro-interactions** (`primary_button.dart`): press-scale, hover lift and a cross-fade between label and spinner.
- **Staggered dashboard entrances**: ISWIM (header, stats), City Hall (hero, desk tools, tabs) and Barangay (section label, pending card, requests card, quick actions) fade and slide in sequence.
- **One dashboard shell for every role (this batch)**: `features/dashboard/widgets/` now holds `RoleHero` (gradient letterhead card: eyebrow, greeting, name, purpose, optional avatar, status chip, animated figure strip, action pills), `RoleTopBar` (wordmark, bell, sign-out) and `QuickActionGrid` (one shortcut tile everywhere). Resident, Barangay Staff, ISWIM, Driver and City Hall all open with the same hero at the same inset, so switching accounts no longer moves the page furniture. The City Hall desk adds a sliding segmented pill, a single search-and-office filter card, documents grouped under **Today / Yesterday / dated** rules, and card skeletons; its signature queue uses the same header language, per-section counts, skeletons and empty states.
- **Barangay desk simplified**: pending accounts, open requests and pending incidents are held in three subscriptions and shown once — as three hero counters plus one "Waiting on the desk" list. The two separate cards and the duplicate quick-action badges are gone.
- **Redundancy removed (this batch)**: five hand-rolled heroes → one `RoleHero`; four shortcut grids (resident wrap, ISWIM rows, Barangay 4-column wall, City Hall cards) → one `QuickActionGrid`; three `_SectionLabel` copies → one `SectionLabel`; `DeskSearchField` → `EcoSearchField`; `DeskEmptyState` → `EmptyState`; ISWIM's custom bottom bar and `DriverNavBar`'s private copy → `AppBottomNav`; five `_logout` methods → `confirmAndLogout` (the driver keeps its own because it also ends the running route, and the resident profile sheet keeps its offline warning); four `_greeting()` copies → `greeting()` in `formatters.dart`. The login screen also stopped navigating to the undefined `/dashboard` route.
- **Role-by-role typography pass (this batch)**: alerts rebuilt on `AppPageHeader` with staggered tiles; the complaint form moved to a header + subtitle layout; every remaining screen (events, announcements, waste, driver picker/completed/profile, fleet, delays, memos, manuals, tickets, admin panel, live routes, signature queue, City Hall requests, complaint desk, profile sheet, forgot password) had its 8–9.5 px labels raised to 10–11 px, and the app bar title raised to 18 px.
- **Already in place before this pass**: the `/splash` route doubles as the animated entry screen (`landing_screen.dart`) with the `EcoTruckArt` GIF driving across the illustration, `EcoLoadingView` / `EcoLoadingOverlay` truck loaders, `HoverLift` on cards, animated bottom-nav icons and the custom `EcoPageTransitionsBuilder`.
- **Theme refresh** (`core/theme/app_theme.dart`): comfortable density, 52 px primary buttons, 20 px card radius, 14 px snackbar, 40 px icon-button targets, flat app bar on scroll, list-tile padding.
- **Auth screens rebuilt**: the login screen now leads with "Welcome back", a one-line promise, a Batasan Hills service-area pill and 11–12 px body copy; the fake "continue with Google/Facebook" buttons were removed from both login and sign-up (they only showed a "coming soon" snackbar).
- **Sign-up** uses the fixed address card and a document upload for the ID, so the profile step reads as three clear blocks: identity, proof of residence, address.

### 3.11 Animations

`lib/core/widgets/motion.dart` provides `HoverLift`, `FadeSlideIn` (staggered by index) and `CountUpText`, plus `GrowBar` for progress. The landing screen runs an intro fade/scale and a slow logo drift with two `AnimationController`s, both disposed. Notification banners animate in and out. Page transitions use a custom `EcoPageTransitionsBuilder` registered for every platform in `app_theme.dart`.

**Reduced motion:** `core/utils/reduced_motion.dart` reads `MediaQuery.disableAnimations`. `HoverLift`, `FadeSlideIn`, `CountUpText`, `GrowBar` and the skeleton shimmer all fall still when the OS asks for it.

There is **no** Lottie/Rive integration (see §6).

---

## 4. What changed in this pass

**New files**
- `lib/core/constants/service_area.dart`
- `lib/core/design/eco_tokens.dart`
- `lib/core/utils/paging.dart`, `lib/core/utils/reduced_motion.dart`
- `lib/core/widgets/eco_pagination.dart`, `lib/core/widgets/eco_skeleton.dart`
- `lib/features/auth/widgets/password_strength.dart`
- `test/paging_test.dart`, `test/password_policy_test.dart`, `test/notification_dedupe_test.dart`, `test/wave2_stage_test.dart`, `test/service_area_test.dart`

**Deleted**
- `lib/features/user/screens/wallet_screen.dart`

**Modified (38 Dart files + rules + tests)** — grouped:

- Routing/navigation: `app.dart`, `app_bottom_nav.dart`, `user_screen.dart`, `community_screen.dart`, `ask_ai_screen.dart`
- Auth/security: `models/user.dart`, `auth_service.dart`, `provisioning_service.dart`, `validators.dart`, `signup_screen.dart`, `accounts_screen.dart`, `app_text_field.dart`, `psgc_service.dart`
- Requests/Wave 2: `collection_request.dart`, `collection_request_service.dart`, `request_form_screen.dart`, `my_requests_screen.dart`, `wave_approval_screen.dart`, `cityhall_requests_screen.dart`
- Tickets: `ticket_service.dart`, `ticket_queue_screen.dart`, `driver_tickets_screen.dart`
- Notifications: `notification_service.dart`, `notification_banner_host.dart`, `notifications_screen.dart`
- Duty scheduling: `route_service.dart`, `route_plans_screen.dart`, `driver_routes_screen.dart`, `driver_screen.dart`
- Desks/lists: `complaint_desk_screen.dart`, `my_complaints_screen.dart`, `manuals_screen.dart`, `pending_accounts_screen.dart`, `verification_screen.dart`
- Services touched for dedupe/notification correctness: `announcement_service.dart`, `event_service.dart`, `complaint_service.dart`, `delay_service.dart`, `incident_service.dart`, `manual_service.dart`, `memo_service.dart`
- `firestore.rules`, `firestore-tests/rules.test.js`, `test/auth_redirect_test.dart`

---

## 5. Testing evidence

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze --no-pub` | No issues found |
| Unit + widget tests | `flutter test --no-pub` | **192 passing** |
| Rules tests | `firebase emulators:exec --only firestore … npm test` | **66/66 passing** |
| Rules deploy | `firebase deploy --only firestore:rules --project ecoconnect-ecaf8` | compiled + released |
| Web release build | `flutter build web --release` | built `build/web` (only pre-existing Wasm/CupertinoIcons warnings) |

Coverage added this pass:

- `paging_test.dart` — page arithmetic, clamping, slicing, range labels, filter-reset behaviour
- `password_policy_test.dart` — every rule, checklist/validator agreement, `Eco-123456!` accepted
- `notification_dedupe_test.dart` — duplicate collapse keeps the newest, null timestamp sorts first
- `wave2_stage_test.dart` — Wave 2 wording across all statuses, City Hall decision precedence, no raw field leakage
- `service_area_test.dart` — Batasan Hills matching (case/padding), every other barangay rejected
- `dashboard_widgets_test.dart` — the shared hero renders eyebrow/greeting/counters, survives a long name and a three-figure strip at 320 px, the shortcut grid keeps two columns on a phone and opens the tapped route, and the section label only shows an action when one is wired
- `auth_redirect_test.dart` — ISWIM may open `/accounts`; removed resident screens no longer reachable
- rules tests — *"Iswim provisions its own logins and crew, but never an admin or City Hall"*, *"only Iswim may create an account"* and *"only Batasan Hills residents can register"*

---

## 6. Partially implemented (honest status)

| Item | What exists | What is missing |
|---|---|---|
| Push / device notifications | In-app notification rows, unread counts, banners, desk channels | No FCM, no `firebase_messaging`, no local notifications — nothing arrives when the app is closed |
| Screen-by-screen redesign | All five role dashboards share one shell (hero, counters, shortcut grid, top bar) and their lists carry the motion layer and skeletons | Sub-screens written before the design system still use their original layouts with a typography pass: fleet, delays, memos, admin panel, live routes, truck picker, driver completed/profile, ticket detail/create, manual detail/requests, profile sheet, forgot password |
| Duty reminders | In-app "Next duty · Tomorrow" banner driven by `watchUpcomingPlans` | No scheduled background job; a reminder is only visible when the driver opens the app |
| Password policy enforcement | Client validation everywhere a password is set | Firebase Auth only enforces 6+ characters; no Cloud Function to reject weak passwords server-side |
| Pagination | Correct, shared, applied to ten lists | Client-side over the watched collection, not Firestore cursor pagination |
| Attachments | Inline base64 data URLs, capped under 1 MiB | No Firebase Storage, so files are size-limited and inflate document size |
| Notifications ordering | Fixed client-side (`newestFirst`) | No composite index on `createdAt`; ordering is applied after the watch returns |

---

## 7. Pending / not attempted

- Firebase Cloud Messaging and a service worker for background push.
- Cloud Functions (scheduled reminders, server-side password policy, fan-out on write).
- Firebase Storage for photos and manual files.
- Android/iOS builds — the toolchain is not installed in this environment; **only the web target was built and exercised**.
- Lottie / Rive assets.
- A live browser walkthrough of every role with real accounts. The web bundle builds and the widget tests render the shell, but no end-to-end click-through was performed this pass.

---

## 8. Known limitations and risks

1. **Rules must be redeployed after any edit.** The rules file is not auto-deployed by `flutter run`. The current release matches the repository as of 2026-11-17.
2. **Client-side pagination holds the full list in memory.** Fine for barangay-scale data; revisit with cursors if a collection grows past a few thousand documents.
3. **Base64 uploads** consume document quota; the encoder rejects anything that would exceed the 1 MiB limit with a readable message rather than failing silently.
4. **The Firestore emulator leaves a `java.exe` child behind** after `emulators:exec` on this machine. Two stale listeners on 8281 were killed on 2026-11-17; if a later run reports "port taken", kill the leftover process before retrying.
5. **`flutter analyze` reports no issues, but analysis is not a runtime test.** Screens that depend on live Firestore data were verified by reading the code paths and by unit tests, not by a live session.

---

## 9. How to verify manually

```bash
# preview (web)
flutter run -d web-server --web-port 8090 --web-hostname 127.0.0.1

# static checks
flutter analyze
flutter test
```

Suggested walkthrough:

1. **Resident** — sign up with a weak password (blocked with the checklist), then a strong one; confirm the fixed Batasan Hills address card, birthdate picker, no province field, verification email once. A resident registered to another barangay must be refused at login.
2. **Resident** — `/my-requests`: search "uncollected", page through, open a Wave 2 report and confirm the stage wording matches the barangay/City Hall view.
3. **Barangay** — `/pending-accounts` approve a resident; `/verification` search and filter; `/route-plans` assign tomorrow's duty twice at the same window (second attempt must be rejected); confirm the driver receives a notification.
4. **Driver** — open `/driver`: the "Next duty · Tomorrow" banner appears; accept a ticket, start/pause/resume/end the trip; confirm timestamps in the ticket history.
5. **ISWIM** — `/accounts` create a driver and an ISWIM account; confirm the ISWIM option is absent for City Hall; `/manuals` upload a revision and confirm City Hall is notified once.
6. **City Hall** — `/complaints` reply and change status; `/wave-approvals` approve a forwarded report and confirm the resident thread and the barangay list both show "Approved by City Hall".
7. **Notifications** — trigger the same event twice; only one row should appear, at the top, with a single unread increment.
