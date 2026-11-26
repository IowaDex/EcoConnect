import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../../manuals/models/assignment_manual.dart';
import '../../manuals/models/manual_assignment.dart';
import '../../manuals/services/assignment_manual_service.dart';
import '../../manuals/services/manual_pdf.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/signature_sheet.dart';

/// One trip ticket, end to end: what was issued, what the driver did, and the
/// three signatures that close it.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    this.autoSign = false,
  });

  final String ticketId;

  /// Opens the signature sheet as soon as the ticket loads, when the signed-in
  /// desk is the one the ticket is waiting for. Used by the City Hall desk's
  /// "Sign" button on a card.
  final bool autoSign;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with WidgetsBindingObserver {
  final _service = TicketService();

  /// One listener for the whole page.
  ///
  /// Building the stream inline meant every rebuild tore the Firestore
  /// listener down and put a new one up, and a new listener answers from the
  /// local cache before the server. A ticket signed on another desk could
  /// therefore sit on "waiting for City Hall" while the page kept resetting to
  /// the cached copy.
  late Stream<TripTicket?> _stream = _service.watchOne(widget.ticketId);

  bool _busy = false;
  bool _autoSignHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A hidden browser tab stops draining the Firestore channel, so a
    // signature that landed while this page was in the background never
    // reaches it. Re-reading on resume is what makes the other desk's
    // approval show up without a page reload.
    if (state == AppLifecycleState.resumed && mounted) _reload();
  }

  void _reload() {
    setState(() => _stream = _service.watchOne(widget.ticketId));
  }

  String _format(DateTime? time) {
    if (time == null) return '—';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${time.month}/${time.day} $h:$m';
  }

  /// Rebuilds the manual sheet from the ticket, so the PDF can be printed at
  /// any point in its life instead of only while it is being created.
  Future<void> _exportPdf(TripTicket ticket) async {
    final saved = await exportManualPdfFromTicket(ticket);
    if (!mounted) return;
    if (saved) {
      AppFeedback.success(context, 'Manual PDF generated');
    } else {
      AppFeedback.error(
        context,
        'PDF download is only available in the browser build.',
      );
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(success), backgroundColor: AppColors.forest),
          );
      }
    } on TicketException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not save: $e'),
              backgroundColor: AppColors.error,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final user = context.read<AuthProvider>().currentUser;
    final reason = await _reasonDialog(
      title: 'Decline this ticket?',
      label: 'Why are you declining it?',
      hint: 'e.g. the truck is broken, no crew with me',
      action: 'Decline',
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _service.decline(
        widget.ticketId,
        reason,
        byUid: user?.uid ?? '',
        byName: user?.displayName ?? 'Driver',
      ),
      'Ticket declined — Iswim will be notified',
    );
  }

  Future<void> _returnForRevision() async {
    final user = context.read<AuthProvider>().currentUser;
    final reason = await _reasonDialog(
      title: 'Return to driver?',
      label: 'What needs to be corrected?',
      hint: 'e.g. departure time is too short, wrong route',
      action: 'Return',
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _service.returnForRevision(
        id: widget.ticketId,
        reason: reason,
        byUid: user?.uid ?? '',
        byName: user?.displayName ?? 'Barangay',
      ),
      'Ticket returned to the driver for revision',
    );
  }

  Future<void> _rejectTicket() async {
    final user = context.read<AuthProvider>().currentUser;
    final reason = await _reasonDialog(
      title: 'Reject this ticket?',
      label: 'Reason for rejection',
      hint: 'This is recorded permanently in the audit trail.',
      action: 'Reject',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _service.reject(
        id: widget.ticketId,
        reason: reason,
        byUid: user?.uid ?? '',
        byName: user?.displayName ?? 'Barangay',
      ),
      'Ticket rejected and recorded',
    );
  }

  Future<void> _rejectManual() async {
    final user = context.read<AuthProvider>().currentUser;
    final reason = await _reasonDialog(
      title: 'Reject this manual?',
      label: 'Reason for rejection',
      hint: 'Iswim sees this reason and can correct the manual.',
      action: 'Reject manual',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _service.rejectManual(
        ticketId: widget.ticketId,
        reason: reason,
        byUid: user?.uid ?? '',
        byName: user?.displayName ?? 'City Hall',
      ),
      'Manual rejected — Iswim was told why',
    );
  }

  Future<void> _resubmit() async {
    final user = context.read<AuthProvider>().currentUser;
    final note = await _reasonDialog(
      title: 'Resubmit ticket?',
      label: 'What did you correct?',
      hint: 'Optional note for the barangay',
      action: 'Resubmit',
      required: false,
    );
    if (note == null || !mounted) return;
    await _run(
      () => _service.resubmit(
        id: widget.ticketId,
        byUid: user?.uid ?? '',
        byName: user?.displayName ?? 'Driver',
        note: note.trim().isEmpty ? 'Corrected and resubmitted' : note,
      ),
      'Ticket resubmitted to the barangay',
    );
  }

  Future<String?> _reasonDialog({
    required String title,
    required String label,
    required String hint,
    required String action,
    bool danger = false,
    bool required = true,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _sign(TripTicket ticket, TicketStatusSigner signer) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final image = await showSignatureSheet(context, signerLabel: signer.label);
    if (image == null || !mounted) return;

    await _run(
      () => _service.sign(
        id: ticket.id,
        signer: signer,
        uid: user.uid,
        name: user.displayName ?? signer.label,
        image: image,
      ),
      ticket.approvalPending && signer == TicketStatusSigner.cityHall
          ? 'Manual approved — the trip ticket is now valid'
          : 'Signed — automatically forwarded to the next signer',
    );
  }

  Future<void> _completeAssignment() async {
    final user = context.read<AuthProvider>().currentUser;
    await _run(
      () => _service.completeAssignment(
        widget.ticketId,
        byUid: user?.uid ?? '',
        byName: user?.displayName ?? 'Driver',
      ),
      'Run marked complete',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return EcoPageScaffold(
      eyebrow: 'TRIP TICKET',
      title: 'Trip ticket',
      subtitle: 'The paper trail for one collection run.',
      onBack: () => ecoBack(context, '/driver-tickets'),
      body: StreamBuilder<TripTicket?>(
        stream: _stream,
        builder: (context, snapshot) {
          final ticket = snapshot.data;
          if (snapshot.hasError) {
            return _TicketError(onRetry: _reload);
          }
          if (ticket == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final isDriver = ticket.driverId == user?.uid;
          final expected = ticket.awaitingSignature;
          final mySigner = switch (user?.role) {
            UserRole.admin => TicketStatusSigner.barangay,
            UserRole.iswim => TicketStatusSigner.iswim,
            UserRole.cityHall => TicketStatusSigner.cityHall,
            _ => null,
          };
          final canSign = mySigner != null && expected == mySigner;

          // Arriving from a desk card's "Sign" button: open the sheet once,
          // after the first frame so the page is already mounted.
          if (widget.autoSign && canSign && !_autoSignHandled) {
            _autoSignHandled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _sign(ticket, mySigner);
            });
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _Header(ticket: ticket),
                  const SizedBox(height: 14),
                  if (ticket.isAssignment) ...[
                    _ManualSection(ticket: ticket),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _exportPdf(ticket),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Export manual PDF',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          side: const BorderSide(color: AppColors.sage),
                        ),
                      ),
                    ),
                    // A rejected manual is Iswim's to fix: City Hall sent it
                    // back with a reason, so the roster reopens in the editor
                    // and goes out again from there.
                    if (ticket.status == TicketStatus.rejected &&
                        (ticket.assignmentId ?? '').isNotEmpty &&
                        user?.role == UserRole.iswim) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: () => context.push(
                            '/assignment-manuals/new'
                            '?editId=${ticket.assignmentId}',
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text(
                            'Edit & resubmit manual',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ] else
                    _Details(ticket: ticket),
                  const SizedBox(height: 14),
                  _Timeline(ticket: ticket, format: _format),
                  const SizedBox(height: 14),
                  _Signatures(ticket: ticket, format: _format),
                  const SizedBox(height: 14),
                  _AuditTrail(ticket: ticket, format: _format),
                  const SizedBox(height: 18),
                  if (isDriver && ticket.needsRevision && !_busy) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Text(
                        'Returned by the barangay: '
                        '${ticket.revisionReason ?? 'Please correct the trip details.'}',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _resubmit,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Resubmit corrected ticket',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                  if (user?.role == UserRole.admin &&
                      ticket.status == TicketStatus.submitted &&
                      !_busy) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _returnForRevision,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.warning,
                                side: const BorderSide(
                                  color: AppColors.warning,
                                ),
                                textStyle: const TextStyle(fontSize: 10.5),
                              ),
                              child: const Text('Return for revision'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _rejectTicket,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                textStyle: const TextStyle(fontSize: 10.5),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (user?.role == UserRole.iswim &&
                      ticket.status == TicketStatus.barangaySigned &&
                      !_busy) ...[
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _rejectTicket,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Reject after barangay approval'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (isDriver && ticket.needsDriver && !_busy) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: _decline,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 46,
                            child: FilledButton(
                              onPressed: () => _run(
                                () => _service.accept(
                                  ticket.id,
                                  byUid: user?.uid ?? '',
                                  byName: user?.displayName ?? 'Driver',
                                ),
                                'Ticket accepted — you can start the trip',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.forest,
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Accept ticket'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isDriver && ticket.canStartTrip) ...[
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/driver'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Go to trip dashboard'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isDriver && ticket.canCompleteAssignment && !_busy) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _completeAssignment,
                        icon: const Icon(Icons.task_alt_rounded, size: 18),
                        label: const Text(
                          'Mark run as completed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                  if (user?.role == UserRole.cityHall &&
                      ticket.approvalPending &&
                      !_busy) ...[
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _rejectManual,
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text(
                          'Reject manual',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canSign) ...[
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _sign(ticket, mySigner),
                        icon: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.draw_rounded, size: 18),
                        label: Text(
                          ticket.approvalPending
                              ? 'Approve manual as City Hall'
                              : 'Sign as ${mySigner.label}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                  if (expected != null && !canSign) ...[
                    Text(
                      'Waiting for the ${expected.label} signature.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                  if (ticket.status == TicketStatus.completed)
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              ticket.isAssignment
                                  ? 'This run is complete. The approved schedule '
                                        'stays available to the barangay and '
                                        'residents.'
                                  : 'All three signatures are complete. The '
                                        'barangay and City Hall each have a signed '
                                        'copy.',
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.45,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (ticket.approvalPending && user?.role != UserRole.cityHall)
                Positioned.fill(child: _ApprovalOverlay(ticket: ticket)),
            ],
          );
        },
      ),
    );
  }
}

/// The collection manual this trip ticket belongs to.
///
/// A bulk manual generates one trip ticket per driver, but the roster is the
/// document City Hall signs and the crew actually runs, so this page lists
/// every driver on it with the areas each one was assigned — not just the row
/// that was opened. When the roster cannot be read (a resident or a crew
/// member), the opened row's own details stand in for it.
class _ManualSection extends StatefulWidget {
  const _ManualSection({required this.ticket});

  final TripTicket ticket;

  @override
  State<_ManualSection> createState() => _ManualSectionState();
}

class _ManualSectionState extends State<_ManualSection> {
  Stream<AssignmentManual?>? _stream;

  @override
  void initState() {
    super.initState();
    final id = widget.ticket.assignmentId;
    if (id != null && id.isNotEmpty) {
      _stream = AssignmentManualService().watchOne(id);
    }
  }

  /// The ticket's position in the roster, or -1 when it cannot be matched.
  int _rowIndex(List<ManualAssignment> rows) {
    final id = widget.ticket.driverId.trim();
    if (id.isNotEmpty) {
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].driverId == id) return i;
      }
    }
    final name = widget.ticket.driverName.trim().toLowerCase();
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].driverName.trim().toLowerCase() == name) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return _AssignmentDetails(ticket: widget.ticket);

    return StreamBuilder<AssignmentManual?>(
      stream: stream,
      builder: (context, snapshot) {
        final manual = snapshot.data;
        // A resident or a crew member may not be allowed to read the roster;
        // the row's own details stand in instead of an error.
        if (manual == null) return _AssignmentDetails(ticket: widget.ticket);

        final rows = manual.allAssignments;
        final index = _rowIndex(rows);
        // Every driver on the manual belongs on this page, whichever desk is
        // reading it. City Hall signs the roster as one document, so there the
        // opened row is not singled out — a green "this ticket" mark reads as
        // "sign this one driver", which is the one thing the desk must not do.
        final highlightCurrent =
            context.watch<AuthProvider>().currentUser?.role != UserRole.cityHall;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ManualStatusStrip(
              manual: manual,
              index: index,
              total: rows.length,
            ),
            const SizedBox(height: 10),
            _ManualRoster(
              rows: rows,
              current: index,
              highlightCurrent: highlightCurrent,
            ),
          ],
        );
      },
    );
  }
}

