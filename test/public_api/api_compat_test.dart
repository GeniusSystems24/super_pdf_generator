// TEST · public API compatibility.
//
// Referencing every load-bearing public symbol here turns an accidental
// rename/removal into a compile error — the Dart analogue of the Web proposal's
// api-extractor compatibility test. A few runtime assertions pin behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

void main() {
  group('public API surface', () {
    test('fluent builder + component factory assemble a document', () {
      final document = pdfDocument()
          .metadata(title: 'Monthly Report', author: 'GeniusLink')
          .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.portrait, marginsAll: 32)
          .content([
        pdf.header(title: 'Monthly Report'),
        pdf.heading('Summary'),
        pdf.paragraph('Generated from structured business data.'),
        pdf.table(columns: const ['Item', 'Value'], rows: const [
          ['Revenue', '1,200'],
        ]),
        pdf.keyValue(const [MapEntry('Total', '1,200')]),
        pdf.bulletList(const ['One', 'Two']),
        pdf.qrCode('https://folio.dev'),
        pdf.statusBadge(label: 'PAID', tone: 'green'),
        pdf.keepTogether([pdf.signatureBlock(name: 'A. Signer', role: 'CFO')]),
        pdf.footer(text: 'Confidential'),
      ]).build();

      expect(document, isA<PdfDocumentDefinition>());
      expect(document.metadata.title, 'Monthly Report');
      expect(document.pages.single.content.length, 10);
    });

    test('generation state is a discriminated union', () {
      const PdfGenerationState state = PdfGenIdle();
      final label = switch (state) {
        PdfGenIdle() => 'idle',
        PdfGenPreparing() => 'preparing',
        PdfGenGenerating() => 'generating',
        PdfGenCompleted() => 'completed',
        PdfGenFailed() => 'failed',
        PdfGenCancelled() => 'cancelled',
      };
      expect(label, 'idle');
    });

    test('failures are a categorized sealed hierarchy', () {
      const PdfFailure failure = FontFailure(code: 'FONT_GLYPH_MISSING', message: 'x');
      expect(failure.category, PdfFailureCategory.font);
      expect(failure.retryable, isTrue);
      const PdfFailure validation = ValidationFailure(code: 'V', message: 'y');
      expect(validation.retryable, isFalse);
    });

    test('Result folds both branches', () {
      const Result<int> ok = Ok(7);
      expect(ok.fold((v) => v * 2, (_) => -1), 14);
      const Result<int> err = Err(UnknownFailure(message: 'nope'));
      expect(err.isErr, isTrue);
    });

    test('factory entry points are present', () {
      expect(createPdfClient, isNotNull);
      expect(createStudioClient, isNotNull);
    });

    test('processing + job requests are constructible', () {
      const merge = PdfMergeRequest(inputs: []);
      expect(merge.operation, 'merge');
      final batch = PdfBatchRequest(requests: const [], label: 'nightly');
      expect(batch.concurrency, 4);
      expect(PdfJobPriority.values, contains(PdfJobPriority.high));
    });
  });
}
