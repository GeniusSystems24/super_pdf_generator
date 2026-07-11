import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../components/page_footer.dart';
import '../theme/report_theme.dart';

/// Shared page scaffold for the reports: an A4 [pw.MultiPage] with 20pt margins,
/// the report font theme, the correct text direction and an optional running
/// [PageFooter]. Document builders assemble a flat widget list and hand it here.
class ReportDocument {
  /// Renders [body] to PDF bytes. [body] flows across pages automatically;
  /// insert `pw.NewPage()` widgets to force breaks.
  static Future<Uint8List> render({
    required ReportTheme theme,
    required List<pw.Widget> body,
    PageFooter? footer,
    String title = 'Report',
    String author = '',
    double margin = 20,
    double marginBottom = 30,
  }) async {
    final doc = pw.Document(
      title: title,
      author: author,
      theme: theme.buildPageTheme(),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: margin,
            marginRight: margin,
            marginTop: margin,
            marginBottom: marginBottom,
          ),
          textDirection: theme.textDirection,
          theme: theme.buildPageTheme(),
        ),
        footer: footer == null ? null : (context) => footer.build(context),
        build: (context) => body,
      ),
    );

    return doc.save();
  }
}

/// Small shared spacing helpers so builders read cleanly.
class Gap {
  static pw.Widget h(double v) => pw.SizedBox(height: v);
}
