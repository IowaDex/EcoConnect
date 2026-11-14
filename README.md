# EcoConnect - Flutter Mobile Application

A comprehensive Flutter mobile application featuring user authentication, email verification, real-time GPS location tracking, and a full dashboard. Built with Firebase backend and modern Flutter practices.

## 🌿 Features

- **User Authentication**
  - Sign up with email and password
  - Login with email and password
  - Session persistence
  - Email verification

- **Email**
  - Verification emails on signup, sent by Firebase Authentication

- **Real-time GPS Location Tracking**
  - Get current GPS location with high accuracy
  - Real-time location tracking toggle
  - Location permissions handling (Android & iOS)
  - Accuracy indicator
  - Coordinates display (latitude/longitude)

- **Dashboard**
  - Welcome message with user name
  - Email verification status indicator
  - Location display with accuracy
  - Real-time tracking toggle
  - Quick action cards
  - Logout functionality

- **Modern UI**
  - Material Design 3
  - Light and dark mode support
  - Google Fonts integration
  - Responsive design

## 🚛 Smart Waste Management Modules

EcoConnect now covers the full barangay collection workflow. Every screen is
backed by Firestore; there is no demo data.

### Landing page
- Animated garbage truck on a highway, drawn entirely with CustomPainter.
- Rotating wheels, scrolling lane markings, drifting clouds, trees and
  floating recycling marks.
- Tagline, Get Started and Login entry points.
- Signed-out users land here; signed-in users are routed straight to their
  role dashboard.

### Driver
- Start, pause, resume and end an assigned route with recorded timestamps
  (startedAt, pausedAt, resumedAt, completedAt).
- Location health monitoring distinguishes GPS off, permission denied,
  offline and unknown states. Staff see the same neutral wording, so a driver
  is never falsely reported for disabling tracking.
- "Enable location" deep-links to the right device settings.
- Staff are notified on pause, resume, completion and lost location.
- Assigned collection points appear as numbered stops with address and
  schedule, a read-only preview map on the dashboard, and a full-screen
  zoomable route map with per-stop details and one-tap Google Maps directions.
- Drivers are notified when staff add, remove, deactivate or reassign a point
  on their route, and the stop list is shown even before a run starts.
- The full-screen map follows real roads through OSRM (OpenStreetMap), showing
  total distance and time plus the drive to each stop.
- Directions are shown in-app: a turn-by-turn sheet lists every manoeuvre
  ("Turn left onto Rizal Ave · 800 m") from the truck to the last stop. Google
  Maps is still one tap away when the driver wants spoken navigation.

### Barangay staff
- Announcements: create, edit, publish/unpublish, delete, optional cover photo.
- Community events: posters, schedules, registration details, upcoming and
  completed tabs.
- Collection requests: search, status/date/barangay filters, approve, reject
  with a reason, assign an active driver and a collection schedule.
- User validation: pending driver/staff accounts, government ID review with
  document preview, resident verification.
- Waste validation: photo review, approve or reject with remarks.
- Designated collection points: interactive map, tap-to-pin editor, driver
  assignment, weekly schedules, active/inactive state, route lines. Points
  assigned to a driver are merged into that driver's route as stops, so the
  driver map, stop list and ad-hoc runs pick them up without re-pinning.

### Resident
- Waste upload with camera/gallery photos, category, quantity and location.
- Upload history with validation status and staff remarks.
- Live tracking shows the truck, the planned path and the same numbered
  stops the driver follows, with a Map action for the full route.
- Verified government personnel additionally unlock **special collection
  requests**; the check is enforced in Firestore, not just by hiding the UI.
- Live announcements and upcoming events on the dashboard.
- Notification centre with unread badges and deep links.

### Notifications
- Personal notifications for account, waste, request, route, announcement and
  event updates.
- Operational alerts are written to a shared "staff" channel so residents and
  drivers never need read access to the user directory.

## 🔐 Backend setup

