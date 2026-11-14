import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../services/memo_service.dart';

/// Outgoing "emails" to the district officer.
///
/// The project has no SMTP credentials, so every announcement Iswim posts is
/// recorded here — City Hall can see exactly what was sent and when, instead of
/// the app pretending a mail server exists.
class EmailLogScreen extends StatelessWidget {
  const EmailLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
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
      body: StreamBuilder<List<EmailLogEntry>>(
        stream: MemoService().watchEmailLog(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <EmailLogEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Wala pang na-email. Pag may announcement ang Iswim, '
                  'automatic itong lalabas dito para sa District Officer.',
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
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            children: [
              for (final entry in entries) ...[
                Container(
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
                          const Icon(Icons.outgoing_mail,
                              size: 14, color: AppColors.moss),
                          const SizedBox(width: 6),
                          Text(
                            'To: ${entry.to}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            entry.sentAt == null
                                ? '—'
                                : '${entry.sentAt!.month}/${entry.sentAt!.day} '
                                    '${entry.sentAt!.hour.toString().padLeft(2, '0')}:'
                                    '${entry.sentAt!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: AppColors.inkMuted,
                            ),
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
                        'ni ${entry.byName}',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.sage,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}
