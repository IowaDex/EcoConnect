import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';
import '../../route/models/route_plan.dart';
import '../../route/services/route_service.dart';
import '../widgets/driver_nav_bar.dart';
import '../../notifications/widgets/notification_bell.dart';

/// History tab: finished runs and completed pickups, newest first.
class DriverCompletedScreen extends StatelessWidget {
  const DriverCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading completed runs'));
    }

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Row(
                children: [
                  BrandWordmark(fontSize: 10.5),
                  Spacer(),
                  NotificationBell(iconSize: 19, color: AppColors.inkMuted),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<RoutePlan>>(
                stream: RouteService().watchCompletedPlans(user.uid),
                builder: (context, snapshot) {
                  final plans = snapshot.data ?? const <RoutePlan>[];
                  return StreamBuilder<List<CollectionRequest>>(
                    stream: CollectionRequestService().watchForDriver(user.uid),
                    builder: (context, requestSnapshot) {
                      final done = (requestSnapshot.data ??
                              const <CollectionRequest>[])
                          .where((r) =>
                              r.status == RequestStatus.collected ||
                              r.status == RequestStatus.completed)
                          .toList(growable: false);

                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          plans.isEmpty) {
                  return const Center(
                    child: LoadingView(label: 'Loading completed runs'),
                  );
                      }
                      if (plans.isEmpty && done.isEmpty) {
                        return const EmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Nothing completed yet',
                          message:
                              'Finished collection runs and pickups will be '
                              'listed here.',
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        children: [
                          if (plans.isNotEmpty) ...[
                            const _Label('FINISHED RUNS'),
                            const SizedBox(height: 8),
                            for (final plan in plans) ...[
                              _PlanTile(plan: plan),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (done.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const _Label('COLLECTED REQUESTS'),
                            const SizedBox(height: 8),
                            for (final request in done) ...[
                              _RequestTile(request: request),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverNavBar(currentIndex: 2),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: AppColors.inkMuted,
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});

  final RoutePlan plan;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusBadge(
                label: 'Completed',
                color: AppColors.primary,
                icon: Icons.check_rounded,
                compact: true,
              ),
              const Spacer(),
              Text(
                plan.completedAt == null
                    ? plan.date
                    : dateTimeLabel(plan.completedAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.zone,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${plan.windowLabel} · ${plan.stops.length} '
            '${plan.stops.length == 1 ? 'stop' : 'stops'}'
            '${plan.adHoc ? ' · ad-hoc' : ''}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final CollectionRequest request;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
                icon: request.status.icon,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(request.updatedAt ?? request.createdAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.requesterName} · ${request.location}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
