import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';
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
    return EcoPageScaffold(
      eyebrow: 'AUDIT · READ ONLY',
      title: 'Audit log',
      subtitle:
          'Every change recorded against a Firestore document, newest first.',
      onBack: () => ecoBack(context, '/admin-dashboard'),
      actions: [
        EcoIconAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onTap: _refresh,
        ),
        EcoIconAction(
          icon: Icons.logout_rounded,
          tooltip: 'Log out',
          onTap: _logout,
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
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

    return EcoCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 7,
                width: 7,
                decoration: BoxDecoration(
                  color: entry.outcome.toLowerCase().contains('fail')
                      ? AppColors.error
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${entry.action.toUpperCase()} · ${entry.outcome}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timestamp,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Record: ${entry.documentPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Actor: ${entry.actorUid ?? 'System / unknown'} '
            '(${entry.actorType})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Changed fields: $changedFields',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
        ],
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