/// Which manual this row belongs to, and where that manual stands.
///
/// A bulk manual generates one trip ticket per driver, so the ticket alone
/// cannot tell Iswim whether the schedule being looked at is the one City Hall
/// has already signed. Naming the manual and the row makes a still-pending row
/// of a different manual obvious instead of looking like a missed approval.
class _ManualStatusStrip extends StatelessWidget {
  const _ManualStatusStrip({
    required this.manual,
    required this.index,
    required this.total,
  });

  final AssignmentManual manual;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final approved = manual.isApproved;
    final rejected = manual.isRejected;
    final position = index >= 0 && total > 1
        ? 'Row ${index + 1} of $total · '
        : '';
    final accent = rejected
        ? AppColors.error
        : approved
        ? AppColors.primary
        : AppColors.warning;
    final reason = (manual.rejectionReason ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: approved ? AppColors.mint : AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected
                ? Icons.report_gmailerrorred_rounded
                : approved
                ? Icons.assignment_turned_in_outlined
                : Icons.assignment_outlined,
            size: 15,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manual.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$position${manual.status.label}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
                if (rejected && reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: $reason',
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every driver on the manual, with the areas each one covers.
///
/// On the desks that dispatch, the opened row is numbered in solid green and
/// carries a "This ticket" badge, so the officer can see which driver's page
/// they are on without losing the rest of the roster. City Hall sees the same
/// list without that mark.
class _ManualRoster extends StatelessWidget {
  const _ManualRoster({
    required this.rows,
    required this.current,
    this.highlightCurrent = true,
  });

  final List<ManualAssignment> rows;
  final int current;

  /// False at City Hall, where the roster is signed as one document and no
  /// single row should look like the one being approved.
  final bool highlightCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
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
              const Icon(
                Icons.groups_rounded,
                size: 14,
                color: AppColors.moss,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Drivers on this manual',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.sage),
                ),
                child: Text(
                  '${rows.length}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            _RosterRow(
              row: rows[i],
              position: i + 1,
              isCurrent: highlightCurrent && i == current,
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.row,
    required this.position,
    required this.isCurrent,
    required this.showDivider,
  });

  final ManualAssignment row;
  final int position;
  final bool isCurrent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final days = ([...row.days]..sort()).map(manualDayLabel).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.sage, width: 0.7),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.forest : AppColors.cream,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$position',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: isCurrent ? Colors.white : AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'This ticket',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.plateNumber} · ${row.wheelers}-wheeler',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.routes.isEmpty ? 'No area set' : row.routesLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${days.isEmpty ? 'No day set' : days} · ${row.startTime} · '
                  '${row.recurrence.label}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
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

/// Shown instead of an endless spinner when the ticket listener fails, so a
/// dropped connection cannot look like a ticket that is still pending.
class _TicketError extends StatelessWidget {
  const _TicketError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 28,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: 10),
            const Text(
              'This ticket could not be loaded.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Check the connection, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final TripTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ticket.code,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ticket.waveLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                ticket.approvalPending
                    ? 'Waiting for City Hall'
                    : ticket.status.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket.plateNumber,
            style: const TextStyle(
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ticket.wheelers}-wheeler · ${ticket.driverName}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xD9FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.ticket});

