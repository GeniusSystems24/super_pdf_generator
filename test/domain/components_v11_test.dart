// TEST · v1.1.0 components — charts, overlays, form fields + fill API.
//
// Domain-level: serialization round-trips and the pure fill API. Rendering is
// exercised by the mapper at runtime; here we assert the data model behaves.

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

/// Rebuild a component from its JSON via a one-page document round-trip.
PdfComponent _roundTrip(PdfComponent c) {
  final doc = pdfDocument().metadata(title: 't').content([c]).build();
  final back = PdfDocumentDefinition.fromJson(doc.toJson());
  return back.pages.first.content.first;
}

void main() {
  group('charts', () {
    test('chart serializes and round-trips its type + series', () {
      final chart = pdf.barChart(
        title: 'Revenue',
        labels: const ['Q1', 'Q2', 'Q3'],
        series: [
          pdf.series('2025', const [10, 20, 30]),
          pdf.series('2026', const [15, 25, 35], color: 0xFF1DB88A),
        ],
      ) as PdfChart;
      expect(chart.chartType, PdfChartType.bar);
      expect(chart.series.length, 2);

      final back = _roundTrip(chart) as PdfChart;
      expect(back.chartType, PdfChartType.bar);
      expect(back.labels, const ['Q1', 'Q2', 'Q3']);
      expect(back.series[1].color, 0xFF1DB88A);
      expect(back.series[0].values, const [10, 20, 30]);
    });

    test('pie chart carries a single series', () {
      final pie = pdf.pieChart(
          labels: const ['A', 'B'], values: const [60, 40], title: 'Split',) as PdfChart;
      expect(pie.chartType, PdfChartType.pie);
      expect(pie.series.single.values, const [60, 40]);
    });

    test('line + area factories set their type', () {
      expect((pdf.lineChart(labels: const [], series: const []) as PdfChart).chartType,
          PdfChartType.line,);
      expect((pdf.areaChart(labels: const [], series: const []) as PdfChart).chartType,
          PdfChartType.area,);
    });
  });

  group('overlays', () {
    test('watermark + stamp round-trip', () {
      final wm = _roundTrip(pdf.watermark('DRAFT', opacity: 0.2)) as PdfWatermark;
      expect(wm.text, 'DRAFT');
      expect(wm.opacity, 0.2);

      final st = _roundTrip(pdf.stamp('PAID', tone: 'green', date: '2026-01-01')) as PdfStamp;
      expect(st.text, 'PAID');
      expect(st.tone, 'green');
      expect(st.date, '2026-01-01');
    });
  });

  group('form fields', () {
    test('field types round-trip', () {
      final tf = _roundTrip(pdf.textField(name: 'email', label: 'Email')) as PdfTextFormField;
      expect(tf.name, 'email');
      final cb = _roundTrip(pdf.checkboxField(name: 'agree', checked: true)) as PdfCheckboxField;
      expect(cb.checked, isTrue);
      final sig = _roundTrip(pdf.signatureField(name: 'sign')) as PdfSignatureFormField;
      expect(sig.name, 'sign');
    });

    test('fill API sets values immutably', () {
      final doc = pdfDocument().metadata(title: 'Form').content([
        pdf.textField(name: 'name', label: 'Name'),
        pdf.checkboxField(name: 'subscribe'),
        pdf.column([pdf.textField(name: 'city', label: 'City')]),
      ]).build();

      const filler = FormFiller();
      expect(filler.fieldNames(doc), containsAll(<String>['name', 'subscribe', 'city']));

      final filled = filler.fill(doc, {'name': 'Sara', 'subscribe': true, 'city': 'Riyadh'});
      // Original is untouched.
      final origName = doc.pages.first.content.first as PdfTextFormField;
      expect(origName.value, isEmpty);
      // Filled copy carries values, including nested.
      final newName = filled.pages.first.content.first as PdfTextFormField;
      final newSub = filled.pages.first.content[1] as PdfCheckboxField;
      final col = filled.pages.first.content[2] as PdfColumn;
      final newCity = col.children.first as PdfTextFormField;
      expect(newName.value, 'Sara');
      expect(newSub.checked, isTrue);
      expect(newCity.value, 'Riyadh');
    });

    test('nested fill reaches into containers', () {
      final doc = pdfDocument().metadata(title: 'F').content([
        pdf.column([pdf.textField(name: 'ref')]),
      ]).build();
      const filler = FormFiller();
      expect(filler.fieldNames(doc), ['ref']);
      final filled = filler.fill(doc, {'ref': 'INV-1'});
      final col = filled.pages.first.content.first as PdfColumn;
      expect((col.children.first as PdfTextFormField).value, 'INV-1');
    });
  });

  group('page tokens & running header/footer config', () {
    test('page number format round-trips', () {
      final pn = _roundTrip(pdf.pageNumber()) as PdfPageNumber;
      expect(pn.format, contains('{page}'));
    });

    test('post-processing carries header/footer templates', () {
      const proc = PdfPostProcessing(
        headerText: '{title} — {date}',
        footerText: 'Page {page} / {total}',
      );
      final back = PdfPostProcessing.fromJson(proc.toJson());
      expect(back.headerText, '{title} — {date}');
      expect(back.footerText, 'Page {page} / {total}');
    });
  });
}
