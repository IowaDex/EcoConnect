# Graph Report - EcoConnect  (2026-10-15)

## Corpus Check
- 42 files · ~12,629 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 34 file(s) not represented in the graph (top: .xml 7, (none) 6, .properties 5)

## Summary
- 388 nodes · 554 edges · 22 communities (13 shown, 9 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `00b8dca4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- signup_screen.dart
- win32_window.cpp
- app.dart
- auth_provider.dart
- location_provider.dart
- package.json
- utils.cpp
- FlutterWindow
- firebase_options.dart
- validators.dart
- GeneratedPluginRegistrant.java
- handle_new_rx_page
- email_service.dart
- flutter_export_environment.sh
- location_display.dart
- splash_screen.dart
- widget_test.dart

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 21 edges
2. `AuthProvider` - 13 edges
3. `FlutterWindow` - 10 edges
4. `LocationProvider` - 8 edges
5. `WindowClassRegistrar` - 7 edges
6. `scripts` - 6 edges
7. `build` - 5 edges
8. `_DriverScreenState` - 5 edges
9. `_UserScreenState` - 5 edges
10. `Point` - 5 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `FlutterWindow` --inherits--> `Win32Window`  [EXTRACTED]
  windows/runner/flutter_window.h → windows/runner/win32_window.h
- `wWinMain()` --calls--> `GetCommandLineArguments()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `_SplashScreenState` --references--> `AuthProvider`  [EXTRACTED]
  lib/features/splash/splash_screen.dart → lib/core/providers/auth_provider.dart
- `build` --references--> `LocationProvider`  [EXTRACTED]
  lib/features/dashboard/widgets/gps_button.dart → lib/core/providers/location_provider.dart

## Import Cycles
- None detected.

## Communities (22 total, 9 thin omitted)

### Community 0 - "signup_screen.dart"
Cohesion: 0.09
Nodes (25): AuthProvider, build, createState, dispose, _emailController, _formKey, _handleLogin, LoginScreen (+17 more)

### Community 1 - "win32_window.cpp"
Cohesion: 0.08
Nodes (17): RegisterPlugins(), EnableFullDpiSupportIfAvailable(), Point, x, y, Scale(), Size, height (+9 more)

### Community 2 - "app.dart"
Cohesion: 0.07
Nodes (24): build, createState, EcoConnectApp, _EcoConnectAppState, initState, _router, AdminDashboardScreen, build (+16 more)

### Community 3 - "auth_provider.dart"
Cohesion: 0.05
Nodes (32): _authService, _clearError, _currentUser, _emailService, _error, _initAuth, isAuthenticated, isEmailVerified (+24 more)

### Community 4 - "location_provider.dart"
Cohesion: 0.05
Nodes (32): checkPermissions, _clearError, _currentPosition, dispose, _error, getCurrentLocation, hasLocation, _isLoading (+24 more)

### Community 5 - "package.json"
Cohesion: 0.06
Nodes (36): dependencies, firebase-admin, firebase-functions, nodemailer, sendgrid, description, devDependencies, eslint (+28 more)

### Community 6 - "utils.cpp"
Cohesion: 0.12
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 7 - "FlutterWindow"
Cohesion: 0.09
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 8 - "firebase_options.dart"
Cohesion: 0.17
Nodes (9): apiKey, appId, authDomain, DefaultFirebaseOptions, FirebaseOptions, measurementId, messagingSenderId, projectId (+1 more)

### Community 9 - "validators.dart"
Cohesion: 0.25
Nodes (7): validateConfirmPassword, validateEmail, validateName, validatePassword, validatePasswordStrength, validateRequired, Validators

### Community 12 - "email_service.dart"
Cohesion: 0.29
Nodes (6): EmailService, sendEmail, sendNotificationEmail, sendPasswordResetEmail, sendVerificationEmail, sendWelcomeEmail

### Community 15 - "location_display.dart"
Cohesion: 0.17
Nodes (11): LocationProvider, build, GpsButton, _showLocationError, build, _CoordinateTile, _getAccuracyColor, icon (+3 more)

### Community 16 - "splash_screen.dart"
Cohesion: 0.17
Nodes (9): _animationController, build, createState, dispose, _fadeAnimation, initState, _scaleAnimation, SplashScreen (+1 more)

## Knowledge Gaps
- **131 isolated node(s):** `_router`, `createState`, `build`, `createState`, `createState` (+126 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 228 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthProvider` connect `signup_screen.dart` to `splash_screen.dart`, `auth_provider.dart`, `location_display.dart`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._
- **What connects `_router`, `createState`, `build` to the rest of the system?**
  _131 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `signup_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.08870967741935484 - nodes in this community are weakly interconnected._
- **Why does `LocationProvider` connect `location_display.dart` to `location_provider.dart`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Should `win32_window.cpp` be split into smaller, more focused modules?**
  _Cohesion score 0.07653061224489796 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `win32_window.cpp` to `utils.cpp`, `FlutterWindow`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Should `app.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.06704260651629072 - nodes in this community are weakly interconnected._