### Deploy the rules

The new collections are protected by firestore.rules. Deploy them before
testing the features:

~~~bash
firebase deploy --only firestore:rules --project ecoconnect-ecaf8
~~~

The emulator compiles the same file during CI, so a syntax error fails fast.

### Audit trail

Business-record changes are captured by server-side Firestore triggers and
written to the append-only `admin_audit` collection. The log records the actor
UID/type, action, document path, changed field names, outcome, and event time;
it does not copy field values. Private resident location history, driver
coordinates/heartbeat-only updates, reads/navigation, and generated counters
and notifications are intentionally excluded.

Deploy the functions and rules together:

~~~bash
firebase deploy --only functions,firestore:rules --project ecoconnect-ecaf8
~~~

Cloud Functions deployment requires the Firebase project to use the Blaze
billing plan. Once deployed, City Hall can create an **Audit viewer** login in
Accounts → New account. The viewer can access the audit page but not the
operational screens or their data. Admins and City Hall can also view the log.
Audit entries have no automatic deletion; set an organizational retention
policy before the collection grows substantially.

Functions run after the source write commits and retry failed log writes, so
entries may arrive with a delay. Firestore rules prevent app clients from
changing audit entries, but this application audit trail is not an immutable
legal evidence service: project owners with privileged Cloud access can still
administer the project. For formal evidentiary requirements, enable and retain
Google Cloud Data Access audit logs as well.

### Collections

| Collection | Purpose |
| --- | --- |
| users | Profile, role, account type, verification status |
| verificationRequests | Government ID submissions (owner + staff only) |
| announcements | Barangay announcements |
| events | Community environmental events |
| collectionRequests | Standard and special collection requests |
| wasteSubmissions | Resident waste photos and validation |
| collectionPoints | Designated pickup locations |
| notifications | Personal and shared staff notifications |
| routes / routePlans | Driver presence and staff assignments |
| shared_locations | Retired; kept only so old documents can be deleted |
| dropOffs / incidents | Recycling ledger and legacy staff-only incident records |

### Uploads

The project does not require a Firebase Storage bucket. Photos and ID
documents are compressed on-device (UploadCodec), capped at 190 KB per photo
(500 KB for an ID image, 600 KB for a PDF) and stored as data URLs inside the
owning document. This keeps every file under the same security rules as its
record and keeps a three-photo record below Firestore's 1 MiB limit.

For production traffic, move uploads to Firebase Storage and keep only the
download URL in Firestore:

1. Enable Storage in the Firebase console.
2. Add firebase_storage to pubspec.yaml.
3. Replace UploadCodec calls with an upload that returns a download URL.
4. Add Storage rules that mirror the Firestore checks (owner + staff only for
   ID documents).

### Required platform configuration

- Android: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION,
  ACCESS_BACKGROUND_LOCATION, INTERNET and ACCESS_NETWORK_STATE are already
  declared.
- Android 13+: the photo picker used by image_picker does not need storage
  permission.
- Map tiles come from OpenStreetMap; devices need internet access to render
  the staff and resident maps.

### Indexes

Queries intentionally avoid composite indexes: filtering and sorting happen in
Dart after a single-field query. If the data set grows, add the matching
composite indexes in the Firebase console and move the filters into the query.

## 📋 Prerequisites

- **Flutter SDK**: 3.44 or higher (Dart 3.12+)
  - Download: https://flutter.dev/docs/get-started/install

- **Node.js**: 20+ (for the Firebase CLI and the Firestore rules tests)
  - Download: https://nodejs.org/
- **Java**: 21+ (for the Firestore emulator used by the rules tests)

- **Firebase Project**: Create one at https://console.firebase.google.com/
  - Enable Firebase Authentication (Email/Password)
  - Enable Firestore Database

- **Android Studio** (for Android development)
  - Download: https://developer.android.com/studio

- **Xcode** (for iOS development - macOS only)
  - Install via App Store

