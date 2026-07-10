// DOMAIN · component tree. Pure, immutable, serializable.
//
// A sealed hierarchy mirroring the Web component inventory (`pdf.*`). Every
// component carries typed props, a `type` discriminator, JSON (de)serialization
// and a `validate()` that returns human-readable issues. Terminology is kept
// identical to the Web/TypeScript design.

import 'package:meta/meta.dart';

import 'value_objects.dart';

/// A validation issue produced by [PdfComponent.validate].
@immutable
class PdfValidationIssue {
  const PdfValidationIssue(this.message, {this.severity = 'error'});
  final String message;
  final String severity; // 'error' | 'warning'
}

/// Base of the document component tree.
@immutable
sealed class PdfComponent {
  const PdfComponent();

  /// Stable discriminator, matching the Web `pdf.*` names.
  String get type;

  /// Structural validation. Empty when valid.
  List<PdfValidationIssue> validate() => const <PdfValidationIssue>[];

  Map<String, Object?> toJson();

  /// Rebuild a component from JSON — the inverse of [toJson].
  static PdfComponent fromJson(Map<String, Object?> json) {
    final type = json['type'] as String? ?? 'paragraph';
    List<PdfComponent> kids(Object? raw) => (raw as List? ?? const [])
        .map((e) => PdfComponent.fromJson((e as Map).cast<String, Object?>()))
        .toList();
    switch (type) {
      case 'text':
        return PdfText(json['text'] as String? ?? '');
      case 'heading':
        return PdfHeading(json['text'] as String? ?? '',
            level: (json['level'] as num?)?.toInt() ?? 2,);
      case 'paragraph':
        return PdfParagraph(json['text'] as String? ?? '');
      case 'richText':
        return PdfRichText(json['spans'] is List
            ? (json['spans'] as List).map((e) => e.toString()).toList()
            : const <String>[],);
      case 'spacer':
        return PdfSpacer((json['size'] as num?)?.toDouble() ?? 12);
      case 'divider':
        return const PdfDivider();
      case 'pageBreak':
        return const PdfPageBreak();
      case 'container':
        return PdfContainer(kids(json['children']));
      case 'row':
        return PdfRow(kids(json['children']));
      case 'column':
        return PdfColumn(kids(json['children']));
      case 'stack':
        return PdfStack(kids(json['children']));
      case 'wrap':
        return PdfWrap(kids(json['children']));
      case 'grid':
        return PdfGrid(kids(json['children']),
            columns: (json['columns'] as num?)?.toInt() ?? 2,);
      case 'keepTogether':
        return PdfKeepTogether(kids(json['children']));
      case 'table':
      case 'dataTable':
        return PdfTable(
          columns: (json['columns'] as List? ?? const [])
              .map((e) => e.toString())
              .toList(),
          rows: (json['rows'] as List? ?? const [])
              .map((r) => (r as List).map((c) => c.toString()).toList())
              .toList(),
          zebra: json['zebra'] as bool? ?? true,
        );
      case 'keyValue':
        return PdfKeyValueSection((json['pairs'] as List? ?? const [])
            .map((p) => MapEntry(
                (p as List)[0].toString(), p.length > 1 ? p[1].toString() : '',),)
            .toList(),);
      case 'list':
      case 'bulletList':
      case 'numberedList':
        return PdfList(
          (json['items'] as List? ?? const []).map((e) => e.toString()).toList(),
          ordered: json['ordered'] as bool? ?? (type == 'numberedList'),
        );
      case 'image':
        return PdfImage(
            label: json['label'] as String? ?? 'Image',
            assetKey: json['assetKey'] as String?,
            altText: json['altText'] as String?,);
      case 'svg':
        return PdfSvg(json['data'] as String? ?? '', altText: json['altText'] as String?);
      case 'barcode':
        return PdfBarcode(json['value'] as String? ?? '',
            symbology: json['symbology'] as String? ?? 'code128',);
      case 'qrCode':
        return PdfQrCode(json['value'] as String? ?? '');
      case 'statusBadge':
        return PdfStatusBadge(
            label: json['label'] as String? ?? 'STATUS',
            tone: json['tone'] as String? ?? 'blue',);
      case 'infoBox':
        return PdfInfoBox(json['text'] as String? ?? '',
            tone: json['tone'] as String? ?? 'blue',);
      case 'signatureBlock':
        return PdfSignatureBlock(
            name: json['name'] as String? ?? '',
            role: json['role'] as String? ?? '',
            dateLabel: json['dateLabel'] as String?,);
      case 'watermark':
        return PdfWatermark(json['text'] as String? ?? '',
            opacity: (json['opacity'] as num?)?.toDouble() ?? 0.12,
            angle: (json['angle'] as num?)?.toDouble() ?? -0.6,
            fontSize: (json['fontSize'] as num?)?.toDouble() ?? 48,);
      case 'stamp':
        return PdfStamp(json['text'] as String? ?? '',
            tone: json['tone'] as String? ?? 'red',
            date: json['date'] as String?,
            angle: (json['angle'] as num?)?.toDouble() ?? -0.25,);
      case 'textField':
        return PdfTextFormField(
            name: json['name'] as String? ?? '',
            label: json['label'] as String? ?? '',
            value: json['value'] as String? ?? '',
            width: (json['width'] as num?)?.toDouble() ?? 220,
            height: (json['height'] as num?)?.toDouble() ?? 22,
            multiline: json['multiline'] as bool? ?? false,);
      case 'checkboxField':
        return PdfCheckboxField(
            name: json['name'] as String? ?? '',
            label: json['label'] as String? ?? '',
            checked: json['checked'] as bool? ?? false,);
      case 'signatureField':
        return PdfSignatureFormField(
            name: json['name'] as String? ?? '',
            label: json['label'] as String? ?? 'Signature',
            width: (json['width'] as num?)?.toDouble() ?? 200,
            height: (json['height'] as num?)?.toDouble() ?? 60,);
      case 'header':
        return PdfHeader(title: json['title'] as String? ?? '');
      case 'footer':
        return PdfFooter(text: json['text'] as String? ?? '');
      case 'pageNumber':
        return PdfPageNumber(format: json['format'] as String? ?? '{page} / {total}');
      case 'chart':
        return PdfChart(
          chartType:
              enumByName(PdfChartType.values, json['chartType'], PdfChartType.bar),
          title: (json['title'] ?? json['label']) as String?,
          labels: (json['labels'] as List? ?? const [])
              .map((e) => e.toString())
              .toList(),
          series: (json['series'] as List? ?? const [])
              .map((e) =>
                  PdfChartSeries.fromJson((e as Map).cast<String, Object?>()),)
              .toList(),
          height: (json['height'] as num?)?.toDouble() ?? 170,
        );
      case 'conditional':
        return PdfConditional(
            when: json['when'] as bool? ?? true, child: kids(json['children']),);
      case 'repeated':
        return PdfRepeated(kids(json['children']), count: (json['count'] as num?)?.toInt() ?? 1);
      default:
        return PdfParagraph(json['text'] as String? ?? '');
    }
  }
}

