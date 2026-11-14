import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../services/memo_service.dart';

/// Announcements Iswim posted that go to the District Officer.
///
/// The project has no mail server (that needs the paid Blaze plan), so each
/// announcement is recorded here and City Hall sends it from its own email
/// app: "Send by email" opens a ready-to-send message to the District Officer
/// address City Hall saved.
class EmailLogScreen extends StatelessWidget {
  const EmailLogScreen({super.key});

  Future<void> _editAddress(BuildContext context, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('District Officer email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'officer@example.gov.ph',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$').hasMatch(saved)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('That is not a valid email address.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    try {
      await MemoService().setDistrictOfficerEmail(saved);
      messenger.showSnackBar(
        const SnackBar(content: Text('District Officer email saved')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not save the address: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _send(
    BuildContext context,
    String? officerEmail,
    EmailLogEntry entry,
  ) async {
    if (officerEmail == null) {
      await _editAddress(context, null);
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: officerEmail,
      query: _encodeQuery({
        'subject': '[EcoConnect · Iswim] ${entry.subject}',
        'body': '${entry.body}\n\n— Posted by ${entry.byName} (Iswim) in '
            'EcoConnect, Barangay Batasan Hills.',
      }),
    );
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No email app is set up on this device.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  /// mailto: needs %20 for spaces, not the + that Uri.queryParameters uses.
  static String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  @override
  Widget build(BuildContext context) {
    final service = MemoService();
    return StreamBuilder<String?>(
      stream: service.watchDistrictOfficerEmail(),
      builder: (context, officerSnap) {
        final officerEmail = officerSnap.data;
        return Scaffold(
          backgroundColor: AppColors.creamBright,
          appBar: AppBar(
            backgroundColor: AppColors.creamBright,
            elevation: 0,
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/cityhall');
                }
              },
            ),
            title: const Text(
              'Email log',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.sage),
                    ),
                    leading: const Icon(Icons.badge_outlined,
                        color: AppColors.forest),
                    title: const Text(
                      'District Officer email',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      officerEmail ?? 'Not set — tap to add',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: officerEmail == null
                            ? AppColors.warning
                            : AppColors.inkMuted,
                      ),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _editAddress(context, officerEmail),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<EmailLogEntry>>(
                  stream: service.watchEmailLog(),
                  builder: (context, snapshot) {
                    final entries = snapshot.data ?? const <EmailLogEntry>[];
                    if (entries.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'Nothing to send yet. When Iswim posts an '
                            'announcement, it appears here for the District '
                            'Officer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.6,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                      children: [
                        for (final entry in entries) ...[
                          _EntryCard(
                            entry: entry,
                            to: officerEmail ?? entry.to,
                            onSend: () => _send(context, officerEmail, entry),
                          ),
                          const SizedBox(height: 9),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.to,
    required this.onSend,
  });

  final EmailLogEntry entry;
  final String to;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final sentAt = entry.sentAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outgoing_mail, size: 14, color: AppColors.moss),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'To: $to',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
              Text(
                sentAt == null
                    ? '—'
                    : '${sentAt.month}/${sentAt.day} '
                        '${sentAt.hour.toString().padLeft(2, '0')}:'
                        '${sentAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.subject,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'by ${entry.byName}',
            style: const TextStyle(fontSize: 8.5, color: AppColors.sage),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: const Text('Send by email'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                textStyle: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
