import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart' show Barcode;

import '../theme/report_theme.dart';

/// A QR block: a quiet-zone-padded QR code with an optional caption underneath
/// ("Scan to open").
class QrPanel {
  const QrPanel(
    this.theme, {
    required this.data,
    this.size = 84,
    this.caption = 'Scan to open',
    this.captionAr,
  });

  final ReportTheme theme;
  final String data;
  final double size;
  final String? caption;
  final String? captionAr;

  pw.Widget build() {
    final captionText =
        caption == null ? null : (theme.dir.isRtl ? (captionAr ?? caption) : caption);
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xffffffff),
            border: pw.Border.all(color: theme.palette.borderSoft, width: 0.6),
          ),
          child: pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: data,
            width: size,
            height: size,
            drawText: false,
            color: theme.palette.text,
          ),
        ),
        if (captionText != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(captionText, style: theme.caption()),
        ],
      ],
    );
  }
}
