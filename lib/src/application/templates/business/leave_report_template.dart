// APPLICATION · templates · business · leave report. Pure Dart.
//
// A leave-balance report: entitlement, taken and remaining days per employee
// and leave type. Validates remaining = entitlement − taken per row.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';

/// A single employee's leave balance for one leave type.
class LeaveBalanceRow {
  const LeaveBalanceRow({
    required this.employeeName,
    required this.leaveType,
    required this.entitledDays,
    required this.takenDays,
    this.employeeNameAr,
    this.leaveTypeAr,
  });
  final String employeeName;
  final String? employeeNameAr;
  final String leaveType;
  final String? leaveTypeAr;
  final double entitledDays;
  final double takenDays;

  double get remainingDays => entitledDays - takenDays;
}

/// Data for a leave report.
class LeaveReportData {
  const LeaveReportData({
    required this.asOfDate,
    required this.rows,
    this.organizationName = '',
    this.organizationNameAr,
  });

  final DateTime asOfDate;
  final List<LeaveBalanceRow> rows;
  final String organizationName;
  final String? organizationNameAr;
}

class LeaveReportTemplate extends PdfTemplate<LeaveReportData> {
  const LeaveReportTemplate();

  @override
  String get id => 'leave_report';
  @override
  String get name => 'Leave Balance Report';
  @override
  String get nameAr => 'تقرير أرصدة الإجازات';
  @override
  String get description => 'Leave entitlement, taken and remaining balance per employee.';

  @override
  GeniusFinancialValidationResult validate(LeaveReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    final results = [
      for (final r in data.rows)
        validator.validateGrandTotal(
          subtotal: r.entitledDays,
          discounts: r.takenDays,
          vatAmount: 0,
          fees: 0,
          providedGrandTotal: r.remainingDays,
        ),
    ];
    return validator.combineResults(results);
  }

  @override
  PdfDocumentDefinition build(LeaveReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    String num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

    final columns = ar
        ? ['الموظف', 'نوع الإجازة', 'المستحق', 'المستخدم', 'المتبقي']
        : ['Employee', 'Leave Type', 'Entitled', 'Taken', 'Remaining'];
    final rows = <List<String>>[
      for (final r in data.rows)
        [
          ar ? (r.employeeNameAr ?? r.employeeName) : r.employeeName,
          ar ? (r.leaveTypeAr ?? r.leaveType) : r.leaveType,
          num(r.entitledDays),
          num(r.takenDays),
          num(r.remainingDays),
        ],
    ];

    final lowBalance = data.rows.where((r) => r.remainingDays <= 2).length;

    return pdfDocument()
        .metadata(title: '${ar ? 'تقرير أرصدة الإجازات' : 'Leave Balance Report'} — ${_date(data.asOfDate)}', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? 'تقرير أرصدة الإجازات' : 'Leave Balance Report'),
      if (data.organizationName.isNotEmpty)
        pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.paragraph('${ar ? 'كما في' : 'As of'}: ${_date(data.asOfDate)}'),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.infoBox(
        lowBalance == 0
            ? (ar ? 'جميع الأرصدة ضمن الحدود الطبيعية' : 'All balances are within normal range')
            : (ar ? '$lowBalance رصيد منخفض (يومان أو أقل)' : '$lowBalance balance(s) low (2 days or fewer)'),
        tone: lowBalance == 0 ? 'green' : 'orange',
      ),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