## 🐳 Quick Start with Docker

The fastest way to run the app — no Flutter SDK, no `flutter doctor`, no platform toolchains. Docker builds the web bundle and serves it with nginx.

### 1. Provide your Firebase config

The app reads its Firebase credentials from `.env` (gitignored, so it is **not** in the repo). Copy the template and fill in your own values:

```bash
cp .env.example .env
```

```ini
FIREBASE_API_KEY=...
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=1:...:web:...
```

> These values are compiled into the JavaScript bundle and are visible to anyone who loads the site. That is normal for Firebase web apps — protect your data with Firestore rules, not by hiding the config. Never put service-account keys or private secrets in `.env`.

### 2. Build and run

```bash
docker compose up --build
```

Open **http://localhost:8080**.

Stop with `Ctrl+C` (or `docker compose down`). Rebuild after changing code with `docker compose up --build`.

### Without Docker Compose

```bash
docker build \
  --build-arg FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --build-arg FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --build-arg FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --build-arg FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --build-arg FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --build-arg FIREBASE_APP_ID="$FIREBASE_APP_ID" \
  -t ecoconnect:latest .

docker run --rm -p 8080:80 ecoconnect:latest
```

### Changing the port

Edit the `ports` mapping in `docker-compose.yml`, e.g. `"3000:80"` to serve on port 3000.

### Files

| File | Purpose |
| --- | --- |
| `Dockerfile` | Two stages: Flutter SDK builds the web bundle, nginx serves it |
| `docker/nginx.conf` | SPA routing (`try_files`), gzip, cache headers |
| `docker-compose.yml` | One-command build + run on port 8080 |
| `.dockerignore` | Keeps `build/`, `.dart_tool/`, mobile folders and `.env` out of the image |
| `.env.example` | Template for the required Firebase config |

> The Docker image targets **web** only. Android/iOS builds still need the native toolchains described below.

---

## 🚀 Installation & Setup

### 1. Clone and Navigate to Project

```bash
root project
```

### 2. Set Up Flutter

```bash
# Get Flutter packages
flutter pub get

# Run flutter doctor to verify setup
flutter doctor
```

### 3. Firebase Configuration

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project named "ecoconnect"
3. Enable Google Analytics (optional)

#### Configure Firebase CLI
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Set project
firebase use --add
# Select your ecoconnect project
```

#### Generate Firebase Config Files
```bash
# This creates google-services.json and GoogleService-Info.plist
flutterfire configure
```

### 4. Update Firebase Configuration

After running `flutterfire configure`, the `lib/firebase_options.dart` file will be auto-generated. No manual changes needed if using the CLI.

### 5. Set Up Firebase Authentication Email

```bash
# Configure the built-in Firebase email templates in:
# Firebase Console > Authentication > Templates
```

Firebase Authentication sends the verification emails. The template editor
supports branding, sender details, subjects, and email content. The app has no
password-reset flow yet, no Cloud Functions, and does not need the Blaze plan.

### 6. Enable Firebase Services

In Firebase Console:
1. **Authentication**: Enable Email/Password provider
2. **Firestore Database**: Create database in production mode

### 7. Deploy Firestore Security Rules

The rules live in `firestore.rules`. Test them, then deploy:

```bash
cd firestore-tests && npm install && npm run test:emulator
cd .. && firebase deploy --only firestore:rules
```

### 8. Create the First Admin

Signup only allows the `user` and `driver` roles. To make an admin, edit
`users/{uid}` in Firebase Console > Firestore and set `role` to `admin`. After
that, admins can change roles from the Admin Panel.

Deleting a user in the Admin Panel removes their profile and location history, and records them in `removed_users` so they can't re-create a
profile. From then on the app refuses to log them in and the rules deny them the
map and location writes. Their login account stays in Firebase Authentication;
remove or disable it in Firebase Console > Authentication if needed (doing that
from the app would require Cloud Functions on Blaze). Admins can't delete their
own profile.

To restore a deleted user, in Firebase Console > Firestore: delete their
`removed_users/{uid}` document, then re-create `users/{uid}` with `name`,
`email` and `role`. (Signing up again doesn't work while their login account
still exists; alternatively delete that account so they can sign up fresh.)

## 🏃 Running the App

### Run on Android Emulator
```bash
flutter run -d emulator
```

### Run on iOS Simulator (macOS only)
```bash
flutter run -d simulator
```

### Run on Physical Device
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

### Run with Specific Build Mode
```bash
# Debug (default)
flutter run

