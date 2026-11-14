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
/// desk. Both sides can write: City Hall replies and moves the status, the
/// resident replies while the complaint is open. The thread updates live.
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
  late final Stream<Complaint?> _live = ComplaintService().watchOne(
    widget.complaint.id,
  );

  /// The role whose messages are "mine" in this sheet.
  String get _myRole => widget.canRespond ? 'cityHall' : 'resident';

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(Complaint complaint) async {
    final message = _reply.text.trim();
    if (widget.canRespond) {
      if (message.isEmpty && _status == complaint.status) {
        AppFeedback.error(context, 'Write a reply or change the status.');
        return;
      }
    } else if (message.isEmpty) {
      AppFeedback.error(context, 'Write your message first.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.canRespond) {
        await ComplaintService().respond(
          complaint: complaint,
          message: message,
          status: _status,
          byName: widget.byName,
        );
      } else {
        await ComplaintService().residentReply(
          complaint: complaint,
          message: message,
          byName: widget.byName,
        );
      }
      if (!mounted) return;
      _reply.clear();
      AppFeedback.success(
        context,
        widget.canRespond ? 'Reply sent to the resident' : 'Sent to City Hall',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => StreamBuilder<Complaint?>(
        stream: _live,
        initialData: widget.complaint,
        builder: (context, snapshot) =>
            _thread(controller, snapshot.data ?? widget.complaint),
      ),
    );
  }

  Widget _thread(ScrollController controller, Complaint complaint) {
    return ListView(
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
              style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
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
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: AppColors.primary,
              ),
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
          Text(
            widget.canRespond
                ? 'No messages yet. Reply to the resident below.'
                : 'No replies yet. City Hall will respond here, and you '
                      'can add details below.',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          )
        else
          for (final response in complaint.responses) ...[
            _ResponseBubble(
              response: response,
              isMine: response.byRole == _myRole,
            ),
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
                  child: Text(
                    status.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 14),
          _sendButton(complaint, 'Send reply'),
        ] else if (complaint.status.isOpen) ...[
          const SizedBox(height: 18),
          const SectionHeader(title: 'Reply to City Hall'),
          const SizedBox(height: 8),
          TextField(
            controller: _reply,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Your message',
              hintText: 'Add details or answer City Hall’s question',
            ),
          ),
          const SizedBox(height: 6),
          _sendButton(complaint, 'Send to City Hall'),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            'This complaint is ${complaint.status.label.toLowerCase()}, so '
            'replies are closed. File a new complaint if the problem '
            'comes back.',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }

  Widget _sendButton(Complaint complaint, String label) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: _busy ? null : () => _send(complaint),
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
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
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
  const _ResponseBubble({required this.response, required this.isMine});

  final ComplaintResponse response;

  /// Written by whoever is reading the sheet: shown on the right.
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final who = response.byRole == 'cityHall'
        ? 'City Hall (DSQC) · ${response.byName}'
        : response.byName;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? AppColors.lightGreen : Colors.white,
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
              '$who · ${timeAgo(response.at)}',
              style: const TextStyle(fontSize: 8, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
