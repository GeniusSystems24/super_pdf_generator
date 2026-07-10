// TEST · application — heuristic intelligence analyzer.

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

void main() {
  group('HeuristicPdfIntelligence', () {
    const intelligence = HeuristicPdfIntelligence();

    test('counts structure and words across the tree', () async {
      final doc = pdfDocument()
          .metadata(title: 'Report')
          .content([
            pdf.heading('Overview'),
            pdf.paragraph('The quarterly numbers are strong and improving.'),
            pdf.table(columns: const ['A', 'B'], rows: const [
              ['1', '2'],
            ],),
            pdf.bulletList(const ['first item', 'second item']),
            pdf.image(label: 'Chart'),
          ])
          .build();

      final analysis = await intelligence.analyze(doc);
      expect(analysis.headingCount, 1);
      expect(analysis.tableCount, 1);
      expect(analysis.listCount, 1);
      expect(analysis.imageCount, 1);
      expect(analysis.wordCount, greaterThan(0));
      expect(analysis.readingMinutes, greaterThanOrEqualTo(1));
    });

    test('detects Arabic script', () async {
      final doc = pdfDocument()
          .metadata(title: 'فاتورة')
          .content([pdf.paragraph('هذا مستند تجريبي باللغة العربية.')])
          .build();
      final analysis = await intelligence.analyze(doc);
      expect(analysis.hasArabic, isTrue);
      expect(analysis.script, anyOf(PdfScript.arabic, PdfScript.mixed));
    });

    test('suggests RTL when Arabic content is set LTR', () async {
      final doc = pdfDocument()
          .metadata(title: 'Doc')
          .direction(PdfDirection.ltr)
          .content([pdf.paragraph('محتوى عربي داخل مستند اتجاهه من اليسار.')])
          .build();
      final suggestions = await intelligence.suggestLayout(doc);
      expect(suggestions.any((s) => s.code == 'SET_RTL'), isTrue);
    });

    test('flags an empty document', () async {
      final doc = pdfDocument().metadata(title: 'Empty').build();
      final suggestions = await intelligence.suggestLayout(doc);
      expect(suggestions.any((s) => s.code == 'EMPTY_DOCUMENT'), isTrue);
    });
  });
}
