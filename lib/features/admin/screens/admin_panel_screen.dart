import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/app_logger.dart';

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
      final users = await AuthService().getAllUsers();
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
      await AuthService().updateUserRole(uid, newRole);
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
      await AuthService().deleteUser(uid);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = context.read<AuthProvider>();
    final isAdmin = authProvider.currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            // Disabled mid-delete: signing out would abort it half done.
            onPressed: _isLoading ? null : () => authProvider.logout(),
          ),
        ],
      ),
      body: _buildBody(isAdmin, colorScheme),
    );
  }

  Widget _buildBody(bool isAdmin, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Admin-only section
    if (!isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Access Denied',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Users list
          if (_allUsers.isNotEmpty)
            ..._allUsers.map(_buildUserCard)
          else
            const Text('No users found'),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final uid = user['uid'] ?? '';
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'user';
    final roleEnum = UserRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => UserRole.user,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  roleEnum == UserRole.admin
                      ? Icons.admin_panel_settings
                      : roleEnum == UserRole.driver
                      ? Icons.directions_car
                      : Icons.person,
                  color: roleEnum == UserRole.admin ? Colors.red : null,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Role selector for admins
                if (roleEnum != UserRole.admin)
                  DropdownButton<UserRole>(
                    value: roleEnum,
                    items: UserRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.name),
                      );
                    }).toList(),
                    onChanged: (newRole) {
                      if (newRole != null && newRole != roleEnum) {
                        _setRole(uid, newRole);
                      }
                    },
                  ),
                const SizedBox(width: 8),
                // Delete button; hidden on your own row so an admin can't lock themselves out
                if (uid != context.read<AuthProvider>().currentUser?.uid)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(uid),
                  ),
              ],
            ),
            const Divider(height: 24),
          ],
        ),
      ),
    );
  }
}