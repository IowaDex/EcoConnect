import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/signature_sheet.dart';

/// One trip ticket, end to end: what was issued, what the driver did, and the
/// three signatures that close it.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _service = TicketService();
  bool _busy = false;

  String _format(DateTime? time) {
    if (time == null) return '—';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${time.month}/${time.day} $h:$m';
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(success),
              backgroundColor: AppColors.forest,
            ),
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
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tanggihan ang ticket?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Bakit hindi mo tatanggapin?',
            hintText: 'Hal. may sira ang truck, wala akong kasama',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(() => _service.decline(widget.ticketId, reason),
        'Ticket declined — Iswim will be notified');
  }

  Future<void> _sign(TripTicket ticket, TicketStatusSigner signer) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final image = await showSignatureSheet(
      context,
      signerLabel: signer.label,
    );
    if (image == null || !mounted) return;

    await _run(
      () => _service.sign(
        id: ticket.id,
        signer: signer,
        uid: user.uid,
        name: user.displayName ?? signer.label,
        image: image,
      ),
      'Napirmahan na — automatic na napasa sa susunod',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/driver-tickets');
            }
          },
        ),
        title: const Text(
          'Trip ticket',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<TripTicket?>(
        stream: _service.watchOne(widget.ticketId),
        builder: (context, snapshot) {
          final ticket = snapshot.data;
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _Header(ticket: ticket),
              const SizedBox(height: 14),
              _Details(ticket: ticket),
              const SizedBox(height: 14),
              _Timeline(ticket: ticket, format: _format),
              const SizedBox(height: 14),
              _Signatures(ticket: ticket, format: _format),
              const SizedBox(height: 18),
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
                            () => _service.accept(ticket.id),
                            'Ticket accepted — pwede nang mag-start ng trip',
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
                    label: const Text('Pumunta sa trip dashboard'),
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
                      'Pirma bilang ${mySigner.label}',
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
                  'Naghihintay ng pirma ng ${expected.label}.',
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
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Kumpleto na ang tatlong pirma. May signed copy na '
                          'ang barangay at City Hall.',
                          style: TextStyle(
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
          );
        },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ticket.waveLabel,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                ticket.status.label,
                style: const TextStyle(
                  fontSize: 9,
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
          _row(Icons.event_rounded, 'Petsa', '${ticket.date} · ${ticket.windowLabel}'),
          if (ticket.notes.trim().isNotEmpty)
            _row(Icons.sticky_note_2_outlined, 'Notes', ticket.notes),
          if ((ticket.declineReason ?? '').trim().isNotEmpty)
            _row(Icons.block_rounded, 'Decline reason', ticket.declineReason!),
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
                fontSize: 9.5,
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

class _Timeline extends StatelessWidget {
  const _Timeline({required this.ticket, required this.format});

  final TripTicket ticket;
  final String Function(DateTime?) format;

  @override
  Widget build(BuildContext context) {
    final steps = <({String label, DateTime? time, bool done})>[
      (
        label: 'Inisyu ni Iswim',
        time: ticket.createdAt,
        done: ticket.createdAt != null,
      ),
      (
        label: 'Tinanggap ng driver',
        time: ticket.acceptedAt,
        done: ticket.acceptedAt != null,
      ),
      (
        label: 'Umikot / tapos ang ruta',
        time: ticket.submittedAt,
        done: ticket.submittedAt != null,
      ),
      (
        label: 'Pirma ng Barangay',
        time: ticket.signatureFor(TicketStatusSigner.barangay)?.signedAt,
        done: ticket.signatureFor(TicketStatusSigner.barangay)?.isPresent ??
            false,
      ),
      (
        label: 'Pirma ng Iswim',
        time: ticket.signatureFor(TicketStatusSigner.iswim)?.signedAt,
        done: ticket.signatureFor(TicketStatusSigner.iswim)?.isPresent ?? false,
      ),
      (
        label: 'Pirma ng City Hall',
        time: ticket.signatureFor(TicketStatusSigner.cityHall)?.signedAt,
        done:
            ticket.signatureFor(TicketStatusSigner.cityHall)?.isPresent ?? false,
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
            'Daloy ng ticket',
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
                    color: steps[i].done
                        ? AppColors.primary
                        : AppColors.sage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            steps[i].done ? FontWeight.w600 : FontWeight.w400,
                        color: steps[i].done
                            ? AppColors.textDark
                            : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Text(
                    steps[i].done ? format(steps[i].time) : '—',
                    style: const TextStyle(
                      fontSize: 9,
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
            'Mga pirma',
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
              for (final signer in const [
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
                        fontSize: 9,
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
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          Text(
            signature?.isPresent == true
                ? format(signature!.signedAt)
                : 'hindi pa',
            style: const TextStyle(fontSize: 8, color: AppColors.inkMuted),
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