# Release
flutter run --release

# Profile
flutter run --profile
```

## 📁 Project Structure

```
eco_connect/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # App configuration & routing
│   ├── firebase_options.dart     # Firebase config (auto-generated)
│   ├── core/
│   │   ├── services/
│   │   │   ├── auth_service.dart       # Firebase auth wrapper
│   │   │   └── location_service.dart   # GPS/location tracking
│   │   ├── providers/
│   │   │   ├── auth_provider.dart      # Auth state management
│   │   │   └── location_provider.dart  # Location state management
│   │   ├── models/
│   │   └── utils/
│   │       └── validators.dart         # Form validation
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── signup_screen.dart
│   │   │   └── widgets/
│   │   ├── user/ driver/ admin/  # One screen set per role
│   │   ├── splash/               # Shown while the saved session is restored
│   │   └── dashboard/
│   │       └── widgets/
│   │           ├── gps_button.dart
│   │           ├── location_display.dart
│   │           └── location_map.dart
├── firestore.rules               # Firestore security rules
├── firestore-tests/              # Rules tests (Firestore emulator)
├── android/                       # Android native code
├── ios/                          # iOS native code
├── pubspec.yaml                  # Flutter dependencies
└── firebase.json                 # Firebase config
```

## 🔐 Environment Variables

Create `.env` in the project root for Flutter's Firebase configuration:

Copy the values from Firebase Console > Project settings > Your apps.

```env
# Required on every platform
FIREBASE_API_KEY=your_web_api_key
FIREBASE_MESSAGING_SENDER_ID=000000000000
FIREBASE_PROJECT_ID=your_project_id
# Required on Android/web (the web app's App ID)
FIREBASE_APP_ID=1:000000000000:web:0000000000000000
# Required for iOS builds (the iOS app registered in Firebase)
FIREBASE_IOS_APP_ID=1:000000000000:ios:0000000000000000
# Optional
FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your_project_id.firebasestorage.app
# iOS only; falls back to FIREBASE_API_KEY when empty
FIREBASE_IOS_API_KEY=your_ios_api_key
```

Never put server-side secrets (such as email provider keys) in the Flutter
`.env` file: it is bundled into the app.

## 🧪 Testing

### Manual Testing Checklist

- [ ] **Authentication**
  - [ ] Sign up with valid email
  - [ ] Receive verification email
  - [ ] Login after email verification
  - [ ] Session persists after app restart
  - [ ] Logout clears session

- [ ] **Location**
  - [ ] GPS button fetches current location
  - [ ] Coordinates display correctly
  - [ ] Real-time tracking toggle works
  - [ ] Location permissions are requested
  - [ ] Error handling for disabled GPS

- [ ] **UI/UX**
  - [ ] Dark mode works correctly
  - [ ] Light mode works correctly
  - [ ] Form validation displays errors
  - [ ] Loading states show spinners
  - [ ] Error messages are user-friendly

### Unit Testing
```bash
flutter test
```

### Firestore Rules Testing
```bash
cd firestore-tests
npm install
npm run test:emulator  # needs firebase-tools installed globally
```

GitHub runs the same tests (`.github/workflows/firestore-rules.yml`) on every
push that changes `firestore.rules` or `firestore-tests/`.

### Build APK (Android)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

### Build for iOS (IPA)

Needs a Mac with Xcode and an Apple Developer account.

1. Register an iOS app in Firebase Console > Project settings with bundle ID
   `com.ecoconnect.ecoConnect`, then add its App ID to `.env` as
   `FIREBASE_IOS_APP_ID` (optionally `FIREBASE_IOS_API_KEY`). The web app ID
   does not work on iOS.
2. Open `ios/Runner.xcworkspace` in Xcode, select the Runner target >
   Signing & Capabilities, and choose your team.
3. Build:
```bash
flutter build ipa --release
# Output: build/ios/ipa/*.ipa
```

**No Mac?** Use the GitHub Actions workflow `.github/workflows/ios-ipa.yml`:
1. In GitHub > Settings > Secrets and variables > Actions, add a secret
   `DOTENV` containing your whole `.env` file. The workflow stops if
   `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID` or
   `FIREBASE_IOS_APP_ID` is empty, or if a `your_...` placeholder is left. It
   runs `flutter test` before building, so a failing test blocks the IPA.
2. Actions > "Build iOS IPA (unsigned)" > Run workflow.
3. Download the `EcoConnect-unsigned-ipa` artifact and install it with
   Sideloadly using an Apple Account. With a free account the app stops
   opening after 7 days and must be re-installed.

## 🐛 Troubleshooting

### Firebase Connection Issues
```bash
# Verify Firebase setup
flutterfire configure

