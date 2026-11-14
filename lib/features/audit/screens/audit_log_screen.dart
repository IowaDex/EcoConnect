import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../models/audit_entry.dart';
import '../repositories/audit_repository.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _repository = AuditRepository();
  late Future<QuerySnapshot<Map<String, dynamic>>> _firstPage;
  final List<AuditEntry> _olderEntries = [];
  DocumentSnapshot<Map<String, dynamic>>? _olderCursor;
  bool _loadingOlder = false;
  bool _hasMore = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _firstPage = _repository.fetchLatest();
  }

  void _refresh() {
    setState(() {
      _firstPage = _repository.fetchLatest();
      _olderEntries.clear();
      _olderCursor = null;
      _loadingOlder = false;
      _hasMore = true;
      _loadError = null;
    });
  }

  Future<void> _loadOlder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> latest,
  ) async {
    if (_loadingOlder || !_hasMore || latest.isEmpty) return;
    setState(() {
      _loadingOlder = true;
      _loadError = null;
    });
    try {
      final page = await _repository.loadAfter(_olderCursor ?? latest.last);
      if (!mounted) return;
      setState(() {
        _olderEntries.addAll(page.docs.map(AuditEntry.fromDocument));
        if (page.docs.isNotEmpty) _olderCursor = page.docs.last;
        _hasMore = page.docs.length == AuditRepository.pageSize;
        _loadingOlder = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingOlder = false;
        _loadError = 'Could not load older audit entries: $error';
      });
    }
  }

  Future<void> _logout() async {
    if (!await confirmLogout(context) || !mounted) return;
    final auth = context.read<AuthProvider>();
    await context.read<LocationProvider>().endSession();
    await auth.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        title: const Text('Audit log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _firstPage,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message('Could not load audit entries: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final latest = snapshot.data!.docs;
          final entries = [
            ...latest.map(AuditEntry.fromDocument),
            ..._olderEntries.where(
              (entry) => latest.every((doc) => doc.id != entry.id),
            ),
          ];
          if (entries.isEmpty) {
            return const _Message('No audit entries have been recorded yet.');
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index < entries.length) {
                return _AuditCard(entry: entries[index]);
              }
              final canLoadMore =
                  _hasMore &&
                  (latest.length >= AuditRepository.pageSize ||
                      _olderCursor != null);
              if (!canLoadMore && !_loadingOlder && _loadError == null) {
                return const SizedBox(height: 24);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    if (_loadError != null)
                      Text(
                        _loadError!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    if (canLoadMore)
                      OutlinedButton(
                        onPressed: _loadingOlder
                            ? null
                            : () => _loadOlder(latest),
                        child: _loadingOlder
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Load older entries'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final changedFields = entry.changedFields.isEmpty
        ? 'No field names recorded'
        : entry.changedFields.join(', ');
    final timestamp = entry.at?.toLocal().toString() ?? 'Time unavailable';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.action.toUpperCase()} · ${entry.outcome}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text('Record: ${entry.documentPath}'),
            Text(
              'Actor: ${entry.actorUid ?? 'System / unknown'} '
              '(${entry.actorType})',
            ),
            const SizedBox(height: 5),
            Text(
              'Changed fields: $changedFields',
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkMuted),
        ),
      ),
    );
  }
}
