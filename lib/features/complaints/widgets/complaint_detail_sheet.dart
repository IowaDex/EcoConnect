import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

/// Shared complaint thread used by the resident tracker and the City Hall
/// desk. Only the desk gets the reply composer.
class ComplaintDetailSheet extends StatefulWidget {
  const ComplaintDetailSheet({
    super.key,
    required this.complaint,
    required this.canRespond,
    required this.byName,
  });

  final Complaint complaint;
  final bool canRespond;
  final String byName;

  @override
  State<ComplaintDetailSheet> createState() => _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState extends State<ComplaintDetailSheet> {
  final _reply = TextEditingController();
  late ComplaintStatus _status = widget.complaint.status;
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _reply.text.trim();
    if (message.isEmpty && _status == widget.complaint.status) {
      AppFeedback.error(context, 'Write a reply or change the status.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ComplaintService().respond(
        complaint: widget.complaint,
        message: message,
        status: _status,
        byName: widget.byName,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(context, 'Reply sent to the resident');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Row(
            children: [
              StatusBadge(
                label: complaint.status.label,
                color: complaint.status.color,
              ),
              const SizedBox(width: 6),
              StatusBadge(
                label: complaint.referenceNo,
                color: AppColors.moss,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(complaint.createdAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            complaint.title,
            style: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${complaint.category.label} · ${complaint.residentName}'
            '${complaint.residentBarangay == null ? '' : ' · ${complaint.residentBarangay}'}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          if (complaint.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: complaint.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _bytes(complaint.images[i].dataUrl),
                    width: 160,
                    height: 130,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            complaint.description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.65,
              color: AppColors.textDark,
            ),
          ),
          if (complaint.location?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    complaint.location!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const SectionHeader(title: 'Conversation'),
          const SizedBox(height: 8),
          if (complaint.responses.isEmpty)
            const Text(
              'No replies yet. City Hall will respond here.',
              style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
            )
          else
            for (final response in complaint.responses) ...[
              _ResponseBubble(response: response),
              const SizedBox(height: 8),
            ],
          if (widget.canRespond) ...[
            const SizedBox(height: 18),
            const SectionHeader(title: 'City Hall reply'),
            const SizedBox(height: 8),
            TextField(
              controller: _reply,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message to the resident',
                hintText: 'Explain what was done or what happens next',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ComplaintStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Update status'),
              items: [
                for (final status in ComplaintStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.label,
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text(
                  'Send reply',
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
          ],
        ],
      ),
    );
  }

  static Uint8List _bytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return Uint8List(0);
    return base64Decode(dataUrl.substring(comma + 1));
  }
}

class _ResponseBubble extends StatelessWidget {
  const _ResponseBubble({required this.response});

  final ComplaintResponse response;

  @override
  Widget build(BuildContext context) {
    final fromCityHall = response.byRole == 'cityHall';
    return Align(
      alignment: fromCityHall ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fromCityHall ? Colors.white : AppColors.lightGreen,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              response.message,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.55,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${response.byName} · ${timeAgo(response.at)}',
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
