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

### 5. Set Up Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Set up environment variables for email service
firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"
firebase functions:config:set sendgrid.email="your-email@example.com"

# Or set environment variables manually in .env.local for local testing
```

#### Get SendGrid API Key
1. Sign up for SendGrid: https://sendgrid.com/
2. Create an API key in Settings > API Keys
3. Set the API key in Firebase:
   ```bash
   firebase functions:config:set sendgrid.key="SG.xxxxx"
   ```

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

Create `.env` file in project root for local development (Firebase setup):

```env
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=ecoconnect
SENDGRID_API_KEY=your_sendgrid_key
SENDGRID_EMAIL=noreply@ecoconnect.app
```

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
- Verify SendGrid API key is set correctly
- Check Firebase Cloud Functions logs:
  ```bash
  firebase functions:log
  ```
- Ensure email is in SendGrid verified senders list

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
- `sendEmail()` - General email sender
- `sendVerificationEmail()` - Send verification
- `sendWelcomeEmail()` - Send welcome
- `sendPasswordResetEmail()` - Send password reset
- `sendNotificationEmail()` - Send generic notification

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
