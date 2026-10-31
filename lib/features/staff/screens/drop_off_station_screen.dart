import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/drop_off.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/recycling_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

/// Staff-side recycling station: find a resident, weigh the recyclables,
/// and credit the points to their wallet in one transaction.
class DropOffStationScreen extends StatefulWidget {
  const DropOffStationScreen({super.key});

  @override
  State<DropOffStationScreen> createState() => _DropOffStationScreenState();
}

class _DropOffStationScreenState extends State<DropOffStationScreen> {
  final _service = RecyclingService();
  final _queryController = TextEditingController();
  final _weightController = TextEditingController();

  Map<String, dynamic>? _resident;
  RecyclableMaterial _material = RecyclableMaterial.plastic;
  double? _weight;
  bool _searching = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  int get _points {
    final weight = _weight;
    if (weight == null) return 0;
    return DropOff.pointsFor(_material, weight);
  }

  bool get _canCredit => _resident != null && _points > 0 && !_busy;

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter an account ID or email.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await _service.findResident(query);
      if (!mounted) return;
      setState(() {
        _resident = found;
        _searching = false;
        if (found == null) {
          _error = 'No resident found for “$query”.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _credit() async {
    final resident = _resident;
    final weight = _weight;
    if (resident == null || weight == null || _points <= 0) return;

    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;

    final name = (resident['name'] ?? resident['displayName'] ?? 'this resident')
        .toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Credit points?'),
        content: Text(
          '$_points points for ${weight.toStringAsFixed(2)} kg of '
          '${_material.shortLabel.toLowerCase()} will be added to $name’s '
          'wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Credit points'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final credited = await _service.recordDropOff(
        residentId: resident['uid'] as String,
        residentName: name,
        residentEmail: resident['email'] as String?,
        staffId: staff.uid,
        staffName: staff.displayName ?? 'Barangay staff',
        material: _material,
        weightKg: weight,
      );
      if (!mounted) return;
      _weightController.clear();
      setState(() {
        _weight = null;
        _busy = false;
      });
      _toast('$credited points credited to $name');
      await _refreshResident(resident['uid'] as String);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_message(e), isError: true);
    }
  }

  /// Re-reads the resident so the card shows the new balance immediately.
  Future<void> _refreshResident(String uid) async {
    try {
      final fresh = await _service.findResident(uid);
      if (mounted && fresh != null) setState(() => _resident = fresh);
    } catch (_) {
      // The credit already succeeded; a stale balance is harmless.
    }
  }

  String _message(Object error) {
    final raw = error.toString();
    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return 'Firestore rules blocked this write. Ask an admin to publish '
          'the latest rules.';
    }
    if (error is RecyclingException) return error.message;
    return raw;
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.forest,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/admin-dashboard'),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  const Icon(Icons.recycling_rounded,
                      size: 18, color: AppColors.moss),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Recycling drop-off',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Find the resident, weigh the recyclables, credit the points.',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 18),
              _StepCard(
                step: '1',
                title: 'Resident',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: 'Account ID or email',
                        hintText: 'Paste the scanned ID or type the email',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                onPressed: _search,
                                icon: const Icon(Icons.search_rounded,
                                    size: 18),
                                tooltip: 'Search resident',
                              ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    if (_resident != null) ...[
                      const SizedBox(height: 10),
                      _ResidentCard(resident: _resident!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _StepCard(
                step: '2',
                title: 'Material & weight',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final material in RecyclableMaterial.values)
                          _MaterialChip(
                            material: material,
                            selected: _material == material,
                            onTap: () => setState(() => _material = material),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (value) => setState(() {
                              _weight = double.tryParse(
                                  value.replaceAll(',', '.').trim());
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              suffixText: 'kg',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_material.pointsPerKg} pts / kg',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.moss,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PointsPreview(points: _points),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: _resident == null
                    ? 'Find a resident first'
                    : 'Credit points',
                loading: _busy,
                onPressed: _canCredit ? _credit : null,
                height: 46,
              ),
              const SizedBox(height: 22),
              const Text(
                'Recent station activity',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<DropOff>>(
                stream: _service.watchRecentDropOffs(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _EmptyActivity(
                      message: 'Could not load activity. Check that the '
                          'Firestore rules are published.',
                    );
                  }
                  final items = snapshot.data ?? const <DropOff>[];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (items.isEmpty) {
                    return const _EmptyActivity(
                      message: 'No drop-offs recorded yet today.',
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) _ActivityTile(dropOff: item),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 20,
                width: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.forest,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.resident});

  final Map<String, dynamic> resident;

  @override
  Widget build(BuildContext context) {
    final name =
        (resident['name'] ?? resident['displayName'] ?? 'Resident').toString();
    final email = (resident['email'] as String?) ?? '';
    final barangay = (resident['barangay'] as String?)?.trim();
    final points = (resident['points'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.forest.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.forest,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [if (email.isNotEmpty) email, if (barangay != null) barangay]
                      .join(' · '),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                points.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const Text(
                'points',
                style: TextStyle(fontSize: 8, color: AppColors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialChip extends StatelessWidget {
  const _MaterialChip({
    required this.material,
    required this.selected,
    required this.onTap,
  });

  final RecyclableMaterial material;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? material.color.withValues(alpha: 0.16)
              : AppColors.creamBright,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? material.color : AppColors.sage,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              material.icon,
              size: 13,
              color: selected ? material.color : AppColors.inkMuted,
            ),
            const SizedBox(width: 5),
            Text(
              material.shortLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.forest : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsPreview extends StatelessWidget {
  const _PointsPreview({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, size: 20, color: AppColors.lime),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Points to credit',
              style: TextStyle(fontSize: 10, color: Color(0xB3FFFFFF)),
            ),
          ),
          Text(
            points.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.dropOff});

  final DropOff dropOff;

  @override
  Widget build(BuildContext context) {
    final time = dropOff.createdAt;
    final stamp = time == null
        ? 'Just now'
        : '${time.hour % 12 == 0 ? 12 : time.hour % 12}:'
            '${time.minute.toString().padLeft(2, '0')}'
            '${time.hour < 12 ? ' AM' : ' PM'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: dropOff.material.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              dropOff.material.icon,
              size: 15,
              color: dropOff.material.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dropOff.residentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dropOff.weightKg.toStringAsFixed(2)} kg '
                  '${dropOff.material.shortLabel.toLowerCase()} · $stamp',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${dropOff.points}',
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

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.message});

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
