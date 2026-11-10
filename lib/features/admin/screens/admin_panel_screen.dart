import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/repositories/location_repository.dart';
import '../services/user_data_cleanup.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/brand_wordmark.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await context.read<AuthProvider>().getAllUsers();
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showResult(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
      ),
    );
  }

  // A short reason for snackbars, e.g. "permission-denied".
  String _reason(Object e) => e is FirebaseException ? e.code : '$e';

  Future<void> _setRole(String uid, UserRole newRole) async {
    try {
      await context.read<AuthProvider>().updateUserRole(uid, newRole);
    } catch (e) {
      AppLogger.error('Role update failed', e);
      _showResult('Could not change role (${_reason(e)}).', success: false);
      return;
    }
    await _loadUsers();
    _showResult('Role updated to ${newRole.name}', success: true);
  }

  Future<void> _deleteUser(String uid) async {
    final userData = _allUsers.firstWhere((u) => u['uid'] == uid);
    final email = userData['email'] ?? 'unknown';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete user: $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    String? failure;
    try {
      await context.read<AuthProvider>().deleteUser(
        uid,
        deleteLocationData: () async {
          await LocationRepository().deleteAllFor(uid);
          await UserDataCleanup().deleteAllFor(uid);
        },
      );
    } catch (e) {
      AppLogger.error('Delete user failed', e);
      failure = _reason(e);
    }
    await _loadUsers();
    _showResult(
      failure == null
          ? 'User data deleted'
          : 'Delete failed ($failure). Please retry.',
      success: failure == null,
    );
  }

  static String _roleLabel(UserRole role) => switch (role) {
        UserRole.admin => 'Barangay staff',
        UserRole.driver => 'Driver',
        UserRole.user => 'Resident',
      };

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        context.read<AuthProvider>().currentUser?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.forest),
                    // Disabled mid-delete so a half-done delete is not left behind.
                    onPressed:
                        _isLoading ? null : () => context.go('/admin-dashboard'),
                  ),
                  const SizedBox(width: 10),
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.refresh_rounded,
                        size: 18, color: AppColors.inkMuted),
                    onPressed: _isLoading ? null : _loadUsers,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 0),
              child: Text(
                'Manage users',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 14),
              child: Text(
                'Change roles or remove accounts and their data.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            ),
            Expanded(child: _buildBody(isAdmin)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isAdmin) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load users: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    // Admin-only section
    if (!isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Access denied',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (await confirmLogout(context)) auth.logout();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No users found.',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      itemCount: _allUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildUserCard(_allUsers[i]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final uid = user['uid'] ?? '';
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final roleEnum = UserRole.values.firstWhere(
      (e) => e.name == user['role'],
      orElse: () => UserRole.user,
    );
    final isSelf = uid == context.read<AuthProvider>().currentUser?.uid;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              roleEnum == UserRole.admin
                  ? Icons.badge_outlined
                  : roleEnum == UserRole.driver
                      ? Icons.local_shipping_outlined
                      : Icons.person_outline,
              size: 18,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          // Admins keep their role here; changing it is done in the console.
          if (roleEnum == UserRole.admin)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Barangay staff',
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
            )
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<UserRole>(
                value: roleEnum,
                isDense: true,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(r)),
                        ))
                    .toList(),
                onChanged: (newRole) {
                  if (newRole != null && newRole != roleEnum) {
                    _setRole(uid, newRole);
                  }
                },
              ),
            ),
          // Hidden on your own row so an admin cannot lock themselves out.
          if (!isSelf)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.danger),
              onPressed: () => _deleteUser(uid),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
