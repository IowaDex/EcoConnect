import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/manual.dart';
import '../services/manual_service.dart';

/// One manual: current file, complete version history, and the two role
/// actions — Iswim uploads a revision, City Hall acknowledges receipt.
class ManualDetailScreen extends StatefulWidget {
  const ManualDetailScreen({super.key, required this.manualId});

  final String manualId;

  @override
  State<ManualDetailScreen> createState() => _ManualDetailScreenState();
}

class _ManualDetailScreenState extends State<ManualDetailScreen> {
  /// Cached so a rebuild from the action sheets does not resubscribe and flash
  /// the loading state.
  late final Stream<Manual?> _manual = ManualService().watchOne(
    widget.manualId,
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;
    final isCityHall = user?.role == UserRole.cityHall;
    final fallback = switch (user?.role) {
      UserRole.iswim => '/iswim',
      UserRole.cityHall => '/cityhall',
      UserRole.admin => '/admin-dashboard',
      _ => '/user',
    };

    return StreamBuilder<Manual?>(
      stream: _manual,
      builder: (context, snapshot) {
        final manual = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        return EcoPageScaffold(
          eyebrow: isIswim
              ? 'ISWIM · MANUALS'
              : isCityHall
              ? 'CITY HALL · MANUALS'
              : 'BARANGAY · MANUALS',
          title: manual?.title ?? 'Manual',
          subtitle: manual == null
              ? null
              : '${manual.category.label} · by ${manual.createdByName}',
          onBack: () => ecoBack(context, fallback),
          actions: [
            if (manual != null) ...[
              StatusBadge(
                label: 'v${manual.version}',
                color: AppColors.primary,
                compact: true,
              ),
              const SizedBox(width: 4),
              StatusBadge(
                label: manual.status.label,
                color: manual.status.color,
                compact: true,
              ),
            ],
          ],
          body: snapshot.hasError
              ? DeskEmptyQueue(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load this manual',
                  message: AppFeedback.describe(snapshot.error!),
                )
              : waiting && manual == null
              ? const EcoLoadingView(label: 'Loading manual')
              : manual == null
              ? const DeskEmptyQueue(
                  icon: Icons.menu_book_outlined,
                  title: 'Manual not found',
                  message: 'This manual no longer exists or was withdrawn.',
                )
              : _body(
                  context,
                  manual,
                  user: user,
                  isIswim: isIswim,
                  isCityHall: isCityHall,
                ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    Manual manual, {
    required AppUser? user,
    required bool isIswim,
    required bool isCityHall,
  }) {
    final summary = manual.summary.trim();
    final notes = manual.currentNotes.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        if (summary.isNotEmpty)
          EcoCard(
            child: SelectableText(
              summary,
              style: EcoType.body(
                context,
                color: AppColors.textDark,
              ).copyWith(height: 1.7),
            ),
          ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: EcoSpace.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
            decoration: BoxDecoration(
              color: AppColors.lightGreen.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(EcoRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT CHANGED IN v${manual.version}',
                  style: EcoType.eyebrow(context, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: EcoType.bodySmall(
                    context,
                    color: AppColors.darkGreen,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
        if (manual.acknowledgedAt != null) ...[
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Received by ${manual.acknowledgedByName ?? 'City Hall'} '
                  '· ${timeAgo(manual.acknowledgedAt)}',
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: EcoSpace.md),
        _FileCard(file: manual.file),
        if (isIswim ||
            (isCityHall && manual.status != ManualStatus.acknowledged)) ...[
          const SizedBox(height: EcoSpace.md),
          SizedBox(
            height: 46,
            child: isIswim
                ? FilledButton.icon(
                    onPressed: user == null
                        ? null
                        : () => _openRevision(context, manual, user),
                    icon: const Icon(Icons.upload_file_rounded, size: 17),
                    label: const Text(
                      'Upload a new version',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EcoRadius.md),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: user == null
                        ? null
                        : () => _acknowledge(context, manual, user),
                    icon: const Icon(Icons.task_alt_rounded, size: 17),
                    label: const Text(
                      'Mark as received',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EcoRadius.md),
                      ),
                    ),
                  ),
          ),
        ],
        const SizedBox(height: EcoSpace.lg),
        const SectionLabel('VERSION HISTORY'),
        const SizedBox(height: EcoSpace.sm),
        StreamBuilder<List<ManualVersion>>(
          stream: ManualService().watchVersions(manual.id),
          builder: (context, versionSnapshot) {
            final versions = versionSnapshot.data ?? const <ManualVersion>[];
            if (versions.isEmpty) {
              return Text(
                'No versions recorded yet.',
                style: EcoType.bodySmall(context, color: AppColors.inkMuted),
              );
            }
            return Column(
              children: [
                for (final version in versions) ...[
                  _VersionTile(
                    version: version,
                    current: version.version == manual.version,
                  ),
                  const SizedBox(height: EcoSpace.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _acknowledge(
    BuildContext context,
    Manual manual,
    AppUser user,
  ) async {
    try {
      await ManualService().acknowledge(
        manual: manual,
        byName: user.displayName ?? 'City Hall',
      );
      if (context.mounted) {
        AppFeedback.success(context, 'Receipt recorded');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _openRevision(
    BuildContext context,
    Manual manual,
    AppUser user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RevisionForm(
        manual: manual,
        byId: user.uid,
        byName: user.displayName ?? 'Iswim',
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file});

  final UploadPayload? file;

  @override
  Widget build(BuildContext context) {
    final payload = file;
    if (payload == null) {
      return EcoCard(
        child: Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No file attached to this revision.',
                style: EcoType.bodySmall(context, color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    final bytes = _decode(payload);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                payload.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_outlined,
                size: 20,
                color: payload.isPdf ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodyStrong(
                        context,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      '${payload.sizeKb.toStringAsFixed(0)} KB · '
                      '${payload.isPdf ? 'PDF' : 'image'}',
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _open(context, payload),
                child: const Text(
                  'Open',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (bytes != null && !payload.isPdf) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(EcoRadius.md),
              child: Image.memory(
                bytes,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Uint8List? _decode(UploadPayload payload) {
    if (payload.isPdf) return null;
    final comma = payload.dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(payload.dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _open(BuildContext context, UploadPayload payload) async {
    final uri = Uri.parse(payload.dataUrl);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened && context.mounted) {
        AppFeedback.error(context, 'No app can open this file on this device.');
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.error(context, 'Could not open this file.');
      }
    }
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.version, required this.current});

  final ManualVersion version;

  /// The version the manual is on right now.
  final bool current;

  @override
  Widget build(BuildContext context) {
    final notes = version.notes.trim();

    return DeskRailCard(
      railColor: current ? AppColors.primary : AppColors.sage,
      padding: const EdgeInsets.fromLTRB(15, 11, 13, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? AppColors.primary : AppColors.lightGreen,
              borderRadius: BorderRadius.circular(EcoRadius.sm),
            ),
            child: Text(
              'v${version.version}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: current ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notes.isEmpty ? 'Version ${version.version}' : notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.bodySmall(
                          context,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(width: 6),
                      const StatusBadge(
                        label: 'Current',
                        color: AppColors.primary,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${version.submittedByName} · '
                  '${timeAgo(version.submittedAt)}'
                  '${version.file == null ? '' : ' · ${version.file!.fileName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionForm extends StatefulWidget {
  const _RevisionForm({
    required this.manual,
    required this.byId,
    required this.byName,
  });

  final Manual manual;
  final String byId;
  final String byName;

  @override
  State<_RevisionForm> createState() => _RevisionFormState();
}

class _RevisionFormState extends State<_RevisionForm> {
  final _notes = TextEditingController();
  UploadPayload? _file;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) {
      AppFeedback.error(context, 'Attach the revised manual file.');
      return;
    }
    setState(() => _busy = true);
    try {
      final version = await ManualService().publishVersion(
        manual: widget.manual,
        notes: _notes.text,
        file: file,
        byId: widget.byId,
        byName: widget.byName,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(context, 'Version $version sent to City Hall');
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            Text(
              'New version of ${widget.manual.title}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This becomes v${widget.manual.version + 1} and goes straight to '
              'City Hall.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What changed?',
                hintText: 'Summary of the revision',
              ),
            ),
            const SizedBox(height: 14),
            ImagePickerField(
              value: _file,
              onChanged: (value) => setState(() => _file = value),
              label: 'Revised file',
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
                  'Publish version',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
