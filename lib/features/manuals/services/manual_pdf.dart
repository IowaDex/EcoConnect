import '../../../core/utils/file_saver.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/simple_pdf.dart';
import '../../tickets/models/trip_ticket.dart';
import '../models/assignment_manual.dart';
import '../models/manual_assignment.dart';
import 'assignment_manual_service.dart';

/// Writes the one-page manual PDF for a record that already exists.
///
/// The creation form, the trip ticket a manual generates and the manuals list
/// all print the same sheet, so the export never depends on the screen that
/// happens to be open. A bulk manual prints every driver row under the title.
/// Returns false when the file could not be handed to the device.
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
  DateTime? validFrom,
  List<ManualAssignment> assignments = const [],
}) async {
  final lines = assignmentManualPdfLines(
    title: title,
    driverName: driverName,
    plateNumber: plateNumber,
    wheelers: wheelers,
    routes: routes,
    days: days,
    startTime: startTime,
    recurrence: recurrence,
    status: status,
    requestTitle: requestTitle,
    validFrom: validFrom,
    assignments: assignments,
  );
  final bytes = buildSimplePdf(manualPdfHeading, lines);
  return saveDataUrl(
    pdfDataUrl(bytes),
    'collection-manual-${plateNumber.replaceAll(' ', '-')}.pdf',
  );
}

/// Saves a one-page PDF from [lines] the caller already built.
///
/// The creation form uses this so the sheet it previews before submitting is
/// written by the same code as the file it downloads.
Future<bool> exportManualPdfLines(
  List<String> lines, {
  required String fileName,
}) {
  final bytes = buildSimplePdf(manualPdfHeading, lines);
  return saveDataUrl(pdfDataUrl(bytes), fileName);
}

/// The heading printed at the top of the manual PDF.
const manualPdfHeading = 'EcoConnect collection manual';

/// The text on the one-page manual PDF.
///
/// Shared by the export and the on-screen preview, so what the officer checks
/// before submitting is exactly what City Hall receives.
List<String> assignmentManualPdfLines({
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
  DateTime? validFrom,
  List<ManualAssignment> assignments = const [],
}) {
  final from = validFrom ?? DateTime.now();
  String valid(ManualRecurrence repeat) =>
      dateLabel(manualValidUntil(recurrence: repeat, from: from));

  return [
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
        '   Recurrence: ${assignments[i].recurrence.label} · valid until '
            '${valid(assignments[i].recurrence)}',
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
      'Valid until: ${valid(recurrence)}',
      '',
    ],
    'Status: $status',
    if (requestTitle != null && requestTitle.trim().isNotEmpty)
      'Request: ${requestTitle.trim()}',
  ];
}

/// The manual a trip ticket was generated from.
///
/// The ticket names one driver; the manual holds the whole roster, so the
/// export reads the roster back and prints every row.
Future<bool> exportManualPdfFromTicket(TripTicket ticket) async {
  final id = ticket.assignmentId;
  final manual = id == null || id.isEmpty
      ? null
      : await AssignmentManualService().findOne(id);
  return exportAssignmentManualPdf(
    title: manual?.title ?? '${ticket.code} · collection manual',
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
    validFrom: manual?.approvedAt ?? manual?.createdAt ?? ticket.createdAt,
    assignments: manual?.assignments ?? const [],
  );
}

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
      validFrom: manual.approvedAt ?? manual.createdAt,
      assignments: manual.assignments,
    );
