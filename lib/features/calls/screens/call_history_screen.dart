import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/call_log.dart';
import '../services/call_service.dart';

/// The shared call history: DSQC, the District Officer and the barangay desk
/// all read the same records. One call is one document, so the officer who
/// rang and the staff who answered see the same row.
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _search = TextEditingController();
  String _query = '';
  CallOutcome? _status;
  String? _role;
  String? _barangay;
  int _days = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CallLog> _filter(List<CallLog> logs, String uid) {
    final query = _query.trim().toLowerCase();
    final since = _days == 0
        ? null
        : DateTime.now().subtract(Duration(days: _days));
    return logs.where((log) {
      if (_status != null && log.outcome != _status) return false;
      if (_role != null && log.contactRoleFor(uid) != _role) return false;
      if (_barangay != null && log.barangay != _barangay) return false;
      if (since != null) {
        final at = log.startedAt;
        if (at == null || at.isBefore(since)) return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        log.contactFor(uid),
        log.barangay ?? '',
        log.district ?? '',
        log.incidentId ?? '',
        log.reference ?? '',
        log.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = user?.uid;
    final role = user?.role ?? UserRole.districtOfficer;
    final eyebrow = switch (role) {
      UserRole.cityHall => 'CITY HALL · CALL HISTORY',
      UserRole.admin => 'BARANGAY · CALL HISTORY',
      _ => 'DISTRICT OFFICER · CALL HISTORY',
    };

    return EcoPageScaffold(
      eyebrow: eyebrow,
      title: 'Call history',
      subtitle:
          'Every call is saved automatically when it ends, so a delay or a '
          'misunderstanding can be traced later.',
      icon: Icons.history_rounded,
      onBack: () => ecoBack(
        context,
        switch (role) {
          UserRole.cityHall => '/cityhall',
          UserRole.admin => '/admin-dashboard',
          _ => '/district-officer',
        },
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<CallLog>>(
              stream: role == UserRole.cityHall
                  ? CallService().watchAllHistory()
                  : CallService().watchHistory(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.cloud_off_rounded,
                    text: 'Could not load the call history.\n${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forest,
                      strokeWidth: 2,
                    ),
                  );
                }
                final all = snapshot.data ?? const <CallLog>[];
                if (all.isEmpty) {
                  return const _Message(
                    icon: Icons.phone_callback_outlined,
                    text:
                        'No calls yet.\nCalls you make or answer from the '
                        'dashboard will be listed here.',
                  );
                }
                final logs = _filter(all, uid);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    _summary(logs),
                    const SizedBox(height: 12),
                    _FilterBar(
                      controller: _search,
                      query: _query,
                      status: _status,
                      role: _role,
                      barangay: _barangay,
                      days: _days,
                      barangays:
                          all
                              .map((log) => log.barangay)
                              .whereType<String>()
                              .toSet()
                              .toList()
                            ..sort(),
                      onQuery: (value) => setState(() => _query = value),
                      onStatus: (value) => setState(() => _status = value),
                      onRole: (value) => setState(() => _role = value),
                      onBarangay: (value) =>
                          setState(() => _barangay = value),
                      onDays: (value) => setState(() => _days = value),
                    ),
                    const SizedBox(height: 14),
                    if (logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: _Message(
                          icon: Icons.filter_alt_off_rounded,
                          text:
                              'No call matches these filters.\nClear one of '
                              'them to see the rest of the history.',
                        ),
                      )
                    else ...[
                      for (var i = 0; i < logs.length; i++) ...[
                        _CallTile(log: logs[i], viewerUid: uid),
                        const SizedBox(height: 9),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Each entry is written when the call ends, from both '
                        'ends of the line, so the two phones share one record.',
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _summary(List<CallLog> logs) {
    final completed = logs
        .where((log) => log.outcome == CallOutcome.completed)
        .length;
    final missed = logs
        .where(
          (log) =>
              log.outcome == CallOutcome.missed ||
              log.outcome == CallOutcome.declined,
        )
        .length;
    final seconds = logs.fold<int>(0, (sum, log) => sum + log.durationSeconds);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(child: _Figure(label: 'Calls', value: '${logs.length}')),
          Expanded(
            child: _Figure(label: 'Completed', value: '$completed'),
          ),
          Expanded(child: _Figure(label: 'Missed', value: '$missed')),
          Expanded(
            child: _Figure(
              label: 'Talk time',
              value: '${(seconds / 60).ceil()}m',
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Search plus the four filters the desk asked for: status, role, barangay
/// and a date window.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.query,
    required this.status,
    required this.role,
    required this.barangay,
    required this.days,
    required this.barangays,
    required this.onQuery,
    required this.onStatus,
    required this.onRole,
    required this.onBarangay,
    required this.onDays,
  });

  final TextEditingController controller;
  final String query;
  final CallOutcome? status;
  final String? role;
  final String? barangay;
  final int days;
  final List<String> barangays;
  final ValueChanged<String> onQuery;
  final ValueChanged<CallOutcome?> onStatus;
  final ValueChanged<String?> onRole;
  final ValueChanged<String?> onBarangay;
  final ValueChanged<int> onDays;

  static const _windows = <int, String>{
    0: 'All time',
    1: 'Today',
    7: 'Last 7 days',
    30: 'Last 30 days',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onQuery,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textDark),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search a name, barangay or incident',
            hintStyle: const TextStyle(
              fontSize: 10.5,
              color: AppColors.inkMuted,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 17,
              color: AppColors.inkMuted,
            ),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 15),
                    onPressed: () {
                      controller.clear();
                      onQuery('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EcoRadius.md),
              borderSide: const BorderSide(color: AppColors.sage),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EcoRadius.md),
              borderSide: const BorderSide(color: AppColors.sage),
            ),
          ),
        ),
        const SizedBox(height: 9),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'All statuses',
                selected: status == null,
                onTap: () => onStatus(null),
              ),
              for (final outcome in CallOutcome.values) ...[
                const SizedBox(width: 6),
                _Chip(
                  label: outcome.label,
                  selected: status == outcome,
                  onTap: () => onStatus(status == outcome ? null : outcome),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _Picker<String>(
                value: role,
                hint: 'Any role',
                items: const {
                  'districtOfficer': 'District Officer',
                  'admin': 'Barangay staff',
                  'cityHall': 'City Hall · DSQC',
                },
                onChanged: onRole,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _Picker<String>(
                value: barangay,
                hint: 'Any barangay',
                items: {
                  for (final area in barangays) area: area,
                },
                onChanged: onBarangay,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _Picker<int>(
          value: days == 0 ? null : days,
          hint: 'All time',
          items: {
            for (final entry in _windows.entries)
              if (entry.key != 0) entry.key: entry.value,
          },
          onChanged: (value) => onDays(value ?? 0),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.sage,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    // A value that is no longer offered (a barangay with no calls left after a
    // filter change) would make DropdownButton assert, so fall back to the
    // hint instead.
    final selected = value != null && items.containsKey(value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isDense: true,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          items: [
            for (final entry in items.entries)
              DropdownMenuItem<T>(
                value: entry.key,
                child: Text(
                  entry.value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.log, required this.viewerUid});

  final CallLog log;
  final String viewerUid;

  @override
  Widget build(BuildContext context) {
    final outgoing = log.isOutgoing(viewerUid);
    final contact = log.contactFor(viewerUid);
    final role = log.contactRoleFor(viewerUid);
    final missed =
        log.outcome == CallOutcome.missed ||
        log.outcome == CallOutcome.declined;
    final tone = missed
        ? AppColors.error
        : log.outcome == CallOutcome.completed
        ? AppColors.forest
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
              size: 17,
              color: tone,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    _OutcomePill(outcome: log.outcome, tone: tone),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_roleLabel(role)} · ${outgoing ? 'Outgoing' : 'Incoming'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _Meta(
                      icon: Icons.schedule_rounded,
                      text: dateTimeLabel(log.startedAt),
                    ),
                    _Meta(
                      icon: Icons.timer_outlined,
                      text: log.connected
                          ? _duration(log.durationSeconds)
                          : 'No connection',
                    ),
                    if (log.reference != null)
                      _Meta(
                        icon: Icons.qr_code_2_rounded,
                        text: log.reference!,
                      ),
                    if (log.incidentId != null)
                      _Meta(
                        icon: Icons.sos_rounded,
                        text: log.incidentId!.toUpperCase(),
                      ),
                    if (log.barangay != null)
                      _Meta(
                        icon: Icons.place_outlined,
                        text: log.barangay!,
                      ),
                    if (log.district != null)
                      _Meta(
                        icon: Icons.map_outlined,
                        text: log.district!,
                      ),
                    _Meta(
                      icon: Icons.tag_rounded,
                      text: log.id.length > 8
                          ? 'Call ${log.id.substring(0, 8)}'
                          : 'Call ${log.id}',
                    ),
                    if (log.hasRecording)
                      const _Meta(
                        icon: Icons.graphic_eq_rounded,
                        text: 'Recording attached',
                      ),
                  ],
                ),
                if (log.failureReason != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    log.failureReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.35,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({required this.outcome, required this.tone});

  final CallOutcome outcome;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        outcome.label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.inkMuted),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: EmptyState(
          icon: icon,
          title: 'Call history',
          message: text,
        ),
      ),
    );
  }
}

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes == 0) return '${rest}s';
  return '${minutes}m ${rest.toString().padLeft(2, '0')}s';
}

String _roleLabel(String role) => switch (role) {
  'cityHall' => 'City Hall · DSQC',
  'districtOfficer' => 'District Officer',
  'admin' => 'Barangay staff',
  'iswim' => 'Iswim',
  _ => 'EcoConnect',
};
