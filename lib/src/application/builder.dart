// APPLICATION · fluent builder + component factory. Pure Dart.
//
// Mirrors the Web API:
//
//   final document = pdfDocument()
//     .metadata(title: 'Monthly Report', author: 'GeniusLink')
//     .page(size: PdfPageSize.a4, margins: const PdfMargins.all(32))
//     .content([ pdf.heading('Summary'), pdf.paragraph('…'), pdf.table(...) ])
//     .build();

import '../domain/components.dart';
import '../domain/document.dart';
import '../domain/theme.dart';
import '../domain/value_objects.dart';

/// Entry point for the fluent builder (analogue of `pdfDocument()`).
PdfDocumentBuilder pdfDocument() => PdfDocumentBuilder();

/// Immutable-friendly document builder. Each call mutates the builder's draft;
/// [build] produces an immutable [PdfDocumentDefinition].
class PdfDocumentBuilder {
  PdfDocumentMetadata _metadata = const PdfDocumentMetadata(title: 'Document');
  PdfTheme _theme = const PdfTheme();
  PdfDirection _direction = PdfDirection.ltr;
  final List<PdfPageDefinition> _pages = <PdfPageDefinition>[];

  PdfPageSize _size = PdfPageSize.a4;
  PdfPageOrientation _orientation = PdfPageOrientation.portrait;
  PdfMargins _margins = const PdfMargins.all(36);

  PdfDocumentBuilder metadata({required String title, String author = '', String? subject}) {
    _metadata = PdfDocumentMetadata(title: title, author: author, subject: subject);
    return this;
  }

  PdfDocumentBuilder theme(PdfTheme theme) {
    _theme = theme;
    return this;
  }

  PdfDocumentBuilder direction(PdfDirection direction) {
    _direction = direction;
    return this;
  }

  /// Configure the *next* page(s) added via [content].
  PdfDocumentBuilder page({
    PdfPageSize? size,
    PdfPageOrientation? orientation,
    PdfMargins? margins,
    double? marginsAll,
  }) {
    if (size != null) _size = size;
    if (orientation != null) _orientation = orientation;
    if (margins != null) _margins = margins;
    if (marginsAll != null) _margins = PdfMargins.all(marginsAll);
    return this;
  }

  /// Append a page with the given content using the current page settings.
  PdfDocumentBuilder content(List<PdfComponent> components) {
    _pages.add(PdfPageDefinition(
      size: _size,
      orientation: _orientation,
      margins: _margins,
      content: components,
    ),);
    return this;
  }

  PdfDocumentDefinition build() => PdfDocumentDefinition(
        metadata: _metadata,
        theme: _theme,
        direction: _direction,
        pages: _pages.isEmpty
            ? <PdfPageDefinition>[
                PdfPageDefinition(size: _size, orientation: _orientation, margins: _margins),
              ]
            : List<PdfPageDefinition>.unmodifiable(_pages),
      );
}

/// The component factory namespace, exported as the top-level `pdf` object so
/// call sites read `pdf.heading(...)` exactly like the Web design.
const PdfComponentFactory pdf = PdfComponentFactory();

/// Factory of component constructors. Every method returns an immutable
/// [PdfComponent]; the terminology matches the Web inventory 1:1.
class PdfComponentFactory {
  const PdfComponentFactory();

  PdfComponent text(String value) => PdfText(value);
  PdfComponent heading(String value, {int level = 1}) => PdfHeading(value, level: level);
  PdfComponent paragraph(String value, {PdfAlign align = PdfAlign.start}) =>
      PdfParagraph(value, align: align);
  PdfComponent richText(List<String> spans) => PdfRichText(spans);

  PdfComponent spacer([double size = 12]) => PdfSpacer(size);
  PdfComponent divider() => const PdfDivider();
  PdfComponent pageBreak() => const PdfPageBreak();

  PdfComponent container(List<PdfComponent> children) => PdfContainer(children);
  PdfComponent row(List<PdfComponent> children) => PdfRow(children);
  PdfComponent column(List<PdfComponent> children) => PdfColumn(children);
  PdfComponent stack(List<PdfComponent> children) => PdfStack(children);
  PdfComponent wrap(List<PdfComponent> children) => PdfWrap(children);
  PdfComponent grid(List<PdfComponent> children, {int columns = 2}) =>
      PdfGrid(children, columns: columns);
  PdfComponent keepTogether(List<PdfComponent> children) => PdfKeepTogether(children);

  PdfComponent table({
    required List<String> columns,
    required List<List<String>> rows,
    bool zebra = true,
  }) =>
      PdfTable(columns: columns, rows: rows, zebra: zebra);

  PdfComponent dataTable({
    required List<String> columns,
    required List<List<String>> rows,
    bool zebra = true,
  }) =>
      PdfTable(columns: columns, rows: rows, zebra: zebra);

