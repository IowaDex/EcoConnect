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

## 📋 Prerequisites

- **Flutter SDK**: 3.0.0 or higher
  - Download: https://flutter.dev/docs/get-started/install

- **Node.js**: 18+ (for the Firebase CLI and the Firestore rules tests)
  - Download: https://nodejs.org/
- **Java**: 11+ (for the Firestore emulator used by the rules tests)

- **Firebase Project**: Create one at https://console.firebase.google.com/
  - Enable Firebase Authentication (Email/Password)
  - Enable Firestore Database

- **Android Studio** (for Android development)
  - Download: https://developer.android.com/studio

- **Xcode** (for iOS development - macOS only)
  - Install via App Store

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

Firebase Authentication sends verification and password-reset emails. The
template editor supports branding, sender details, subjects, and email content.
The app has no Cloud Functions and does not need the Blaze plan.

### 6. Enable Firebase Services

In Firebase Console:
1. **Authentication**: Enable Email/Password provider
2. **Firestore Database**: Create database in production mode

### 7. Deploy Firestore Security Rules

The rules live in `firestore.rules`. Test them, then deploy:

```bash
cd firestore-tests && npm install && npx firebase emulators:exec --only firestore "npm test"
cd .. && firebase deploy --only firestore:rules
```

### 8. Create the First Admin

Signup only allows the `user` and `driver` roles. To make an admin, edit
`users/{uid}` in Firebase Console > Firestore and set `role` to `admin`. After
that, admins can change roles from the Admin Panel.

Deleting a user in the Admin Panel removes their profile, location history and
shared location, and the app refuses to log them in. Their login account stays
in Firebase Authentication; remove it in Firebase Console > Authentication if
needed (deleting it from the app would require Cloud Functions on Blaze).

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

```env
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=ecoconnect
# iOS only: the App ID of the iOS app registered in Firebase
FIREBASE_IOS_APP_ID=1:000000000000:ios:0000000000000000
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
npx firebase emulators:exec --only firestore "npm test"
```

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
   `DOTENV` containing your whole `.env` file (including `FIREBASE_IOS_APP_ID`).
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

Users can optionally enable **Share my location**. When enabled, the app
publishes the user's latest location to the `shared_locations/{uid}` document.
Signed-in users with a verified email can read these opted-in locations and see
them as additional markers on the map. Turning sharing off or logging out
deletes the user's shared location document; private location history remains
restricted to its owner and admins.

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
- `logout()` - Remove the shared location, then sign out

### LocationProvider
- `getCurrentLocation()` - Get one-time location
- `startTracking()` - Enable real-time location updates
- `stopTracking()` - Disable real-time updates
- `checkPermissions()` - Check location permission status
- `requestPermissions()` - Request location permissions
- `setSharingLocation(enabled)` - Turn live location sharing on or off

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

- **Android**: 5.0 (API 21) and above
- **iOS**: 11.0 and above

---

**Last Updated**: October 13, 2026
**Flutter Version**: 3.x+
**Firebase**: Latest (v2.24+)
