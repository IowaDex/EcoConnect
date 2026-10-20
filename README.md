# EcoConnect - Flutter Mobile Application

A comprehensive Flutter mobile application featuring user authentication, email verification, real-time GPS location tracking, and a full dashboard. Built with Firebase backend and modern Flutter practices.

## 🌿 Features

- **User Authentication**
  - Sign up with email and password
  - Login with email and password
  - Session persistence
  - Email verification

- **General Email Service**
  - Verification emails on signup
  - Welcome emails after verification
  - Password reset emails (ready for implementation)
  - Notification emails (extensible system)
  - Firebase Cloud Functions integration

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

- **Node.js**: 18+ (for Firebase Cloud Functions)
  - Download: https://nodejs.org/

- **Firebase Project**: Create one at https://console.firebase.google.com/
  - Enable Firebase Authentication (Email/Password)
  - Enable Firestore Database
  - Enable Cloud Functions

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

Firebase Authentication sends verification and password-reset emails without
Cloud Functions or Brevo. The template editor supports branding, sender
details, subjects, and email content. Fully custom HTML notification emails
require a separate server-side email provider.

### 6. Enable Firebase Services

In Firebase Console:
1. **Authentication**: Enable Email/Password provider
2. **Firestore Database**: 
   - Create database in production mode
   - Add security rules (see below)
3. **Cloud Functions**: Enable billing (required for functions)

### 7. Set Up Firestore Security Rules

In Firebase Console > Firestore > Rules, replace with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - only owner can read/write
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Default deny all
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 8. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

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
│   │   │   ├── email_service.dart      # Email functionality
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
│   │   └── dashboard/
│   │       ├── screens/
│   │       │   └── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── gps_button.dart
│   │           └── location_display.dart
│   └── features/splash/
│       └── splash_screen.dart
├── functions/
│   ├── src/
│   │   └── index.js              # Cloud Functions implementation
│   └── package.json              # Node.js dependencies
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
```

Brevo is not required for the current Firebase email flow. If it is used in
the future, its secrets must remain server-side and must not be added to the
Flutter `.env` file.

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

### Build APK (Android)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

### Build for iOS
```bash
flutter build ios --release
# Follow on-screen instructions for deployment
```

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
Authenticated users can read these opted-in locations and see them as
additional markers on the map. Turning sharing off deletes the user's shared
location document; private location history remains restricted to its owner.

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
- `logout()` - Sign out user
- `sendVerificationEmail()` - Resend verification email
- `refreshUser()` - Refresh auth state

### LocationProvider
- `getCurrentLocation()` - Get one-time location
- `startTracking()` - Enable real-time location updates
- `stopTracking()` - Disable real-time updates
- `checkPermissions()` - Check location permission status
- `requestPermissions()` - Request location permissions

### EmailService
- `sendVerificationEmail()` - Send verification
- `sendPasswordResetEmail()` - Send password reset

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
2. Review Firebase logs: `firebase functions:log`
3. Check Flutter doctor: `flutter doctor -v`

## 📱 Platforms Supported

- **Android**: 5.0 (API 21) and above
- **iOS**: 11.0 and above

---

**Last Updated**: October 13, 2026
**Flutter Version**: 3.x+
**Firebase**: Latest (v2.24+)
