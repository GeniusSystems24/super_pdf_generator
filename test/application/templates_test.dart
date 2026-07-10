// TEST · application — template registry (voucher family parity).

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

void main() {
  group('default template registry', () {
    final registry = defaultTemplateRegistry();

    test('registers the full voucher family', () {
      const voucherIds = <String>[
        'payment_voucher',
        'expense_voucher',
        'petty_cash_voucher',
        'journal_voucher',
        'contra_voucher',
        'bank_payment_voucher',
        'bank_receipt_voucher',
        'cash_payment_voucher',
        'cash_receipt_voucher',
        'salary_voucher',
        'advance_voucher',
        'refund_voucher',
        'deposit_voucher',
      ];
      for (final id in voucherIds) {
        expect(registry.contains(id), isTrue, reason: 'missing $id');
      }
    });

    test('a voucher template builds a valid document', () {
      final template = registry.require('expense_voucher');
      final data = PaymentVoucherData(
        voucherNumber: 'EV-0001',
        date: DateTime(2026, 1, 15),
        payer: const PdfParty(name: 'GeniusLink'),
        payee: const PdfParty(name: 'Acme Supplies'),
        amount: 1250.00,
        purpose: 'Office supplies',
      );
      final result = template.buildChecked(data);
      expect(result.isValid, isTrue);
      expect(result.document, isNotNull);
      expect(result.document!.metadata.title, contains('EV-0001'));
    });

    test('bilingual names are present', () {
      final template = registry.require('cash_receipt_voucher');
      expect(template.name, 'Cash Receipt Voucher');
      expect(template.nameAr, isNotEmpty);
    });
  });
}
