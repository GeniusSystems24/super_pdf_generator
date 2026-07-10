// TEST · public API compatibility.
//
// Referencing every load-bearing public symbol here turns an accidental
// rename/removal into a compile error — the Dart analogue of the Web proposal's
// api-extractor compatibility test. A few runtime assertions pin behaviour.

import 'dart:typed_data';

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
        ],),
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
      const batch = PdfBatchRequest(requests: [], label: 'nightly');
      expect(batch.concurrency, 4);
      expect(PdfJobPriority.values, contains(PdfJobPriority.high));
    });

    test('v1.0.0 capability surface is exported', () {
      // Ports.
      PdfSecurityService? security;
      PdfExporter? exporter;
      const PdfIntelligence intelligence = HeuristicPdfIntelligence();
      expect(security, isNull);
      expect(exporter, isNull);
      expect(intelligence, isA<PdfIntelligence>());

      // Security value types.
      final input = PdfInputFile(name: 'x.pdf', bytes: Uint8List(0));
      const options = PdfSecurityOptions(algorithm: PdfEncryptionAlgorithm.aesx256);
      final protect = PdfSecurityRequest(input: input, options: options);
      expect(protect.options.permissions, isNotEmpty);
      expect(PdfDocumentPermission.values, contains(PdfDocumentPermission.print));

      // Export value types.
      expect(PdfTextExportRequest(input: input).format, PdfExportFormat.plainText);
      expect(PdfAExportRequest(input: input).conformance, PdfAConformance.a1b);

      // Sharing + failures.
      expect(PdfShareTarget.values, contains(PdfShareTarget.bluetooth));
      const PdfFailure sec = SecurityFailure(code: 'S', message: 'm');
      const PdfFailure exp = ExportFailure(code: 'E', message: 'm');
      expect(sec.category, PdfFailureCategory.security);
      expect(exp.category, PdfFailureCategory.export);
    });

    test('v1.1.0 component surface is exported', () {
      // Charts.
      final chart = pdf.chart(
        type: PdfChartType.line,
        labels: const ['A', 'B'],
        series: [pdf.series('s', const [1, 2])],
      );
      expect(chart, isA<PdfChart>());
      expect(PdfChartType.values, contains(PdfChartType.pie));

      // Overlays.
      expect(pdf.watermark('DRAFT'), isA<PdfWatermark>());
      expect(pdf.stamp('PAID', tone: 'green'), isA<PdfStamp>());

      // Form fields + fill API.
      final form = pdfDocument().metadata(title: 'F').content([
        pdf.textField(name: 'a'),
        pdf.checkboxField(name: 'b'),
        pdf.signatureField(name: 'c'),
      ]).build();
      const filler = FormFiller();
      expect(filler.fieldNames(form), <String>['a', 'b', 'c']);
      final filled = filler.fill(form, {'a': 'x', 'b': true});
      expect((filled.pages.first.content.first as PdfTextFormField).value, 'x');

      // Running header/footer tokens.
      const proc = PdfPostProcessing(headerText: '{title}', footerText: '{page}/{total}');
      expect(proc.headerText, isNotNull);
      expect(PdfPostProcessing.fromJson(proc.toJson()).footerText, '{page}/{total}');
    });
  });
}
