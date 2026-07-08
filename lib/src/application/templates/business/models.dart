// APPLICATION · templates · shared data models. Pure Dart.
//
// Small, reusable value objects shared by the business templates.

/// A named party (seller, buyer, employer, employee, account holder).
class PdfParty {
  const PdfParty({
    required this.name,
    this.nameAr,
    this.taxNumber,
    this.address,
    this.email,
    this.phone,
    this.extra = const <String, String>{},
  });

  final String name;
  final String? nameAr;
  final String? taxNumber;
  final String? address;
  final String? email;
  final String? phone;
  final Map<String, String> extra;
}

/// A single billable line on an invoice.
class PdfInvoiceLine {
  const PdfInvoiceLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.vatRate = 15,
    String? descriptionAr,
  }) : descriptionAr = descriptionAr;

  final String description;
  final String? descriptionAr;
  final double quantity;
  final double unitPrice;

  /// Absolute discount on this line (in currency units).
  final double discount;

  /// VAT percentage applied to this line (e.g. 15 for 15%).
  final double vatRate;

  /// Net line amount before VAT = qty × price − discount.
  double get net => quantity * unitPrice - discount;

  /// VAT amount for this line = net × rate / 100.
  double get vat => net * vatRate / 100;

  /// Gross line amount = net + VAT.
  double get gross => net + vat;
}

/// A generic report line for statement-style templates (balance sheet, income
/// statement, cash flow): a named account with an amount and optional Arabic
/// label, nesting level and subtotal flag.
class PdfReportLine {
  const PdfReportLine({
    required this.label,
    required this.amount,
    this.labelAr,
    this.code,
    this.level = 0,
    this.isSubtotal = false,
  });

  final String label;
  final String? labelAr;
  final String? code;
  final double amount;
  final int level;
  final bool isSubtotal;
}

/// A named group of [PdfReportLine]s with a computed [total].
class PdfReportSection {
  const PdfReportSection({required this.title, required this.lines, this.titleAr, this.isDeduction = false});

  final String title;
  final String? titleAr;
  final List<PdfReportLine> lines;
  final bool isDeduction;

  double get total => lines.fold(0.0, (s, l) => s + l.amount);
}

/// A generic document line item shared by quotations, purchase orders,
/// delivery notes and credit notes.
class PdfLineItem {
  const PdfLineItem({
    required this.itemNumber,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.descriptionAr,
    this.unit,
    this.discount = 0,
    this.taxRate = 15,
  });

  final int itemNumber;
  final String description;
  final String? descriptionAr;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double discount;
  final double taxRate;

  double get subtotal => quantity * unitPrice;
  double get net => subtotal - discount;
  double get tax => net * taxRate / 100;
  double get total => net + tax;
}
