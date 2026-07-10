// TEST · domain — builder, serialization, validation, failures.

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

void main() {
  group('document builder', () {
    test('build produces an immutable definition with one page', () {
      final doc = pdfDocument()
          .metadata(title: 'Invoice', author: 'GeniusLink')
          .content([pdf.heading('Invoice'), pdf.paragraph('Body')])
          .build();
      expect(doc.pages.length, 1);
      expect(doc.pages.first.content.length, 2);
      expect(doc.metadata.author, 'GeniusLink');
    });

    test('empty builder still yields a valid single page', () {
      final doc = pdfDocument().metadata(title: 'Empty').build();
      expect(doc.pages.length, 1);
    });
  });

  group('serialization', () {
    test('document JSON round-trips structurally', () {
      final doc = pdfDocument()
          .metadata(title: 'Invoice')
          .content([
            pdf.heading('Invoice'),
            pdf.table(columns: const ['A', 'B'], rows: const [
              ['1', '2'],
            ],),
            pdf.statusBadge(label: 'PAID', tone: 'green'),
          ])
          .build();
      final restored = PdfDocumentDefinition.fromJson(doc.toJson());
      expect(restored.metadata.title, 'Invoice');
      final content = restored.pages.first.content;
      expect(content.length, 3);
      expect(content[1], isA<PdfTable>());
      expect((content[1] as PdfTable).columns, ['A', 'B']);
      expect(content[2], isA<PdfStatusBadge>());
    });

    test('color hex parsing and export', () {
      expect(PdfColor.hex('#4A7CFF').toHex().toUpperCase(), '#4A7CFF');
      expect(PdfColor.hex('#FFF').blue, 255);
    });
  });

  group('validation', () {
    test('a table with a short row reports a warning', () {
      final table = pdf.table(columns: const ['A', 'B', 'C'], rows: const [
        ['1', '2'],
      ],) as PdfTable;
      final issues = table.validate();
      expect(issues.any((i) => i.severity == 'warning'), isTrue);
    });

    test('empty heading is an error', () {
      final heading = pdf.heading('') as PdfHeading;
      expect(heading.validate().any((i) => i.severity == 'error'), isTrue);
    });
  });

  group('failures', () {
    test('every category has a representative failure that carries a code', () {
      const failures = <PdfFailure>[
        ValidationFailure(code: 'V', message: 'm'),
        FontFailure(code: 'F', message: 'm'),
        ImageFailure(code: 'I', message: 'm'),
        RenderingFailure(code: 'R', message: 'm'),
        FileFailure(code: 'FL', message: 'm'),
        PrintingFailure(code: 'P', message: 'm'),
        SharingFailure(code: 'S', message: 'm'),
        ProcessingFailure(code: 'PR', message: 'm'),
        SecurityFailure(code: 'SEC', message: 'm'),
        ExportFailure(code: 'EX', message: 'm'),
        UnsupportedFeatureFailure(code: 'U', message: 'm'),
        PermissionFailure(code: 'PM', message: 'm'),
        CancelledFailure(),
        TimeoutFailure(code: 'T', message: 'm'),
        UnknownFailure(message: 'm'),
      ];
      final categories = failures.map((f) => f.category).toSet();
      expect(categories.length, PdfFailureCategory.values.length);
    });
  });
}
