// TEST · financial domain (pure Dart). Runs without Flutter bindings.

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

void main() {
  group('GeniusMoney', () {
    test('exact addition and subtraction in minor units', () {
      final p = GeniusRoundingPolicy.defaults();
      final a = GeniusMoney.fromDouble(900.00, currency: 'SAR', policy: p);
      final b = GeniusMoney.fromDouble(135.00, currency: 'SAR', policy: p);
      expect((a + b).toDouble(), 1035.00);
      expect((a - b).toDouble(), 765.00);
      expect(a.minorUnits, 90000);
    });

    test('multiplyByRate rounds exactly once', () {
      final p = GeniusRoundingPolicy.defaults();
      final base = GeniusMoney.fromDouble(900.00, currency: 'SAR', policy: p);
      expect(base.multiplyByRate(0.15, policy: p).toDouble(), 135.00);
    });

    test('honours 3-decimal currencies', () {
      final p = GeniusRoundingPolicy.forCurrency('KWD');
      final m = GeniusMoney.fromDouble(12.3456, currency: 'KWD', policy: p);
      expect(m.decimalPlaces, 3);
      expect(m.toDisplayString(), '12.346');
    });
  });

  group('GeniusFinancialValidator', () {
    final validator = GeniusFinancialValidator(GeniusRoundingPolicy.defaults());

    test('subtotal matches sum of lines', () {
      final ok = validator.validateSubtotal(lineTotals: [1200, 1800, 900], providedSubtotal: 3900);
      expect(ok.isValid, isTrue);
      final bad = validator.validateSubtotal(lineTotals: [1200, 1800, 900], providedSubtotal: 3899);
      expect(bad.isValid, isFalse);
      expect(bad.errors.single.messageAr, isNotEmpty);
    });

    test('VAT calculation', () {
      expect(validator.validateVat(vatBase: 3900, vatRate: 15, providedVatAmount: 585).isValid, isTrue);
      expect(validator.validateVat(vatBase: 3900, vatRate: 15, providedVatAmount: 580).isValid, isFalse);
    });

    test('debits must equal credits exactly', () {
      expect(validator.validateAccountingEntries(debits: [85000, 42000], credits: [31000, 96000]).isValid, isTrue);
      expect(validator.validateAccountingEntries(debits: [85000], credits: [84999]).isValid, isFalse);
    });
  });

  group('TaxInvoiceTemplate', () {
    test('buildChecked produces a document for correct figures', () {
      const template = TaxInvoiceTemplate();
      final data = TaxInvoiceData(
        invoiceNumber: 'INV-1',
        issueDate: DateTime(2026, 1, 1),
        seller: const PdfParty(name: 'Seller'),
        buyer: const PdfParty(name: 'Buyer'),
        lines: const [PdfInvoiceLine(description: 'X', quantity: 2, unitPrice: 100, vatRate: 15)],
        providedSubtotal: 200,
        providedVatTotal: 30,
        providedGrandTotal: 230,
      );
      final result = template.buildChecked(data);
      expect(result.isValid, isTrue);
      expect(result.document!.pages, isNotEmpty);
    });

    test('buildChecked rejects a wrong grand total', () {
      const template = TaxInvoiceTemplate();
      final data = TaxInvoiceData(
        invoiceNumber: 'INV-2',
        issueDate: DateTime(2026, 1, 1),
        seller: const PdfParty(name: 'Seller'),
        buyer: const PdfParty(name: 'Buyer'),
        lines: const [PdfInvoiceLine(description: 'X', quantity: 2, unitPrice: 100, vatRate: 15)],
        providedGrandTotal: 999,
      );
      final result = template.buildChecked(data);
      expect(result.isValid, isFalse);
      expect(result.document, isNull);
    });
  });

  group('amountInWords', () {
    test('English', () {
      expect(amountInWords(1035.50, currencyCode: 'SAR'), contains('One Thousand Thirty-Five'));
      expect(amountInWords(1035.50, currencyCode: 'SAR'), contains('Fifty Halalas'));
    });
    test('Arabic', () {
      final w = amountInWords(1035.0, currencyCode: 'SAR', language: AmountWordsLanguage.arabic);
      expect(w, contains('ريال'));
    });
  });
}
