# Graph Report - EcoConnect  (2026-10-14)

## Corpus Check
- Corpus is ~10,456 words - fits in a single context window. You may not need a graph.

## Summary
- 364 nodes · 496 edges · 18 communities (11 shown, 7 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- UI Screens & Widgets
- Windows Native Window Management
- Flutter Core & Widget System
- Authentication Business Logic
- Location Services
- Firebase Cloud Functions
- Windows C++ Runtime
- Windows Plugin Registration
- Firebase Configuration
- Input Validation Utilities
- Android Plugin Registration
- iOS LLDB Debug Helpers
- Email Service Layer
- Android MainActivity
- iOS Environment Export

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 21 edges
2. `AuthProvider` - 18 edges
3. `LocationProvider` - 12 edges
4. `FlutterWindow` - 10 edges
5. `WindowClassRegistrar` - 7 edges
6. `scripts` - 6 edges
7. `_DashboardScreenState` - 5 edges
8. `_SplashScreenState` - 5 edges
9. `wWinMain()` - 5 edges
10. `GetCommandLineArguments()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `build` --references--> `AuthProvider`  [EXTRACTED]
  lib/features/dashboard/screens/dashboard_screen.dart → lib/core/providers/auth_provider.dart
- `_DashboardScreenState` --references--> `LocationProvider`  [EXTRACTED]
  lib/features/dashboard/screens/dashboard_screen.dart → lib/core/providers/location_provider.dart
- `initState` --references--> `LocationProvider`  [EXTRACTED]
  lib/features/dashboard/screens/dashboard_screen.dart → lib/core/providers/location_provider.dart
- `build` --references--> `LocationProvider`  [EXTRACTED]
  lib/features/dashboard/widgets/gps_button.dart → lib/core/providers/location_provider.dart

## Import Cycles
- None detected.

## Communities (18 total, 7 thin omitted)

### Community 0 - "UI Screens & Widgets"
Cohesion: 0.06
Nodes (37): AuthProvider, build, createState, dispose, _emailController, _formKey, _handleLogin, LoginScreen (+29 more)

### Community 1 - "Windows Native Window Management"
Cohesion: 0.08
Nodes (16): EnableFullDpiSupportIfAvailable(), Point, x, y, Scale(), Size, height, width (+8 more)

### Community 2 - "Flutter Core & Widget System"
Cohesion: 0.06
Nodes (23): build, EcoConnectApp, LocationProvider, _ActionCard, build, createState, icon, initState (+15 more)

### Community 3 - "Authentication Business Logic"
Cohesion: 0.05
Nodes (32): _authService, _clearError, _currentUser, _emailService, _error, _initAuth, isAuthenticated, isEmailVerified (+24 more)

### Community 4 - "Location Services"
Cohesion: 0.05
Nodes (32): checkPermissions, _clearError, _currentPosition, dispose, _error, getCurrentLocation, hasLocation, _isLoading (+24 more)

### Community 5 - "Firebase Cloud Functions"
Cohesion: 0.06
Nodes (36): dependencies, firebase-admin, firebase-functions, nodemailer, sendgrid, description, devDependencies, eslint (+28 more)

### Community 6 - "Windows C++ Runtime"
Cohesion: 0.12
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 7 - "Windows Plugin Registration"
Cohesion: 0.09
Nodes (5): RegisterPlugins(), FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 8 - "Firebase Configuration"
Cohesion: 0.17
Nodes (9): apiKey, appId, authDomain, DefaultFirebaseOptions, FirebaseOptions, measurementId, messagingSenderId, projectId (+1 more)

### Community 9 - "Input Validation Utilities"
Cohesion: 0.25
Nodes (7): validateConfirmPassword, validateEmail, validateName, validatePassword, validatePasswordStrength, validateRequired, Validators

### Community 12 - "Email Service Layer"
Cohesion: 0.29
Nodes (6): EmailService, sendEmail, sendNotificationEmail, sendPasswordResetEmail, sendVerificationEmail, sendWelcomeEmail

## Knowledge Gaps
- **132 isolated node(s):** `sendgrid`, `eslint`, `eslint-plugin-functional`, `firebase-functions-test`, `build` (+127 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 220 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthProvider` connect `UI Screens & Widgets` to `Flutter Core & Widget System`, `Authentication Business Logic`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **What connects `sendgrid`, `eslint`, `eslint-plugin-functional` to the rest of the system?**
  _132 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `UI Screens & Widgets` be split into smaller, more focused modules?**
  _Cohesion score 0.05877551020408163 - nodes in this community are weakly interconnected._
- **Why does `LocationProvider` connect `Flutter Core & Widget System` to `UI Screens & Widgets`, `Location Services`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Should `Windows Native Window Management` be split into smaller, more focused modules?**
  _Cohesion score 0.0797872340425532 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `Windows Native Window Management` to `Windows C++ Runtime`, `Windows Plugin Registration`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Should `Flutter Core & Widget System` be split into smaller, more focused modules?**
  _Cohesion score 0.06382978723404255 - nodes in this community are weakly interconnected._