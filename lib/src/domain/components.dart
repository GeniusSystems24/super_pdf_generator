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
            level: (json['level'] as num?)?.toInt() ?? 2);
      case 'paragraph':
        return PdfParagraph(json['text'] as String? ?? '');
      case 'richText':
        return PdfRichText(json['spans'] is List
            ? (json['spans'] as List).map((e) => e.toString()).toList()
            : const <String>[]);
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
            columns: (json['columns'] as num?)?.toInt() ?? 2);
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
                (p as List)[0].toString(), p.length > 1 ? p[1].toString() : ''))
            .toList());
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
            altText: json['altText'] as String?);
      case 'svg':
        return PdfSvg(json['data'] as String? ?? '', altText: json['altText'] as String?);
      case 'barcode':
        return PdfBarcode(json['value'] as String? ?? '',
            symbology: json['symbology'] as String? ?? 'code128');
      case 'qrCode':
        return PdfQrCode(json['value'] as String? ?? '');
      case 'statusBadge':
        return PdfStatusBadge(
            label: json['label'] as String? ?? 'STATUS',
            tone: json['tone'] as String? ?? 'blue');
      case 'infoBox':
        return PdfInfoBox(json['text'] as String? ?? '',
            tone: json['tone'] as String? ?? 'blue');
      case 'signatureBlock':
        return PdfSignatureBlock(
            name: json['name'] as String? ?? '',
            role: json['role'] as String? ?? '');
      case 'header':
        return PdfHeader(title: json['title'] as String? ?? '');
      case 'footer':
        return PdfFooter(text: json['text'] as String? ?? '');
      case 'pageNumber':
        return PdfPageNumber(format: json['format'] as String? ?? '{page} / {total}');
      case 'chart':
        return PdfChartPlaceholder(label: json['label'] as String? ?? 'Chart');
      case 'conditional':
        return PdfConditional(
            when: json['when'] as bool? ?? true, child: kids(json['children']));
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
                severity: 'warning'),
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

class PdfChartPlaceholder extends PdfComponent {
  const PdfChartPlaceholder({required this.label});
  final String label;
  @override
  String get type => 'chart';
  @override
  Map<String, Object?> toJson() => {'type': type, 'label': label};
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
  const PdfSignatureBlock({required this.name, required this.role});
  final String name;
  final String role;
  @override
  String get type => 'signatureBlock';
  @override
  Map<String, Object?> toJson() => {'type': type, 'name': name, 'role': role};
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
