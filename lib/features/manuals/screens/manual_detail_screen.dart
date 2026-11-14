import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/manual.dart';
import '../services/manual_service.dart';

/// One manual: current file, complete version history, and the two role
/// actions — Iswim uploads a revision, City Hall acknowledges receipt.
class ManualDetailScreen extends StatelessWidget {
  const ManualDetailScreen({super.key, required this.manualId});

  final String manualId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isIswim = user?.role == UserRole.iswim;
    final isCityHall = user?.role == UserRole.cityHall;

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
        title: const Text(
          'Manual',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<Manual?>(
        stream: ManualService().watchOne(manualId),
        builder: (context, snapshot) {
          final manual = snapshot.data;
          if (manual == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              EcoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(
                          label: 'v${manual.version}',
                          color: AppColors.primary,
                          compact: true,
                        ),
                        const SizedBox(width: 6),
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
                    const SizedBox(height: 10),
                    Text(
                      manual.title,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${manual.category.label} · by ${manual.createdByName}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    if (manual.summary.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        manual.summary,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.6,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                    if (manual.currentNotes.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'v${manual.version} notes: ${manual.currentNotes}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            height: 1.5,
                            color: AppColors.darkGreen,
                          ),
                        ),
                      ),
                    ],
                    if (manual.acknowledgedAt != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Received by ${manual.acknowledgedByName ?? 'City Hall'} '
                              '· ${timeAgo(manual.acknowledgedAt)}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FileCard(file: manual.file),
              const SizedBox(height: 14),
              if (isIswim)
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => _openRevision(context, manual, user!),
                    icon: const Icon(Icons.upload_file_rounded, size: 17),
                    label: const Text(
                      'Upload a new version',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                    ),
                  ),
                ),
              if (isCityHall && manual.status != ManualStatus.acknowledged) ...[
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => _acknowledge(context, manual, user!),
                    icon: const Icon(Icons.task_alt_rounded, size: 17),
                    label: const Text(
                      'Mark as received',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const SectionHeader(title: 'Version history'),
              const SizedBox(height: 8),
              StreamBuilder<List<ManualVersion>>(
                stream: ManualService().watchVersions(manual.id),
                builder: (context, versionSnapshot) {
                  final versions =
                      versionSnapshot.data ?? const <ManualVersion>[];
                  if (versions.isEmpty) {
                    return const Text(
                      'No versions recorded.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final version in versions) ...[
                        _VersionTile(version: version),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
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
      return const EcoCard(
        child: Row(
          children: [
            Icon(Icons.attach_file_rounded, size: 18, color: AppColors.inkMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No file attached to this revision.',
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      '${payload.sizeKb.toStringAsFixed(0)} KB · '
                      '${payload.isPdf ? 'PDF' : 'image'}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _open(context, payload),
                child: const Text(
                  'Open',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (bytes != null && !payload.isPdf) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
  const _VersionTile({required this.version});

  final ManualVersion version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              'v${version.version}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.notes.trim().isEmpty
                      ? 'Version ${version.version}'
                      : version.notes,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${version.submittedByName} · '
                  '${timeAgo(version.submittedAt)}'
                  '${version.file == null ? '' : ' · ${version.file!.fileName}'}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AppColors.inkMuted,
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
                fontSize: 9.5,
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
    );
  }
}