// ---- text -----------------------------------------------------------------

class PdfText extends PdfComponent {
  const PdfText(this.text, {this.style});
  final String text;
  final PdfTextStyleRef? style;
  @override
  String get type => 'text';
  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text};
}

/// Lightweight style hint kept nullable so JSON round-trips stay compact.
typedef PdfTextStyleRef = Object;

class PdfHeading extends PdfComponent {
  const PdfHeading(this.text, {this.level = 2});
  final String text;
  final int level; // 1..3
  @override
  String get type => 'heading';
  @override
  List<PdfValidationIssue> validate() => [
        if (text.trim().isEmpty)
          const PdfValidationIssue('Heading text is empty'),
        if (level < 1 || level > 3)
          const PdfValidationIssue('Heading level must be 1–3'),
      ];
  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text, 'level': level};
}

class PdfParagraph extends PdfComponent {
  const PdfParagraph(this.text, {this.align = PdfAlign.start});
  final String text;
  final PdfAlign align;
  @override
  String get type => 'paragraph';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'text': text, 'align': align.name};
}

class PdfRichText extends PdfComponent {
  const PdfRichText(this.spans);
  final List<String> spans;
  @override
  String get type => 'richText';
  @override
  Map<String, Object?> toJson() => {'type': type, 'spans': spans};
}

