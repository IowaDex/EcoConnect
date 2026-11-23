import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That is not a valid email address.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    try {
      await MemoService().setDistrictOfficerEmail(saved);
      messenger.showSnackBar(
        const SnackBar(content: Text('District Officer email saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save the address: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
        'body':
            '${entry.body}\n\n— Posted by ${entry.byName} (Iswim) in '
            'EcoConnect, Barangay Batasan Hills.',
      }),
    );
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app is set up on this device.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// mailto: needs %20 for spaces, not the + that Uri.queryParameters uses.
  static String _encodeQuery(Map<String, String> params) => params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');

  @override
  Widget build(BuildContext context) {
    final service = MemoService();
    return StreamBuilder<String?>(
      stream: service.watchDistrictOfficerEmail(),
      builder: (context, officerSnap) {
        final officerEmail = officerSnap.data;
        return EcoPageScaffold(
          eyebrow: 'CITY HALL · OUTBOX',
          title: 'Email log',
          subtitle: 'Every message this desk sent to the district officer.',
          icon: Icons.forward_to_inbox_rounded,
          onBack: () => ecoBack(context, '/cityhall'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _OfficerCard(
                  email: officerEmail,
                  onEdit: () => _editAddress(context, officerEmail),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<EmailLogEntry>>(
                  stream: service.watchEmailLog(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const DeskEmptyQueue(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load the log',
                        message:
                            'Check the connection and open this page again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const EcoLoadingView(label: 'Loading email log');
                    }
                    final entries = snapshot.data!;
                    if (entries.isEmpty) {
                      return const DeskEmptyQueue(
                        icon: Icons.outgoing_mail,
                        title: 'Nothing to send yet',
                        message:
                            'When Iswim posts an announcement, it appears here '
                            'ready to forward to the District Officer.',
                        steps: [
                          'Iswim posts an announcement',
                          'It lands in this log',
                          'City Hall sends it by email',
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: DeskResultLine(
                            label:
                                '${entries.length} '
                                '${entries.length == 1 ? 'message' : 'messages'}',
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: EcoSpace.sm),
                            itemBuilder: (context, i) => _EntryCard(
                              entry: entries[i],
                              to: officerEmail ?? entries[i].to,
                              onSend: () =>
                                  _send(context, officerEmail, entries[i]),
                            ),
                          ),
                        ),
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

/// The saved District Officer address, editable in place.
class _OfficerCard extends StatelessWidget {
  const _OfficerCard({required this.email, required this.onEdit});

  final String? email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final set = email != null;
    return EcoCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: set
                  ? AppColors.mint
                  : AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(EcoRadius.sm),
            ),
            child: Icon(
              Icons.badge_outlined,
              size: 17,
              color: set ? AppColors.forest : AppColors.warning,
            ),
          ),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISTRICT OFFICER',
                  style: EcoType.eyebrow(context, color: AppColors.moss),
                ),
                const SizedBox(height: 3),
                Text(
                  email ?? 'Not set yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.bodyStrong(
                    context,
                    color: set ? AppColors.textDark : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: EcoSpace.sm),
          Text(
            set ? 'Change' : 'Add',
            style: EcoType.action(context, color: AppColors.primary),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: AppColors.inkMuted,
          ),
        ],
      ),
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
    return DeskRailCard(
      railColor: AppColors.moss,
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outgoing_mail, size: 13, color: AppColors.moss),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'TO $to'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.eyebrow(context, color: AppColors.moss),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sentAt == null
                    ? '—'
                    : '${sentAt.month}/${sentAt.day} '
                          '${sentAt.hour.toString().padLeft(2, '0')}:'
                          '${sentAt.minute.toString().padLeft(2, '0')}',
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.xs),
          Text(
            entry.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 5),
          Text(
            entry.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: EcoType.bodySmall(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 12,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'by ${entry.byName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
              const SizedBox(width: EcoSpace.sm),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                    textStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
