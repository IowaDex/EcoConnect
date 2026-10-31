import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/drop_off.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/recycling_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/brand_wordmark.dart';

/// Resident-facing view of the points earned at the barangay drop-off station.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _service = RecyclingService();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/user'),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const BrandWordmark(fontSize: 10.5),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                children: [
                  const Text(
                    'Recycling wallet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Points earned every time you drop off recyclables at the '
                    'barangay station.',
                    style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 18),
                  if (uid == null)
                    const _BalanceCard(points: 0)
                  else
                    StreamBuilder<int>(
                      stream: _service.watchResidentPoints(uid),
                      builder: (context, snapshot) {
                        return _BalanceCard(points: snapshot.data ?? 0);
                      },
                    ),
                  const SizedBox(height: 16),
                  const _RatesCard(),
                  const SizedBox(height: 22),
                  const Text(
                    'Drop-off history',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (uid == null)
                    const _EmptyHistory()
                  else
                    StreamBuilder<List<DropOff>>(
                      stream: _service.watchResidentDropOffs(uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const _EmptyHistory(
                            message: 'Could not load your history right now.',
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final items = snapshot.data ?? const <DropOff>[];
                        if (items.isEmpty) {
                          return const _EmptyHistory(
                            message: 'No drop-offs yet. Bring your recyclables '
                                'to the barangay station to start earning.',
                          );
                        }
                        return Column(
                          children: [
                            for (final item in items) _HistoryTile(item: item),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/user');
            case 1:
              context.go('/tracking');
            case 2:
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('You have no new alerts')),
                );
            case 3:
              break;
          }
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'POINTS BALANCE',
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: Color(0xB3FFFFFF),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.recycling_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                points.toString(),
                style: const TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lime,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Redeemable for barangay vouchers and partner discounts soon.',
            style: TextStyle(
              fontSize: 9.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accepted materials',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 10),
          for (final material in RecyclableMaterial.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(material.icon, size: 14, color: material.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      material.label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  Text(
                    '${material.pointsPerKg} pts/kg',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.moss,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final DropOff item;

  @override
  Widget build(BuildContext context) {
    final created = item.createdAt;
    final date = created == null
        ? 'Just now'
        : '${_months[created.month - 1]} ${created.day}, '
            '${created.hour % 12 == 0 ? 12 : created.hour % 12}:'
            '${created.minute.toString().padLeft(2, '0')}'
            '${created.hour < 12 ? ' AM' : ' PM'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: item.material.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.material.icon,
              size: 16,
              color: item.material.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.material.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.weightKg.toStringAsFixed(2)} kg · $date',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${item.points}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.moss,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    this.message = 'No drop-offs yet. Bring your recyclables to the barangay '
        'station to start earning.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 10,
          height: 1.45,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