// ---- layout ---------------------------------------------------------------

class PdfSpacer extends PdfComponent {
  const PdfSpacer(this.size);
  final double size;
  @override
  String get type => 'spacer';
  @override
  Map<String, Object?> toJson() => {'type': type, 'size': size};
}

class PdfDivider extends PdfComponent {
  const PdfDivider();
  @override
  String get type => 'divider';
  @override
  Map<String, Object?> toJson() => {'type': type};
}

class PdfPageBreak extends PdfComponent {
  const PdfPageBreak();
  @override
  String get type => 'pageBreak';
  @override
  Map<String, Object?> toJson() => {'type': type};
}

/// Base for components that hold children.
sealed class PdfContainerBase extends PdfComponent {
  const PdfContainerBase(this.children);
  final List<PdfComponent> children;
  Map<String, Object?> childrenJson() =>
      {'children': children.map((c) => c.toJson()).toList()};
}

class PdfContainer extends PdfContainerBase {
  const PdfContainer(super.children);
  @override
  String get type => 'container';
  @override
  Map<String, Object?> toJson() => {'type': type, ...childrenJson()};
}

class PdfRow extends PdfContainerBase {
  const PdfRow(super.children);
  @override
  String get type => 'row';
  @override
  Map<String, Object?> toJson() => {'type': type, ...childrenJson()};
}

class PdfColumn extends PdfContainerBase {
  const PdfColumn(super.children);
  @override
  String get type => 'column';
  @override
  Map<String, Object?> toJson() => {'type': type, ...childrenJson()};
}

class PdfStack extends PdfContainerBase {
  const PdfStack(super.children);
  @override
  String get type => 'stack';
  @override
  Map<String, Object?> toJson() => {'type': type, ...childrenJson()};
}

class PdfWrap extends PdfContainerBase {
  const PdfWrap(super.children);
  @override
  String get type => 'wrap';
  @override
  Map<String, Object?> toJson() => {'type': type, ...childrenJson()};
}

class PdfGrid extends PdfContainerBase {
  const PdfGrid(super.children, {this.columns = 2});
  final int columns;
  @override
  String get type => 'grid';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'columns': columns, ...childrenJson()};
}

class PdfKeepTogether extends PdfContainerBase {
  const PdfKeepTogether(super.children);
  @override
  String get type => 'keepTogether';
  @override
  Map<String, Object?> toJson() => {'type': type, ...childrenJson()};
}

class PdfConditional extends PdfContainerBase {
  const PdfConditional({required this.when, required List<PdfComponent> child})
      : super(child);
  final bool when;
  @override
  String get type => 'conditional';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'when': when, ...childrenJson()};
}

class PdfRepeated extends PdfContainerBase {
  const PdfRepeated(super.children, {this.count = 1});
  final int count;
  @override
  String get type => 'repeated';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'count': count, ...childrenJson()};
}

// ---- data -----------------------------------------------------------------

class PdfTable extends PdfComponent {
  const PdfTable({
    required this.columns,
    required this.rows,
    this.zebra = true,
    this.direction,
  });
  final List<String> columns;
  final List<List<String>> rows;
  final bool zebra;
  final PdfDirection? direction;
  @override
  String get type => 'table';
  @override
  List<PdfValidationIssue> validate() => [
        if (columns.isEmpty)
          const PdfValidationIssue('Table has no columns'),
        for (final (i, r) in rows.indexed)
          if (r.length != columns.length)
            PdfValidationIssue(
                'Row ${i + 1} has ${r.length} cells, expected ${columns.length}',
                severity: 'warning',),
      ];
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'columns': columns, 'rows': rows, 'zebra': zebra};
}