  final TripTicket ticket;

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
          _row(Icons.route_rounded, 'Ruta', ticket.route),
          _row(Icons.place_outlined, 'Zone', ticket.zone),
          _row(
            Icons.event_rounded,
            'Petsa',
            '${ticket.date} · ${ticket.windowLabel}',
          ),
          if (ticket.notes.trim().isNotEmpty)
            _row(Icons.sticky_note_2_outlined, 'Notes', ticket.notes),
          if ((ticket.declineReason ?? '').trim().isNotEmpty)
            _row(Icons.block_rounded, 'Decline reason', ticket.declineReason!),
          if ((ticket.revisionReason ?? '').trim().isNotEmpty)
            _row(
              Icons.edit_note_rounded,
              'Revision reason',
              ticket.revisionReason!,
            ),
          if ((ticket.rejectionReason ?? '').trim().isNotEmpty)
            _row(
              Icons.gpp_bad_outlined,
              'Rejection reason',
              ticket.rejectionReason!,
            ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.moss),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentDetails extends StatelessWidget {
  const _AssignmentDetails({required this.ticket});

  final TripTicket ticket;

  @override
  Widget build(BuildContext context) {
    final days = ([...ticket.days]..sort()).map(manualDayLabel).join(', ');
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
          _row(Icons.person_pin_circle_rounded, 'Driver', ticket.driverName),
          _row(
            Icons.local_shipping_rounded,
            'Plate number',
            '${ticket.plateNumber} · ${ticket.wheelers}-wheeler',
          ),
          _row(
            Icons.route_rounded,
            'Routes',
            ticket.routes.isEmpty ? ticket.route : ticket.routes.join('\n'),
          ),
          _row(Icons.schedule_rounded, 'Start time', ticket.windowStart),
          _row(Icons.event_repeat_rounded, 'Schedule', days),
          _row(Icons.autorenew_rounded, 'Repeats', ticket.recurrence.label),
          if (ticket.notes.trim().isNotEmpty)
            _row(Icons.sticky_note_2_outlined, 'Notes', ticket.notes),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.moss),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The translucent cover that keeps a freshly submitted manual from reading as
/// a valid trip ticket. City Hall sees through it (it is the desk that signs);
/// every other role sees the waiting state instead.
class _ApprovalOverlay extends StatelessWidget {
  const _ApprovalOverlay({required this.ticket});

  final TripTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 34),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 24,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Waiting for City Hall\'s approval',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The manual was submitted by ISWIM. This trip ticket becomes '
                'valid once the DSQC signs it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ticket.code,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.moss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.ticket, required this.format});

  final TripTicket ticket;
  final String Function(DateTime?) format;

  @override
  Widget build(BuildContext context) {
    final steps = ticket.isAssignment
        ? <({String label, DateTime? time, bool done})>[
            (
              label: 'Manual issued by Iswim',
              time: ticket.createdAt,
              done: ticket.createdAt != null,
            ),
            (
              label: 'City Hall approval',
              time: ticket.signatureFor(TicketStatusSigner.cityHall)?.signedAt,
              done:
                  ticket.signatureFor(TicketStatusSigner.cityHall)?.isPresent ??
                  false,
            ),
            (
              label: 'Run completed by driver',
              time: ticket.completedAt,
              done: ticket.status == TicketStatus.completed,
            ),
          ]
        : <({String label, DateTime? time, bool done})>[
            (
              label: 'Issued by Iswim',
              time: ticket.createdAt,
              done: ticket.createdAt != null,
            ),
            (
              label: 'Received by driver',
              time: ticket.acceptedAt,
              done: ticket.acceptedAt != null,
            ),
            (
              label: 'Route completed',
              time: ticket.submittedAt,
              done: ticket.submittedAt != null,
            ),
            (
              label: 'Barangay signature',
              time: ticket.signatureFor(TicketStatusSigner.barangay)?.signedAt,
              done:
                  ticket.signatureFor(TicketStatusSigner.barangay)?.isPresent ??
                  false,
            ),
            (
              label: 'Iswim signature',
              time: ticket.signatureFor(TicketStatusSigner.iswim)?.signedAt,
              done:
                  ticket.signatureFor(TicketStatusSigner.iswim)?.isPresent ??
                  false,
            ),
            (
              label: 'City Hall signature',
              time: ticket.signatureFor(TicketStatusSigner.cityHall)?.signedAt,
              done:
                  ticket.signatureFor(TicketStatusSigner.cityHall)?.isPresent ??
                  false,
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ticket flow',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    steps[i].done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: steps[i].done ? AppColors.primary : AppColors.sage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: steps[i].done
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: steps[i].done
                            ? AppColors.textDark
                            : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Text(
                    steps[i].done ? format(steps[i].time) : '—',
                    style: const TextStyle(
                      fontSize: 10.5,
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

class _AuditTrail extends StatelessWidget {
  const _AuditTrail({required this.ticket, required this.format});

  final TripTicket ticket;
  final String Function(DateTime?) format;

  @override
  Widget build(BuildContext context) {
    if (ticket.history.isEmpty) return const SizedBox.shrink();
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
          const Text(
            'Audit trail',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in ticket.history.reversed) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    height: 7,
                    width: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.previousStatus == null
                              ? entry.status.label
                              : '${entry.previousStatus!.label} → '
                                    '${entry.status.label}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${entry.byName.isEmpty ? 'System' : entry.byName}'
                          '${entry.note.trim().isEmpty ? '' : ' · ${entry.note}'}',
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.4,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    format(entry.at),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Signatures extends StatelessWidget {
  const _Signatures({required this.ticket, required this.format});

  final TripTicket ticket;
  final String Function(DateTime?) format;

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
          const Text(
            'Signatures',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final signer
                  in ticket.isAssignment
                      ? const [TicketStatusSigner.cityHall]
                      : const [
                          TicketStatusSigner.barangay,
                          TicketStatusSigner.iswim,
                          TicketStatusSigner.cityHall,
                        ])
                Expanded(
                  child: _SignatureBox(
                    signer: signer,
                    signature: ticket.signatureFor(signer),
                    format: format,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignatureBox extends StatelessWidget {
  const _SignatureBox({
    required this.signer,
    required this.signature,
    required this.format,
  });

  final TicketStatusSigner signer;
  final TicketSignature? signature;
  final String Function(DateTime?) format;

  @override
  Widget build(BuildContext context) {
    final image = signature?.image;
    final bytes = image == null ? null : _decode(image);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Container(
            height: 62,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.sage),
            ),
            child: bytes == null
                ? Center(
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkMuted.withValues(alpha: 0.9),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            signer.label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          Text(
            signature?.isPresent == true
                ? format(signature!.signedAt)
                : 'not yet',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  static Uint8List? _decode(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}
