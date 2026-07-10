// APPLICATION · templates · business · attendance report. Pure Dart.
//
// A monthly attendance summary: per-employee present/absent/late/leave day
// counts, with an attendance-rate KPI. Validates that daily categories sum to
// the working-day total per row.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';

/// A single employee's attendance tally for the period.
class AttendanceRow {
  const AttendanceRow({
    required this.employeeName,
    required this.presentDays,
    required this.absentDays,
    this.employeeNameAr,
    this.lateDays = 0,
    this.leaveDays = 0,
  });
  final String employeeName;
  final String? employeeNameAr;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int leaveDays;

  int get totalDays => presentDays + absentDays + leaveDays;
  double get attendanceRate => totalDays == 0 ? 0 : presentDays / totalDays * 100;
}

/// Data for an attendance report.
class AttendanceReportData {
  const AttendanceReportData({
    required this.periodLabel,
    required this.workingDays,
    required this.rows,
    this.organizationName = '',
    this.organizationNameAr,
  });

  final String periodLabel;
  final int workingDays;
  final List<AttendanceRow> rows;
  final String organizationName;
  final String? organizationNameAr;
}

class AttendanceReportTemplate extends PdfTemplate<AttendanceReportData> {
  const AttendanceReportTemplate();

  @override
  String get id => 'attendance_report';
  @override
  String get name => 'Attendance Report';
  @override
  String get nameAr => 'تقرير الحضور والانصراف';
  @override
  String get description => 'Monthly attendance summary with attendance-rate KPI.';

  @override
  GeniusFinancialValidationResult validate(AttendanceReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    final errors = data.rows
        .where((r) => r.totalDays > data.workingDays)
        .map((r) => validator.validateGridColumn(
              rowValues: [r.presentDays.toDouble(), r.absentDays.toDouble(), r.leaveDays.toDouble()],
              providedTotal: data.workingDays.toDouble(),
              columnId: r.employeeName,
            ),)
        .where((r) => !r.isValid)
        .expand((r) => r.errors)
        .toList();
    return errors.isEmpty ? GeniusFinancialValidationResult.valid() : GeniusFinancialValidationResult.invalid(errors);
  }

  @override
  PdfDocumentDefinition build(AttendanceReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;

    final columns = ar
        ? ['الموظف', 'حاضر', 'غائب', 'متأخر', 'إجازة', 'نسبة الحضور']
        : ['Employee', 'Present', 'Absent', 'Late', 'Leave', 'Attendance %'];
    final rows = <List<String>>[
      for (final r in data.rows)
        [
          ar ? (r.employeeNameAr ?? r.employeeName) : r.employeeName,
          '${r.presentDays}',
          '${r.absentDays}',
          '${r.lateDays}',
          '${r.leaveDays}',
          '${r.attendanceRate.toStringAsFixed(1)}%',
        ],
    ];

    final avgRate = data.rows.isEmpty
        ? 0.0
        : data.rows.fold(0.0, (s, r) => s + r.attendanceRate) / data.rows.length;

    return pdfDocument()
        .metadata(title: '${ar ? 'تقرير الحضور والانصراف' : 'Attendance Report'} — ${data.periodLabel}', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? 'تقرير الحضور والانصراف' : 'Attendance Report'),
      if (data.organizationName.isNotEmpty)
        pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.keyValue([
        MapEntry(ar ? 'الفترة' : 'Period', data.periodLabel),
        MapEntry(ar ? 'أيام العمل' : 'Working Days', '${data.workingDays}'),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.infoBox(
        '${ar ? 'متوسط نسبة الحضور' : 'Average Attendance Rate'}: ${avgRate.toStringAsFixed(1)}%',
        tone: avgRate >= 90 ? 'green' : (avgRate >= 75 ? 'orange' : 'red'),
      ),
      pdf.pageNumber(),
    ]).build();
  }
}
