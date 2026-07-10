// APPLICATION · templates · business · employee report. Pure Dart.
//
// A single-employee HR profile summary: identity, employment details and an
// optional compensation section, reusing the same section/line shape as the
// financial statements.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// Data for an employee report.
class EmployeeReportData {
  const EmployeeReportData({
    required this.employee,
    required this.employeeId,
    required this.jobTitle,
    required this.department,
    required this.hireDate,
    this.jobTitleAr,
    this.departmentAr,
    this.manager,
    this.employmentType = 'Full-time',
    this.status = 'Active',
    this.compensation,
    this.currency = 'SAR',
    this.asOfDate,
  });

  final PdfParty employee;
  final String employeeId;
  final String jobTitle;
  final String? jobTitleAr;
  final String department;
  final String? departmentAr;
  final DateTime hireDate;
  final String? manager;
  final String employmentType;
  final String status;

  /// Optional compensation breakdown (e.g. basic, housing, transport).
  final PdfReportSection? compensation;
  final String currency;
  final DateTime? asOfDate;
}

class EmployeeReportTemplate extends PdfTemplate<EmployeeReportData> {
  const EmployeeReportTemplate();

  @override
  String get id => 'employee_report';
  @override
  String get name => 'Employee Report';
  @override
  String get nameAr => 'تقرير بيانات الموظف';
  @override
  String get description => 'Single-employee HR profile with optional compensation.';

  @override
  GeniusFinancialValidationResult validate(EmployeeReportData data, {PdfTemplateContext? context}) =>
      GeniusFinancialValidationResult.valid();

  @override
  PdfDocumentDefinition build(EmployeeReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) => formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final tenureDays = (data.asOfDate ?? DateTime.now()).difference(data.hireDate).inDays;
    final tenureYears = (tenureDays / 365.25);

    return pdfDocument()
        .metadata(title: '${ar ? 'تقرير بيانات الموظف' : 'Employee Report'} — ${data.employeeId}', author: data.employee.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'تقرير بيانات الموظف' : 'Employee Report'),
      pdf.heading(ar ? (data.employee.nameAr ?? data.employee.name) : data.employee.name, level: 2),
      pdf.statusBadge(label: data.status.toUpperCase(), tone: data.status.toLowerCase() == 'active' ? 'green' : 'orange'),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(ar ? 'الرقم الوظيفي' : 'Employee ID', data.employeeId),
        MapEntry(ar ? 'المسمى الوظيفي' : 'Job Title', ar ? (data.jobTitleAr ?? data.jobTitle) : data.jobTitle),
        MapEntry(ar ? 'القسم' : 'Department', ar ? (data.departmentAr ?? data.department) : data.department),
        if (data.manager != null) MapEntry(ar ? 'المدير المباشر' : 'Manager', data.manager!),
        MapEntry(ar ? 'نوع التوظيف' : 'Employment Type', data.employmentType),
        MapEntry(ar ? 'تاريخ التعيين' : 'Hire Date', _date(data.hireDate)),
        MapEntry(ar ? 'مدة الخدمة' : 'Tenure', '${tenureYears.toStringAsFixed(1)} ${ar ? 'سنة' : 'years'}'),
      ]),
      if (data.compensation != null) ...[
        pdf.spacer(12),
        pdf.heading(ar ? 'الراتب الشهري' : 'Monthly Compensation', level: 3),
        pdf.dataTable(
          columns: ar ? ['البند', 'المبلغ'] : ['Component', 'Amount'],
          rows: [
            for (final l in data.compensation!.lines) [ar ? (l.labelAr ?? l.label) : l.label, fmt(l.amount)],
            [ar ? 'الإجمالي' : 'TOTAL', fmt(data.compensation!.total)],
          ],
        ),
      ],
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
