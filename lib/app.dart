import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_gate.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/verify_email_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/landing/screens/landing_screen.dart';
import 'features/user/screens/user_screen.dart';
import 'features/driver/models/truck_crew_role.dart';
import 'features/driver/screens/truck_picker_screen.dart';
import 'features/driver/screens/driver_screen.dart';
import 'features/driver/screens/driver_routes_screen.dart';
import 'features/driver/screens/driver_completed_screen.dart';
import 'features/driver/screens/driver_profile_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/live_routes_screen.dart';
import 'features/ai/screens/ask_ai_screen.dart';
import 'features/alerts/screens/alerts_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/community/screens/post_detail_screen.dart';
import 'features/staff/screens/incident_desk_screen.dart';
import 'features/staff/screens/route_plans_screen.dart';
import 'features/staff/screens/verification_screen.dart';
import 'features/staff/screens/collection_requests_screen.dart';
import 'features/staff/screens/waste_validation_screen.dart';
import 'features/staff/screens/collection_points_screen.dart';
import 'features/staff/screens/event_participation_screen.dart';
import 'features/announcements/screens/announcements_screen.dart';
import 'features/events/screens/events_screen.dart';
import 'features/waste/screens/waste_upload_screen.dart';
import 'features/waste/screens/waste_history_screen.dart';
import 'features/requests/models/collection_request.dart';
import 'features/requests/screens/request_form_screen.dart';
import 'features/requests/screens/my_requests_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/notifications/widgets/notification_banner_host.dart';
import 'features/notifications/widgets/push_notification_host.dart';
import 'features/tracking/screens/tracking_screen.dart';
import 'features/tracking/widgets/truck_proximity_host.dart';
import 'features/driver/widgets/run_broadcast_host.dart';
import 'features/tickets/screens/ticket_detail_screen.dart';
import 'features/tickets/screens/driver_tickets_screen.dart';
import 'features/tickets/screens/create_ticket_screen.dart';
import 'features/tickets/screens/ticket_queue_screen.dart';
import 'features/tickets/screens/truck_history_screen.dart';
import 'features/tickets/models/trip_ticket.dart';
import 'features/iswim/screens/iswim_dashboard_screen.dart';
import 'features/cityhall/screens/cityhall_dashboard_screen.dart';
import 'features/cityhall/screens/signature_queue_screen.dart';
import 'features/delay/screens/delay_screens.dart';
import 'features/district/screens/barangay_staff_directory_screen.dart';
import 'features/district/screens/district_officer_dashboard_screen.dart';
import 'features/district/screens/district_officers_screen.dart';
import 'features/calls/screens/call_history_screen.dart';
import 'features/memos/screens/memo_screens.dart';
import 'features/memos/screens/memo_detail_screen.dart';
import 'features/memos/services/memo_service.dart';
import 'features/memos/screens/email_log_screen.dart';
import 'features/requests/screens/wave_approval_screen.dart';
import 'features/fleet/screens/fleet_screen.dart';
import 'features/auth/screens/accounts_screen.dart';
import 'features/auth/widgets/session_ended_host.dart';
import 'features/manuals/screens/manuals_screen.dart';
import 'features/manuals/screens/manual_detail_screen.dart';
import 'features/manuals/screens/manual_requests_screen.dart';
import 'features/manuals/screens/create_assignment_manual_screen.dart';
import 'features/manuals/screens/assignment_schedule_screen.dart';
import 'features/complaints/screens/complaint_form_screen.dart';
import 'features/complaints/screens/my_complaints_screen.dart';
import 'features/complaints/screens/complaint_desk_screen.dart';
import 'features/cityhall/screens/cityhall_requests_screen.dart';
import 'features/audit/screens/audit_log_screen.dart';
import 'features/verification/screens/verify_identity_screen.dart';
import 'features/calls/widgets/call_host.dart';
import 'features/sos/screens/sos_detail_screen.dart';
import 'features/sos/screens/sos_form_screen.dart';
import 'features/sos/screens/sos_list_screen.dart';
import 'features/sos/widgets/sos_alert_host.dart';

const _publicRoutes = {
  '/splash',
  '/welcome',
  '/login',
  '/signup',
  '/forgot-password',
  // A pending sign-up types its emailed code here; it is not yet a session.
  '/verify-email',
};

const _sharedRoutes = {
  '/announcements',
  '/events',
  '/notifications',
  '/community-post',
};