  PdfComponent keyValue(List<MapEntry<String, String>> pairs) =>
      PdfKeyValueSection(pairs);
  PdfComponent list(List<String> items, {bool ordered = false}) =>
      PdfList(items, ordered: ordered);
  PdfComponent bulletList(List<String> items) => PdfList(items, ordered: false);
  PdfComponent numberedList(List<String> items) => PdfList(items, ordered: true);

  PdfComponent image({required String label, String? assetKey, String? altText}) =>
      PdfImage(label: label, assetKey: assetKey, altText: altText);
  PdfComponent svg(String data, {String? altText}) => PdfSvg(data, altText: altText);
  PdfComponent barcode(String value, {String symbology = 'code128'}) =>
      PdfBarcode(value, symbology: symbology);
  PdfComponent qrCode(String value) => PdfQrCode(value);

  /// A data-driven chart rendered natively to vector PDF.
  PdfComponent chart({
    required PdfChartType type,
    required List<PdfChartSeries> series,
    List<String> labels = const <String>[],
    String? title,
    double height = 170,
  }) =>
      PdfChart(
          chartType: type,
          series: series,
          labels: labels,
          title: title,
          height: height,);
  PdfComponent barChart(
          {required List<String> labels,
          required List<PdfChartSeries> series,
          String? title,
          double height = 170,}) =>
      PdfChart(
          chartType: PdfChartType.bar,
          series: series,
          labels: labels,
          title: title,
          height: height,);
  PdfComponent lineChart(
          {required List<String> labels,
          required List<PdfChartSeries> series,
          String? title,
          double height = 170,}) =>
      PdfChart(
          chartType: PdfChartType.line,
          series: series,
          labels: labels,
          title: title,
          height: height,);
  PdfComponent areaChart(
          {required List<String> labels,
          required List<PdfChartSeries> series,
          String? title,
          double height = 170,}) =>
      PdfChart(
          chartType: PdfChartType.area,
          series: series,
          labels: labels,
          title: title,
          height: height,);
  PdfComponent pieChart(
          {required List<String> labels,
          required List<double> values,
          String? title,
          double height = 170,}) =>
      PdfChart(
          chartType: PdfChartType.pie,
          series: [PdfChartSeries(name: title ?? 'Series', values: values)],
          labels: labels,
          title: title,
          height: height,);

  /// A single chart series (a bar group, line, area, or pie slice set).
  PdfChartSeries series(String name, List<double> values, {int? color}) =>
      PdfChartSeries(name: name, values: values, color: color);

  /// Inline diagonal watermark (see [PdfPostProcessing] for a page-background one).
  PdfComponent watermark(String text,
          {double opacity = 0.12, double angle = -0.6, double fontSize = 48,}) =>
      PdfWatermark(text, opacity: opacity, angle: angle, fontSize: fontSize);

  /// A rubber-stamp label (e.g. PAID / CONFIDENTIAL).
  PdfComponent stamp(String text,
          {String tone = 'red', String? date, double angle = -0.25,}) =>
      PdfStamp(text, tone: tone, date: date, angle: angle);

  // ---- form fields (AcroForm) ----
  PdfComponent textField(
          {required String name,
          String label = '',
          String value = '',
          double width = 220,
          double height = 22,
          bool multiline = false,}) =>
      PdfTextFormField(
          name: name,
          label: label,
          value: value,
          width: width,
          height: height,
          multiline: multiline,);
  PdfComponent checkboxField(
          {required String name, String label = '', bool checked = false,}) =>
      PdfCheckboxField(name: name, label: label, checked: checked);
  PdfComponent signatureField(
          {required String name,
          String label = 'Signature',
          double width = 200,
          double height = 60,}) =>
      PdfSignatureFormField(name: name, label: label, width: width, height: height);

  PdfComponent statusBadge({required String label, String tone = 'blue'}) =>
      PdfStatusBadge(label: label, tone: tone);
  PdfComponent infoBox(String text, {String tone = 'blue'}) =>
      PdfInfoBox(text, tone: tone);
  PdfComponent signatureBlock({required String name, required String role, String? dateLabel}) =>
      PdfSignatureBlock(name: name, role: role, dateLabel: dateLabel);
  PdfComponent header({required String title}) => PdfHeader(title: title);
  PdfComponent footer({required String text}) => PdfFooter(text: text);
  PdfComponent pageNumber({String format = '{page} / {total}'}) =>
      PdfPageNumber(format: format);

  PdfComponent conditional({required bool when, required List<PdfComponent> child}) =>
      PdfConditional(when: when, child: child);
  PdfComponent repeated(List<PdfComponent> children, {int count = 1}) =>
      PdfRepeated(children, count: count);
}
