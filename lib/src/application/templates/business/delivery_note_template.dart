// APPLICATION · templates · business · delivery note. Pure Dart.
//
// A goods-delivery note (no monetary totals — quantities shipped vs ordered,
// with a receiver sign-off). Validates that delivered ≤ ordered per line.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import 'models.dart';

/// A single delivery line.
class DeliveryLine {
  const DeliveryLine({
    required this.description,
    required this.orderedQty,
    required this.deliveredQty,
    this.descriptionAr,
    this.unit = 'pc',
  });
  final String description;
  final String? descriptionAr;
  final double orderedQty;
  final double deliveredQty;
  final String unit;

  bool get isShort => deliveredQty < orderedQty;
}

/// Data for a delivery note.
class DeliveryNoteData {
  const DeliveryNoteData({
    required this.noteNumber,
    required this.date,
    required this.sender,
    required this.receiver,
    required this.lines,
    this.orderReference,
    this.carrier,
  });

  final String noteNumber;
  final DateTime date;
  final PdfParty sender;
  final PdfParty receiver;
  final List<DeliveryLine> lines;
  final String? orderReference;
  final String? carrier;
}

class DeliveryNoteTemplate extends PdfTemplate<DeliveryNoteData> {
  const DeliveryNoteTemplate();

  @override
  String get id => 'delivery_note';
  @override
  String get name => 'Delivery Note';
  @override
  String get nameAr => 'إذن تسليم';
  @override
  String get description => 'Goods delivery note with ordered vs delivered quantities.';

  @override
  GeniusFinancialValidationResult validate(DeliveryNoteData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final errors = <GeniusFinancialValidationError>[];
    GeniusMoney qty(double v) => GeniusMoney.fromDouble(v, currency: 'QTY', policy: ctx.roundingPolicy);
    for (final l in data.lines) {
      if (l.deliveredQty > l.orderedQty) {
        errors.add(GeniusFinancialValidationError(
          fieldId: l.description,
          ruleId: 'delivery_over_order',
          expectedValue: qty(l.orderedQty),
          actualValue: qty(l.deliveredQty),
          message: 'Delivered quantity for "${l.description}" (${l.deliveredQty}) exceeds ordered (${l.orderedQty})',
          messageAr: 'الكمية المسلَّمة لـ "${l.description}" (${l.deliveredQty}) تتجاوز الكمية المطلوبة (${l.orderedQty})',
        ),);
      }
    }
    return errors.isEmpty ? GeniusFinancialValidationResult.valid() : GeniusFinancialValidationResult.invalid(errors);
  }

  @override
  PdfDocumentDefinition build(DeliveryNoteData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    String num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

    final columns = ar
        ? ['#', 'البيان', 'الوحدة', 'المطلوب', 'المسلَّم', 'الحالة']
        : ['#', 'Description', 'Unit', 'Ordered', 'Delivered', 'Status'];
    final rows = <List<String>>[
      for (final (i, l) in data.lines.indexed)
        [
          '${i + 1}',
          ar ? (l.descriptionAr ?? l.description) : l.description,
          l.unit,
          num(l.orderedQty),
          num(l.deliveredQty),
          l.isShort ? (ar ? 'ناقص' : 'SHORT') : (ar ? 'مكتمل' : 'COMPLETE'),
        ],
    ];

    return pdfDocument()
        .metadata(title: '${ar ? 'إذن تسليم' : 'Delivery Note'} ${data.noteNumber}', author: data.sender.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'إذن تسليم' : 'Delivery Note'),
      pdf.keyValue([
        MapEntry(ar ? 'رقم الإذن' : 'Note #', data.noteNumber),
        MapEntry(ar ? 'التاريخ' : 'Date', _date(data.date)),
        if (data.orderReference != null) MapEntry(ar ? 'مرجع الطلب' : 'Order Ref', data.orderReference!),
        if (data.carrier != null) MapEntry(ar ? 'شركة الشحن' : 'Carrier', data.carrier!),
      ]),
      pdf.spacer(8),
      pdf.row([
        pdf.column([pdf.keyValue([MapEntry(ar ? 'من' : 'From', ar ? (data.sender.nameAr ?? data.sender.name) : data.sender.name)])]),
        pdf.column([pdf.keyValue([MapEntry(ar ? 'إلى' : 'To', ar ? (data.receiver.nameAr ?? data.receiver.name) : data.receiver.name)])]),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(16),
      pdf.row([
        pdf.signatureBlock(name: data.sender.name, role: ar ? 'المُسلِّم' : 'Delivered By'),
        pdf.signatureBlock(name: data.receiver.name, role: ar ? 'المستلم' : 'Received By'),
      ]),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