const _residentRoutes = {
  '/user',
  // Residents track the collection truck from their dashboard.
  '/tracking',
  // Keep old links working, but send them to the resident complaints inbox.
  '/report-incident',
  '/community',
  '/ask-ai',
  '/alerts',
  '/waste-upload',
  '/waste-history',
  '/request-collection',
  '/my-requests',
  '/my-complaints',
  '/complaints/new',
  '/verify-identity',
  // Residents read the approved collection schedule.
  '/schedule',
  ..._sharedRoutes,
};

const _driverRoutes = {
  '/driver-trucks',
  '/driver',
  '/driver-routes',
  '/driver-completed',
  '/driver-profile',
  '/driver-tickets',
  '/tickets',
  '/schedule',
  ..._sharedRoutes,
};

const _ticketRoutes = {'/tickets', '/trucks'};

const _iswimRoutes = {
  '/iswim',
  '/iswim/new-ticket',
  '/tickets',
  '/trucks',
  '/fleet',
  // Iswim dispatches: the run assignment is theirs, not the barangay's.
  '/routes',
  '/delays',
  '/delays/new',
  '/memos',
  '/memo',
  '/manuals',
  '/manual-requests',
  '/assignment-manuals/new',
  '/assignments',
  '/schedule',
  // Iswim provisions its own colleagues and the crew logins.
  '/accounts',
  ..._sharedRoutes,
};

const _cityHallRoutes = {
  '/cityhall',
  '/tickets',
  '/trucks',
  // The fleet is Iswim's to manage: City Hall reads the trucks it dispatches
  // through the ticket desk, never the fleet page.
  '/delays',
  '/memos',
  '/memo',
  '/email-log',
  '/wave2',
  '/incidents',
  '/complaints',
  '/cityhall-requests',
  '/district-officers',
  '/calls',
  '/sos',
  '/sos/new',
  '/manuals',
  '/manual-requests',
  '/assignments',
  '/schedule',
  '/audit-log',
  ..._sharedRoutes,
};

const _auditorRoutes = {'/audit-log'};

/// The District Officer's desk: the alert queue, the call log, and the routes
/// needed to answer a delay and hand it to the barangay.
const _districtOfficerRoutes = {
  '/district-officer',
  '/district-officer/calls',
  '/district-officer/staff',
  '/delays',
  '/sos',
  ..._sharedRoutes,
};

/// The barangay desk. Dispatch (routes) and account provisioning belong to
/// Iswim and City Hall, so those routes are deliberately absent. The incident
/// desk stays: the dashboard reports what is still pending there.
const _staffRoutes = {
  '/admin-dashboard',
  '/tracking',
  '/incidents',
  '/verification',
  '/staff-requests',
  '/waste-validation',
  '/collection-points',
  '/event-participation',
  '/ticket-signatures',
  '/delays',
  '/sos',
  // The barangay answers the officer's calls, so it reads the same call
  // history the officer and City Hall see.
  '/calls',
  '/memos',
  '/memo',
  '/wave2',
  '/wave2/pass',
  '/audit-log',
  '/assignments',
  '/schedule',
  ..._ticketRoutes,
  ..._sharedRoutes,
};

String _homeFor(UserRole role, {TruckCrewRole? crewRole}) => switch (role) {
  UserRole.admin => '/admin-dashboard',
  // A driver already owns a truck, so the dashboard opens straight away.
  // A guide has no plate of his own: he starts on the fleet list and taps the
  // truck he is riding today. Decided here, in the redirect, so the dashboard
  // never flashes up as a landing page for him.
  UserRole.driver =>
    crewRole == TruckCrewRole.guide ? '/driver-trucks' : '/driver',
  UserRole.iswim => '/iswim',
  UserRole.cityHall => '/cityhall',
  UserRole.districtOfficer => '/district-officer',
  UserRole.user => '/user',
  UserRole.auditor => '/audit-log',
};

Set<String> _allowedFor(UserRole role) => switch (role) {
  UserRole.admin => _staffRoutes,
  UserRole.driver => _driverRoutes,
  UserRole.iswim => _iswimRoutes,
  UserRole.cityHall => _cityHallRoutes,
  UserRole.districtOfficer => _districtOfficerRoutes,
  UserRole.user => _residentRoutes,
  UserRole.auditor => _auditorRoutes,
};