class PdfKeyValueSection extends PdfComponent {
  const PdfKeyValueSection(this.pairs);
  final List<MapEntry<String, String>> pairs;
  @override
  String get type => 'keyValue';
  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'pairs': pairs.map((e) => [e.key, e.value]).toList(),
      };
}

class PdfList extends PdfComponent {
  const PdfList(this.items, {this.ordered = false});
  final List<String> items;
  final bool ordered;
  @override
  String get type => 'list';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'items': items, 'ordered': ordered};
}

// ---- media ----------------------------------------------------------------

class PdfImage extends PdfComponent {
  const PdfImage({required this.label, this.assetKey, this.altText});
  final String label;
  final String? assetKey;
  final String? altText;
  @override
  String get type => 'image';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'label': label, 'assetKey': assetKey, 'altText': altText};
}

class PdfSvg extends PdfComponent {
  const PdfSvg(this.data, {this.altText});
  final String data;
  final String? altText;
  @override
  String get type => 'svg';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'data': data, 'altText': altText};
}

class PdfBarcode extends PdfComponent {
  const PdfBarcode(this.value, {this.symbology = 'code128'});
  final String value;
  final String symbology;
  @override
  String get type => 'barcode';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'value': value, 'symbology': symbology};
}

class PdfQrCode extends PdfComponent {
  const PdfQrCode(this.value);
  final String value;
  @override
  String get type => 'qrCode';
  @override
  Map<String, Object?> toJson() => {'type': type, 'value': value};
}

/// The kind of chart to render.
enum PdfChartType { bar, line, area, pie }

/// One data series (a bar group, a line, an area, or — for pie — the slice set).
@immutable
class PdfChartSeries {
  const PdfChartSeries({required this.name, required this.values, this.color});
  final String name;
  final List<double> values;

  /// 0xAARRGGBB; when null the mapper assigns a palette color by index.
  final int? color;

  Map<String, Object?> toJson() =>
      {'name': name, 'values': values, 'color': color};

  factory PdfChartSeries.fromJson(Map<String, Object?> json) => PdfChartSeries(
        name: json['name'] as String? ?? '',
        values: (json['values'] as List? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        color: (json['color'] as num?)?.toInt(),
      );
}

/// A data-driven chart (bar / line / area / pie), rendered natively to vector
/// PDF by the mapper — no rasterization, so it stays crisp and isolate-safe.
class PdfChart extends PdfComponent {
  const PdfChart({
    required this.chartType,
    required this.series,
    this.labels = const <String>[],
    this.title,
    this.height = 170,
  });
  final PdfChartType chartType;
  final List<PdfChartSeries> series;
  final List<String> labels;
  final String? title;
  final double height;
  @override
  String get type => 'chart';
  @override
  List<PdfValidationIssue> validate() => [
        if (series.isEmpty)
          const PdfValidationIssue('Chart has no data series',
              severity: 'warning',),
        if (chartType == PdfChartType.pie && series.length > 1)
          const PdfValidationIssue('Pie charts use the first series only',
              severity: 'warning',),
      ];
  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'chartType': chartType.name,
        'series': series.map((s) => s.toJson()).toList(),
        'labels': labels,
        'title': title,
        'height': height,
      };
}

// ---- document furniture ---------------------------------------------------

class PdfStatusBadge extends PdfComponent {
  const PdfStatusBadge({required this.label, this.tone = 'blue'});
  final String label;
  final String tone; // green | orange | blue | red
  @override
  String get type => 'statusBadge';
  @override
  Map<String, Object?> toJson() => {'type': type, 'label': label, 'tone': tone};
}

class PdfInfoBox extends PdfComponent {
  const PdfInfoBox(this.text, {this.tone = 'blue'});
  final String text;
  final String tone;
  @override
  String get type => 'infoBox';
  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text, 'tone': tone};
}

class PdfSignatureBlock extends PdfComponent {
  const PdfSignatureBlock({required this.name, required this.role, this.dateLabel});
  final String name;
  final String role;

