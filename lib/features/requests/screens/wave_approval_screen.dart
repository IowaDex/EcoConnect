import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';

/// Wave 2 approvals: the barangay reviews first, City Hall approves.
///
/// One screen, two faces — the barangay sees requests it can pass up, City Hall
/// sees the queue it has to decide on. The resident sees the outcome on the
/// request thread either way.
class WaveApprovalScreen extends StatelessWidget {
  const WaveApprovalScreen({super.key, required this.forCityHall});

  final bool forCityHall;

  @override
  Widget build(BuildContext context) {
    final service = CollectionRequestService();

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
              context.go(forCityHall ? '/cityhall' : '/admin-dashboard');
            }
          },
        ),
        title: Text(
          forCityHall ? 'Wave 2 approvals' : 'Pass to City Hall',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<CollectionRequest>>(
        stream: service.watchAll(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <CollectionRequest>[];
          final list = forCityHall
              ? all.where((r) => r.cityHallStatus == 'pending').toList()
              : (all
                  .where((r) =>
                      r.cityHallStatus == 'none' &&
                      r.status != RequestStatus.completed &&
                      r.status != RequestStatus.rejected)
                  .toList()
                // Residents' uncollected-garbage reports are wave 2 by
                // nature, so they lead the list.
                ..sort((a, b) => (b.kind == RequestKind.uncollected ? 1 : 0)
                    .compareTo(a.kind == RequestKind.uncollected ? 1 : 0)));

          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  forCityHall
                      ? 'No requests have been passed by the barangay yet.'
                      : 'No requests are ready to pass to City Hall.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
              Text(
                '${list.length} request',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              for (final request in list) ...[
                _RequestCard(request: request, forCityHall: forCityHall),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.forCityHall});

  final CollectionRequest request;
  final bool forCityHall;

  Future<void> _pass(BuildContext context) async {
    final name = context.read<AuthProvider>().currentUser?.displayName;
    await CollectionRequestService().passToCityHall(
      request.id,
      byName: name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Passed to City Hall for approval'),
          backgroundColor: AppColors.forest,
        ),
      );
  }

  Future<void> _decide(BuildContext context, bool approve) async {
    await CollectionRequestService().cityHallDecision(
      request.id,
      approve: approve,
      note: approve ? null : 'Rejected by City Hall',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(approve ? 'Na-approve' : 'Na-reject'),
          backgroundColor: approve ? AppColors.forest : AppColors.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Wave ${request.wave}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.moss,
                ),
              ),
              const Spacer(),
              Text(
                request.status.label,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${request.requesterName} · ${request.location}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
          if (!forCityHall)
            SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: () => _pass(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.primary),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Pass to City Hall (Wave 2)'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () => _decide(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: () => _decide(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Approve'),
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
