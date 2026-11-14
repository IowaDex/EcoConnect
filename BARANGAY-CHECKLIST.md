# Barangay Staff — Checklist ng Tapos

Sakop: ang barangay desk (role `admin`) sa Eco-Connect.  
Huling update: 14 Nob 2026, 22:30

---

## 1. Dashboard (`/admin-dashboard`)

- [x] Hero card **Resident applications** — bilang ng pending na aplikante, may **Review** button
- [x] Rejected applicants hindi na binibilang sa pending count
- [x] 11 quick tiles, lahat gumagana:
  - [x] Trip tickets
  - [x] Wave 2
  - [x] Requests
  - [x] Verify
  - [x] Waste
  - [x] Points
  - [x] Notices
  - [x] Memos
  - [x] Events
  - [x] Sign-ups
  - [x] Recycling
- [x] Tinanggal ang **Users** tile at ang buong `/admin` panel

## 2. Account approval — Residents (`/verification` → Residents)

- [x] Listahan ng lahat ng residente, **pending muna sa taas** tapos alphabetical
- [x] **Accept resident** button sa pending
- [x] **Reject** button — kailangan ng reason (dialog)
- [x] Pag rejected na: **nawawala na ang buttons**, may note na "waiting for the resident to resubmit"
- [x] Badge conflict fixed — hindi na magkasabay ang `Rejected` at `Registration pending`
- [x] Rejected applicant bumababa sa listahan (hindi na naka-top)
- [x] Undo sa **⋮** menu: Mark verified / Reject / Reset to unverified
- [x] Status labels: `Registration pending` → `Awaiting resident` → `Registration accepted` / `Resident declined`
- [x] Resident ang sumasagot ng approval (accept/decline) bago maging `accepted`

## 3. Government IDs (`/verification` → Government IDs)

- [x] Review desk: tingnan ang ID, **Approve** / **Reject** na may reason
- [x] Preview ng dokumento
- [ ] **KULANG:** walang pumapasok na request — laging `AccountType.resident` ang signup, at walang resident-side ID upload screen. Kailangan pa gawin ang "upload my ID" para sa residente.

## 4. Special requests (`/staff-requests`)

- [x] Natatanggap ang special collection requests ng residente
- [x] **Special only** filter chip (star icon)
- [x] Status filters + assign driver action

## 5. Wave 2 requests (`/wave2/pass`)

- [x] Natatanggap at naa-approve ang wave 2 pass requests
- [x] Hiwalay sa City Hall version (`/wave2`)

## 6. Memos at endorsements (`/memos/barangay`)

- [x] Inbox ng memo/endorsement galing City Hall
- [x] Back button role-aware (bumabalik sa `/admin-dashboard`, hindi hardcoded sa cityhall)

## 7. Events (`/events`)

- [x] **Makapag-post ng event** — FAB nakabukas lang sa barangay
- [x] Edit/manage ng sariling events
- [x] Residents see published lang

## 8. Announcements (`/announcements`)

- [x] **Makapag-post ng announcement** — FAB nakabukas lang sa barangay
- [x] Edit/manage

## 9. Sign-ups (`/event-participation`)

- [x] Sinong sumali per event
- [x] Bilang per street
- [x] `setState` bug fixed (dati sumasabog pag nag-refresh)

## 10. Trip tickets (`/ticket-signatures`)

- [x] Barangay signature slot sa submitted ticket
- [x] Ordered signing (barangay → Iswim)

## 11. Waste validation (`/waste-validation`)

- [x] Review at validate ng waste submissions
- [x] `setState` bug fixed

## 12. Points (`/collection-points`)

- [x] Collection points management

## 13. Recycling (`/dropoff`)

- [x] Drop-off / recycling desk

## 14. Tracking (`/tracking`)

- [x] Live truck tracking

## 15. Delays (`/delays`)

- [x] Delay reports

---

## Tinanggal sa Barangay (ayon sa instruction)

- [x] **Route assignment / dispatch** — kay **Iswim** na, wala nang `/routes` sa barangay
- [x] **Routes button** sa dashboard
- [x] **Incidents** — DSQC / City Hall na
- [x] **Live routes** board
- [x] **Account creation / Add user** — City Hall lang
- [x] **Users tile** at `/admin` panel
- [x] `/pending-accounts` duplicate desk

## Security / Firestore rules

- [x] Naka-**publish** at na-verify live (14 Nob, 20:50):

| Test                              | Resulta     |
| --------------------------------- | ----------- |
| Barangay gumawa ng `users/`       | 403 BLOCKED |
| Barangay gumawa ng `routePlans/`  | 403 BLOCKED |
| Iswim gumawa ng `routePlans/`     | 200 ALLOWED |
| Barangay magpalit ng role         | 403 BLOCKED |
| Barangay mag-set ng accountStatus | 200 ALLOWED |

- [x] Resident-only signup (wala nang self-signup na driver)
- [x] Barangay pwedeng mag-review ng account pero hindi pwedeng magbigay ng role

## Quality

- [x] `flutter analyze` — 0 issues
- [x] `flutter test` — 136/136 pass
- [x] `flutter build web --release` — OK

---

## Bukas pa / kailangan pa ng desisyon

1. **Resident ID upload** — wala pang screen. Kaya empty ang Government IDs tab at walang paraan ang residente para mag-resubmit ng ID pag na-reject.
2. **City Hall cannot delete a user** — rules: `allow delete: if isAdmin() && uid != self`. Barangay lang ang nakakabura. Kung dapat may delete din ang City Hall (sila ang gumagawa ng accounts), kailangang baguhin ang rules at i-publish.
3. **Trip tickets tile** — nasa barangay pa. Hindi kasama sa listahan ng function na binigay mo. Kumpirmahin kung tatanggalin o itatabi.
