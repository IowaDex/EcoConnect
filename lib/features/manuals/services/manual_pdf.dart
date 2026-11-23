import '../../../core/utils/file_saver.dart';
import '../../../core/utils/simple_pdf.dart';
import '../../tickets/models/trip_ticket.dart';
import '../models/assignment_manual.dart';
import '../models/manual_assignment.dart';

/// Writes the one-page manual PDF for a record that already exists.
///
/// The creation form, the trip ticket a manual generates and the manuals list
/// all print the same sheet, so the export never depends on the screen that
/// happens to be open. A bulk manual prints every driver row under the title.
/// Returns false when the build has no browser download.
Future<bool> exportAssignmentManualPdf({
  required String title,
  required String driverName,
  required String plateNumber,
  required int wheelers,
  required List<String> routes,
  required List<int> days,
  required String startTime,
  required ManualRecurrence recurrence,
  required String status,
  String? requestTitle,
  List<ManualAssignment> assignments = const [],
}) async {
  final lines = <String>[
    'Collection manual',
    if (title.trim().isNotEmpty) 'Title: ${title.trim()}',
    '',
    if (assignments.length > 1) ...[
      'Bulk assignment · ${assignments.length} drivers',
      '',
      for (var i = 0; i < assignments.length; i++) ...[
        '${i + 1}. ${assignments[i].driverName} · '
            '${assignments[i].plateNumber} · '
            '${assignments[i].wheelers}-wheeler',
        '   Routes: ${assignments[i].routes.isEmpty ? '—' : assignments[i].routes.join(' / ')}',
        '   Schedule: '
            '${([...assignments[i].days]..sort()).map(manualDayLabel).join(', ')}',
        '   Start time: ${assignments[i].startTime}',
        '   Recurrence: ${assignments[i].recurrence.label}',
        '',
      ],
    ] else ...[
      'Driver: $driverName',
      'Plate number: $plateNumber',
      if (wheelers > 0) 'Truck: $wheelers-wheeler',
      'Routes: ${routes.isEmpty ? '—' : routes.join(' / ')}',
      'Schedule: ${([...days]..sort()).map(manualDayLabel).join(', ')}',
      'Start time: $startTime',
      'Recurrence: ${recurrence.label}',
      '',
    ],
    'Status: $status',
    if (requestTitle != null && requestTitle.trim().isNotEmpty)
      'Request: ${requestTitle.trim()}',
  ];
  final bytes = buildSimplePdf('EcoConnect collection manual', lines);
  return saveDataUrl(
    pdfDataUrl(bytes),
    'collection-manual-${plateNumber.replaceAll(' ', '-')}.pdf',
  );
}

/// The manual a trip ticket was generated from.
Future<bool> exportManualPdfFromTicket(TripTicket ticket) =>
    exportAssignmentManualPdf(
      title: '${ticket.code} · collection manual',
      driverName: ticket.driverName,
      plateNumber: ticket.plateNumber,
      wheelers: ticket.wheelers,
      routes: ticket.routes,
      days: ticket.days,
      startTime: ticket.windowStart,
      recurrence: ticket.recurrence,
      status: ticket.approvalPending
          ? 'Waiting for City Hall approval'
          : ticket.status.label,
    );

/// The roster entry saved in `assignment_manuals`.
Future<bool> exportManualPdfFromRecord(AssignmentManual manual) =>
    exportAssignmentManualPdf(
      title: manual.title,
      driverName: manual.driverName,
      plateNumber: manual.plateNumber,
      wheelers: manual.wheelers,
      routes: manual.routes,
      days: manual.days,
      startTime: manual.startTime,
      recurrence: manual.recurrence,
      status: manual.status.label,
      assignments: manual.assignments,
    );