/// Detail screens live under a collection path (`/community-post/{id}`), so a
/// plain set lookup would reject them. A prefixed match keeps the guard while
/// allowing nested ids.
bool _canOpen(UserRole role, String location) {
  final allowed = _allowedFor(role);
  if (allowed.contains(location)) return true;
  return allowed.any((route) => location.startsWith('$route/'));
}

/// Where to send the user, or null to stay. Pure so it can be unit tested.
String? authRedirect({
  required bool initialized,
  required UserRole? role,
  required String location,
  bool restrictedResident = false,
  TruckCrewRole? crewRole,
}) {
  // Stay on the splash until the saved session is restored, so a
  // logged-in user never sees the login screen flash.
  if (!initialized) return location == '/splash' ? null : '/splash';

  final isPublic = _publicRoutes.contains(location);

  if (role == null) {
    // Signed-out visitors may browse the landing and auth screens only. The
    // entry hero shares /welcome's page key, so this swap does not rebuild it.
    if (location == '/splash') return '/welcome';
    return isPublic ? null : '/login';
  }

  // There is no splash screen to navigate away: the redirect sends a restored
  // session straight to its home.
  if (location == '/splash' || location == '/welcome' || isPublic) {
    return _homeFor(role, crewRole: crewRole);
  }

  // A resident whose ID is still being checked may only track the truck and
  // manage their own account. Everything else waits for verification, even
  // when the URL is typed by hand.
  if (restrictedResident) {
    const open = {
      '/user',
      '/tracking',
      '/verify-identity',
      '/notifications',
      '/schedule',
    };
    if (!open.contains(location)) return '/user';
  }

  // Filing an SOS is DSQC's action. The shared `/sos` prefix would otherwise
  // let another desk open the form by typing the URL.
  if (location == '/sos/new' && role != UserRole.cityHall) {
    return _homeFor(role, crewRole: crewRole);
  }

  // A driver must not reach the staff desk by typing the URL, and vice versa.
  if (!_canOpen(role, location)) return _homeFor(role, crewRole: crewRole);
  return null;
}

/// Both entry routes render the same hero screen.
///
/// The redirect swaps `/splash` for `/welcome` the instant the saved session
/// resolves, so the two routes must produce the *same* page key. Without it the
/// navigator would tear the screen down and rebuild it, restarting the truck
/// animation and the copy reveal in front of the user.
Page<void> _heroPage() => const MaterialPage<void>(
  key: ValueKey<String>('ecoconnect-hero'),
  child: LandingScreen(),
);

class EcoConnectApp extends StatefulWidget {
  const EcoConnectApp({super.key});

  @override
  State<EcoConnectApp> createState() => _EcoConnectAppState();
}

