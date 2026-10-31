import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/incident.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/incident_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _incidentService = IncidentService();

  IncidentCategory _category = IncidentCategory.missedCollection;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = context.read<LocationProvider>();
      if (!location.hasLocation) location.getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await _incidentService.submit(
        residentId: user.uid,
        residentName: user.displayName ?? 'Resident',
        category: _category,
        description: _description.text.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Report sent to your barangay. Salamat!'),
          ),
        );
      context.go('/user');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not send report: ' + e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.forest),
                    onPressed: () => context.go('/user'),
                  ),
                  const SizedBox(width: 10),
                  const BrandWordmark(fontSize: 10.5),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Report an\nincident',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your barangay reviews every report. Attach the exact '
                        'location so the team can respond faster.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'What happened?',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in IncidentCategory.values)
                            _CategoryChip(
                              category: category,
                              selected: _category == category,
                              onTap: () => setState(() => _category = category),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _description,
                        maxLines: 4,
                        maxLength: 300,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.forest),
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Truck skipped our street this morning, bins '
                              'are still full.',
                          counterStyle: TextStyle(
                              fontSize: 9, color: AppColors.inkMuted),
                        ),
                        validator: (v) => (v == null || v.trim().length < 10)
                            ? 'Please describe the issue (at least 10 characters)'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.sage.withValues(alpha: 0.8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 16, color: AppColors.forest),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Geotag',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    location.hasLocation
                                        ? location.locationString
                                        : 'Waiting for a GPS fix…',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              location.hasLocation
                                  ? Icons.check_circle_rounded
                                  : Icons.sync_rounded,
                              size: 16,
                              color: location.hasLocation
                                  ? AppColors.moss
                                  : AppColors.inkMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Submit report',
                        loading: _submitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final IncidentCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.creamBright,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.sage,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 13,
              color: selected ? Colors.white : AppColors.forest,
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
