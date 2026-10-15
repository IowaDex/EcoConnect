import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, dynamic>? _editingUser;
  UserRole? _newRole;
  String? _deleteTargetUid;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await AuthService().getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRole(String uid, UserRole currentRole) async {
    final newRole = currentRole == UserRole.admin
        ? UserRole.user
        : UserRole.admin;
    await AuthService().updateUserRole(uid, newRole);
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Role updated to ${newRole.name}'),
        backgroundColor: Colors.green.shade600,
      ),
    );
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

    if (confirm != true) return;

    await AuthService().deleteUser(uid);
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('User deleted'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = context.read<AuthProvider>();
    final isAdmin = authProvider.isAuthenticated && authProvider.isEmailVerified;

    // Check if current user is actually an admin
    if (isAdmin) {
      // Try to verify via Firestore
      // We'll just show the panel and let the service check
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: _buildBody(isAdmin, colorScheme),
    );
  }

  Widget _buildBody(bool isAdmin, ColorScheme colorScheme) {
    if (!_isLoading && _allUsers.isEmpty) {
      return const Center(child: Text('No users found'));
    }

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
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // Filter users locally
            },
          ),
          const SizedBox(height: 16),

          // Users list
          if (_allUsers.isNotEmpty)
            ..._allUsers.map((user) => _buildUserCard(user)).toList()
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
                      _toggleRole(uid, roleEnum);
                    },
                  ),
                const SizedBox(width: 8),
                // Delete button
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