class _EcoConnectAppState extends State<EcoConnectApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        return authRedirect(
          initialized: auth.isInitialized,
          role: auth.currentUser?.role,
          location: state.matchedLocation,
          restrictedResident: auth.currentUser?.isRestrictedResident ?? false,
          crewRole: auth.currentUser?.crewRole,
        );
      },
      routes: [
        GoRoute(path: '/splash', pageBuilder: (_, __) => _heroPage()),
        GoRoute(path: '/welcome', pageBuilder: (_, __) => _heroPage()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (_, __) => const VerifyEmailScreen(),
        ),
        GoRoute(path: '/user', builder: (_, __) => const UserScreen()),
        GoRoute(
          path: '/verify-identity',
          builder: (_, __) => const VerifyIdentityScreen(),
        ),
        GoRoute(
          path: '/driver-trucks',
          builder: (_, __) => const TruckPickerScreen(),
        ),
        GoRoute(path: '/driver', builder: (_, __) => const DriverScreen()),
        GoRoute(
          path: '/driver-tickets',
          builder: (_, __) => const DriverTicketsScreen(),
        ),
        GoRoute(
          path: '/tickets/:id',
          builder: (_, state) => TicketDetailScreen(
            ticketId: state.pathParameters['id'] ?? '',
            autoSign: state.uri.queryParameters['sign'] == '1',
          ),
        ),
        GoRoute(
          path: '/trucks/:id/history',
          builder: (_, state) =>
              TruckHistoryScreen(truckId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/iswim',
          builder: (_, __) => const IswimDashboardScreen(),
        ),
        GoRoute(
          path: '/iswim/new-ticket',
          builder: (_, __) => const CreateTicketScreen(),
        ),
        GoRoute(
          path: '/cityhall',
          builder: (_, __) => const CityHallDashboardScreen(),
        ),
        GoRoute(
          path: '/cityhall/signatures',
          builder: (_, __) => const SignatureQueueScreen(),
        ),
        GoRoute(
          path: '/district-officers',
          builder: (_, __) => const DistrictOfficersScreen(),
        ),
        GoRoute(
          path: '/district-officer',
          builder: (_, __) => const DistrictOfficerDashboardScreen(),
        ),
        GoRoute(
          path: '/district-officer/calls',
          builder: (_, __) => const CallHistoryScreen(),
        ),
        GoRoute(
          path: '/district-officer/staff',
          builder: (_, state) => BarangayStaffDirectoryScreen(
            barangay: state.uri.queryParameters['barangay'],
            incidentId: state.uri.queryParameters['incidentId'],
            incidentCode: state.uri.queryParameters['code'],
            incidentReason: state.uri.queryParameters['reason'],
          ),
        ),
        GoRoute(path: '/sos', builder: (_, __) => const SosListScreen()),
        GoRoute(path: '/sos/new', builder: (_, __) => const SosFormScreen()),
        GoRoute(
          path: '/sos/:id',
          builder: (_, state) =>
              SosDetailScreen(incidentId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(path: '/calls', builder: (_, __) => const CallHistoryScreen()),
        GoRoute(path: '/fleet', builder: (_, __) => const FleetScreen()),
        GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
        GoRoute(
          path: '/delays',
          builder: (context, __) {
            final role = context.read<AuthProvider>().currentUser?.role;
            return DelayListScreen(
              canForward: role == UserRole.cityHall,
              canAnnounce: role == UserRole.admin,
            );
          },
        ),
        GoRoute(
          path: '/delays/new',
          builder: (_, __) => const FileDelayScreen(),
        ),
        GoRoute(
          path: '/memos/new',
          builder: (_, state) => MemoComposeScreen(
            initialChannel: state.uri.queryParameters['channel'],
            initialKind: MemoKindX.fromName(state.uri.queryParameters['kind']),
          ),
        ),
        GoRoute(
          path: '/memo/:id/edit',
          builder: (_, state) =>
              MemoComposeScreen(memoId: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/memo/:id',
          builder: (_, state) => MemoDetailScreen(
            memoId: state.pathParameters['id']!,
            autoSign: state.uri.queryParameters['sign'] == '1',
          ),
        ),
        GoRoute(
          path: '/memos/:channel',
          builder: (_, state) {
            final channel = state.pathParameters['channel'] ?? 'cityHall';
            return MemoInboxScreen(
              channel: channel,
              title: switch (channel) {
                'iswim' => 'Memos · Iswim',
                'barangay' => 'Memos · Barangay',
                _ => 'Memos · City Hall',
              },
            );
          },
        ),
        GoRoute(path: '/email-log', builder: (_, __) => const EmailLogScreen()),
        GoRoute(
          path: '/wave2',
          builder: (_, __) => const WaveApprovalScreen(forCityHall: true),
        ),
        GoRoute(
          path: '/wave2/pass',
          builder: (_, __) => const WaveApprovalScreen(forCityHall: false),
        ),
        GoRoute(
          path: '/ticket-signatures',
          builder: (_, __) => const TicketQueueScreen(
            signer: TicketStatusSigner.barangay,
            title: 'Barangay signature',
          ),
        ),
        GoRoute(
          path: '/driver-routes',
          builder: (_, __) => const DriverRoutesScreen(),
        ),
        GoRoute(
          path: '/driver-completed',
          builder: (_, __) => const DriverCompletedScreen(),
        ),
        GoRoute(
          path: '/driver-profile',
          builder: (_, __) => const DriverProfileScreen(),
        ),
        GoRoute(
          path: '/admin-dashboard',
          builder: (_, __) => const AdminDashboardScreen(),
        ),
        GoRoute(path: '/audit-log', builder: (_, __) => const AuditLogScreen()),
        GoRoute(path: '/tracking', builder: (_, __) => const TrackingScreen()),
        GoRoute(
          path: '/live-routes',
          builder: (_, __) => const LiveRoutesScreen(),
        ),
        GoRoute(
          path: '/report-incident',
          redirect: (_, __) => '/my-complaints',
        ),
        GoRoute(path: '/wallet', redirect: (_, __) => '/user'),
        GoRoute(
          path: '/community',
          builder: (_, __) => const CommunityScreen(),
        ),
        GoRoute(
          path: '/community-post/:id',
          builder: (_, state) =>
              PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(path: '/ask-ai', builder: (_, __) => const AskAiScreen()),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        GoRoute(
          path: '/incidents',
          builder: (_, __) => const IncidentDeskScreen(),
        ),
        GoRoute(path: '/routes', builder: (_, __) => const RoutePlansScreen()),
        // The recycling station and its points wallet are gone; an old
        // bookmark lands on the dashboard.
        GoRoute(path: '/dropoff', redirect: (_, __) => '/admin-dashboard'),
        GoRoute(
          path: '/verification',
          builder: (_, __) => const VerificationScreen(),
        ),
        GoRoute(
          path: '/staff-requests',
          builder: (_, __) => const CollectionRequestsScreen(),
        ),
        GoRoute(
          path: '/waste-validation',
          builder: (_, __) => const WasteValidationScreen(),
        ),
        GoRoute(
          path: '/collection-points',
          builder: (_, __) => const CollectionPointsScreen(),
        ),
        GoRoute(
          path: '/event-participation',
          builder: (_, __) => const EventParticipationScreen(),
        ),
        GoRoute(
          path: '/announcements',
          builder: (_, __) => const AnnouncementsScreen(),
        ),
        GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        GoRoute(
          path: '/waste-upload',
          builder: (_, __) => const WasteUploadScreen(),
        ),
        GoRoute(
          path: '/waste-history',
          builder: (_, __) => const WasteHistoryScreen(),
        ),
        GoRoute(
          path: '/request-collection',
          builder: (_, state) => RequestFormScreen(
            initialKind: RequestKindX.fromName(
              state.uri.queryParameters['kind'],
            ),
          ),
        ),
        GoRoute(
          path: '/my-requests',
          builder: (_, __) => const MyRequestsScreen(),
        ),
        GoRoute(
          path: '/my-complaints',
          builder: (_, state) => MyComplaintsScreen(
            initialComplaintId: state.uri.queryParameters['id'],
          ),
        ),
        GoRoute(
          path: '/complaints/new',
          builder: (_, __) => const ComplaintFormScreen(),
        ),
        GoRoute(
          path: '/complaints',
          builder: (_, state) => ComplaintDeskScreen(
            initialComplaintId: state.uri.queryParameters['id'],
          ),
        ),
        GoRoute(
          path: '/cityhall-requests',
          builder: (_, __) => const CityHallRequestsScreen(),
        ),
        GoRoute(path: '/manuals', builder: (_, __) => const ManualsScreen()),
        GoRoute(
          path: '/manuals/:id',
          builder: (_, state) =>
              ManualDetailScreen(manualId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/manual-requests',
          builder: (_, __) => const ManualRequestsScreen(),
        ),
        GoRoute(
          path: '/assignment-manuals/new',
          builder: (_, state) => CreateAssignmentManualScreen(
            requestId: state.uri.queryParameters['requestId'],
            requestTitle: state.uri.queryParameters['title'] ?? '',
          ),
        ),
        GoRoute(
          path: '/assignments',
          builder: (_, __) => const AssignmentScheduleScreen(staffView: true),
        ),
        GoRoute(
          path: '/schedule',
          builder: (_, __) => const AssignmentScheduleScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // The EcoConnect design system is a light-only brand palette.
      themeMode: ThemeMode.light,
      routerConfig: _router,
      // Realtime notification banners float above every screen, so a new
      // approval or broadcast shows up without pulling to refresh.
      // The offline truck sits outside the banner host: if the phone has no
      // network there is nothing worth announcing over the top of it. The
      // session notice is outermost so it is never hidden.
      builder: (context, child) => SessionEndedHost(
        child: CallHost(
          child: SosAlertHost(
            child: OfflineGate(
              // Drivers keep working through dead spots instead of being
              // blocked.
              enabled: context.select<AuthProvider, bool>(
                (auth) => auth.currentUser?.role != UserRole.driver,
              ),
              child: PushNotificationHost(
                child: NotificationBannerHost(
                  child: RunBroadcastHost(
                    child: TruckProximityHost(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