# Check Firebase CLI connection
firebase login

# List projects
firebase projects:list
```

### Location Permission Issues
- **Android**: Go to Settings > Apps > EcoConnect > Permissions > Location
- **iOS**: Go to Settings > Privacy > Location Services > EcoConnect

### Email Not Sending
- Ensure Email/Password is enabled in Firebase Authentication
- Configure templates in Firebase Console > Authentication > Templates
- Check the recipient's spam folder

### Offline Location Sync

Location updates are saved to a local SQLite queue before they are uploaded to
Firestore. If connectivity is unavailable, the app keeps the points locally
and retries when connectivity returns. The location card shows whether points
are synced, pending, or saved offline.

A driver's live position is published to `routes/{uid}` while a route is running, so
residents always see the truck on the tracking map. A resident's location is private:
it is never shared. The app only compares it on the resident's own phone with the
truck's position to send "Truck approaching" alerts, and the optional private history
in `users/{uid}/locations` is readable only by its owner (staff can read it only while
deleting that user, to clean it up).

The current Android and iOS configuration requests foreground location. The
tracking stream remains app-session based; continuous tracking after the app
is backgrounded or terminated requires a platform background-location service,
additional permissions, and clear user consent.

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Upgrade packages
flutter pub upgrade
```

## 📚 API Documentation

### AuthProvider
- `signUp(name, email, password)` - Create account and send verification
- `login(email, password)` - Authenticate user
- `logout()` - Try to purge any old shared location (5 s limit), then sign out

### LocationProvider
- `getCurrentLocation()` - Get one-time location
- `startTracking()` - Enable real-time location updates
- `stopTracking()` - Disable real-time updates
- `checkPermissions()` - Check location permission status
- `requestPermissions()` - Request location permissions

## 🔄 Future Enhancements

- [ ] Password reset flow
- [ ] Social authentication (Google, Apple)
- [ ] User profile editing
- [ ] Map view for location display
- [ ] Location history tracking
- [ ] Push notifications
- [ ] Advanced email templates
- [ ] Two-factor authentication
- [ ] User search functionality
- [ ] Community features

## 📄 License

This project is private and confidential.

## 👥 Support

For issues or questions:
1. Check the troubleshooting section above
2. Check Flutter doctor: `flutter doctor -v`

## 📱 Platforms Supported

- **Android**: 7.0 (API 24) and above
- **iOS**: 15.0 and above

---

**Last Updated**: October 13, 2026
**Flutter Version**: 3.44+
**Firebase**: firebase_core 5, firebase_auth 7, cloud_firestore 7
