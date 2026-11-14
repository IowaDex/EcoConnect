import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/manual.dart';
import '../services/manual_service.dart';

/// Manual library. Iswim publishes revisions here; City Hall reads and
/// acknowledges them. No other role has access.
class ManualsScreen extends StatelessWidget {
  const ManualsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(isIswim ? '/iswim' : '/cityhall'),
        ),
        title: Text(
          isIswim ? 'Manuals' : 'Manual library',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/manual-requests'),
            icon: const Icon(Icons.inbox_outlined, size: 16),
            label: const Text(
              'Requests',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      floatingActionButton: isIswim
          ? FloatingActionButton.extended(
              onPressed: () => _openCreate(context),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text(
                'New manual',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: StreamBuilder<List<Manual>>(
        stream: ManualService().watchManuals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load manuals',
              message: AppFeedback.describe(snapshot.error!),
            );
          }
          final manuals = snapshot.data ?? const <Manual>[];
          if (manuals.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No manuals yet',
              message: isIswim
                  ? 'Upload the first manual. It is sent straight to City Hall.'
                  : 'Iswim has not submitted a manual yet. You can request one.',
              actionLabel: isIswim ? 'Upload a manual' : 'Request a manual',
              onAction: () => isIswim
                  ? _openCreate(context)
                  : context.push('/manual-requests'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
            children: [
              const SectionHeader(title: 'Latest revisions'),
              const SizedBox(height: 8),
              for (final manual in manuals) ...[
                _ManualCard(manual: manual),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualForm(
        byId: user.uid,
        byName: user.displayName ?? 'Iswim',
      ),
    );
  }
}

class _ManualCard extends StatelessWidget {
  const _ManualCard({required this.manual});

  final Manual manual;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: () => context.push('/manuals/${manual.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  manual.category.icon,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manual.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${manual.category.label} · v${manual.version}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 19, color: AppColors.moss),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusBadge(
                label: manual.status.label,
                color: manual.status.color,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(manual.updatedAt ?? manual.createdAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          if (manual.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              manual.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Create the first version of a manual.
class _ManualForm extends StatefulWidget {
  const _ManualForm({required this.byId, required this.byName});

  final String byId;
  final String byName;

  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _notes = TextEditingController();

  ManualCategory _category = ManualCategory.collection;
  UploadPayload? _file;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final file = _file;
    if (file == null) {
      AppFeedback.error(context, 'Attach the manual file first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ManualService().createManual(
        title: _title.text,
        category: _category,
        summary: _summary.text,
        notes: _notes.text,
        file: file,
        byId: widget.byId,
        byName: widget.byName,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(context, 'Manual sent to City Hall');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'New manual',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This is sent directly to City Hall. District officers and the '
                'barangay are not part of this workflow.',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Manual title'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a title'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ManualCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in ManualCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label,
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summary,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Short description',
                  hintText: 'What this manual covers',
                ),
                validator: (value) => (value ?? '').trim().length < 10
                    ? 'Add a short description'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Version notes',
                  hintText: 'What changed in this revision',
                ),
              ),
              const SizedBox(height: 14),
              ImagePickerField(
                value: _file,
                onChanged: (value) => setState(() => _file = value),
                label: 'Manual file',
                helper: 'JPG, PNG or PDF · compressed automatically',
                documentMode: true,
                previewHeight: 130,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: const Text(
                    'Send to City Hall',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