  /// Optional caption for a date line beneath the signature (e.g. 'Date').
  final String? dateLabel;
  @override
  String get type => 'signatureBlock';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'name': name, 'role': role, 'dateLabel': dateLabel};
}

class PdfHeader extends PdfComponent {
  const PdfHeader({required this.title});
  final String title;
  @override
  String get type => 'header';
  @override
  Map<String, Object?> toJson() => {'type': type, 'title': title};
}

class PdfFooter extends PdfComponent {
  const PdfFooter({required this.text});
  final String text;
  @override
  String get type => 'footer';
  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text};
}

class PdfPageNumber extends PdfComponent {
  const PdfPageNumber({this.format = '{page} / {total}'});
  final String format;
  @override
  String get type => 'pageNumber';
  @override
  Map<String, Object?> toJson() => {'type': type, 'format': format};
}

// ---- overlays: watermark & stamp ------------------------------------------

/// An inline, diagonal watermark drawn where it sits in the flow (distinct from
/// the page-background watermark configured on [PdfPostProcessing]).
class PdfWatermark extends PdfComponent {
  const PdfWatermark(this.text,
      {this.opacity = 0.12, this.angle = -0.6, this.fontSize = 48,});
  final String text;
  final double opacity; // 0..1
  final double angle; // radians
  final double fontSize;
  @override
  String get type => 'watermark';
  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'text': text,
        'opacity': opacity,
        'angle': angle,
        'fontSize': fontSize,
      };
}

/// A rubber-stamp label (e.g. PAID / CONFIDENTIAL): a rotated, tone-colored
/// bordered box with an optional date line.
class PdfStamp extends PdfComponent {
  const PdfStamp(this.text, {this.tone = 'red', this.date, this.angle = -0.25});
  final String text;
  final String tone; // green | orange | blue | red
  final String? date;
  final double angle; // radians
  @override
  String get type => 'stamp';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'text': text, 'tone': tone, 'date': date, 'angle': angle};
}

// ---- form fields (AcroForm) -----------------------------------------------

/// Base for interactive form fields. Each carries a unique [name] used by the
/// fill API and by the produced AcroForm.
sealed class PdfFormField extends PdfComponent {
  const PdfFormField({required this.name, required this.label});
  final String name;
  final String label;
  @override
  List<PdfValidationIssue> validate() => [
        if (name.trim().isEmpty)
          const PdfValidationIssue('Form field has no name'),
      ];
}

/// A single- or multi-line text field. A non-empty [value] renders as a filled
/// field; an empty one renders as an interactive AcroForm text input.
class PdfTextFormField extends PdfFormField {
  const PdfTextFormField({
    required super.name,
    super.label = '',
    this.value = '',
    this.width = 220,
    this.height = 22,
    this.multiline = false,
  });
  final String value;
  final double width;
  final double height;
  final bool multiline;
  PdfTextFormField withValue(String v) => PdfTextFormField(
      name: name,
      label: label,
      value: v,
      width: width,
      height: height,
      multiline: multiline,);
  @override
  String get type => 'textField';
  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'name': name,
        'label': label,
        'value': value,
        'width': width,
        'height': height,
        'multiline': multiline,
      };
}

/// An interactive checkbox with a label.
class PdfCheckboxField extends PdfFormField {
  const PdfCheckboxField(
      {required super.name, super.label = '', this.checked = false,});
  final bool checked;
  PdfCheckboxField withChecked(bool v) =>
      PdfCheckboxField(name: name, label: label, checked: v);
  @override
  String get type => 'checkboxField';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'name': name, 'label': label, 'checked': checked};
}

/// A signature field: a bordered signing area with a caption.
class PdfSignatureFormField extends PdfFormField {
  const PdfSignatureFormField({
    required super.name,
    super.label = 'Signature',
    this.width = 200,
    this.height = 60,
  });
  final double width;
  final double height;
  @override
  String get type => 'signatureField';
  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'name': name, 'label': label, 'width': width, 'height': height};
}
