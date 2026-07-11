import 'package:pdf/widgets.dart' as pw;

import '../core/report_models.dart';
import '../theme/report_theme.dart';

/// The bilingual company header that opens every report: English company
/// details on the leading edge, Arabic details on the trailing edge, an
/// optional centered logo, and a strong hairline beneath.
///
/// Per the reference behaviour, the two language columns keep their sides
/// (English left / Arabic right) in **both** LTR and RTL documents — only the
/// body of the report mirrors. Set [bilingual] to false for a single-language
/// letterhead aligned with [singleAlign].
class CompanyHeader {
  const CompanyHeader(
    this.theme,
    this.company, {
    this.bilingual = true,
    this.singleAlign = CellAlign.start,
  });

  final ReportTheme theme;
  final ReportCompany company;
  final bool bilingual;
  final CellAlign singleAlign;

  // Standard Arabic label prefixes for the contact lines.
  static const _vatAr = 'الرقم الضريبي';
  static const _crAr = 'السجل التجاري';
  static const _phoneAr = 'الهاتف';
  static const _emailAr = 'البريد';

  List<String> _enLines() => [
        if (company.address != null && company.address!.isNotEmpty) company.address!,
        if (company.vatNumber != null) 'VAT No: ${company.vatNumber}',
        if (company.crNumber != null) 'CR No: ${company.crNumber}',
        if (company.phone != null) 'Phone: ${company.phone}',
        if (company.email != null) 'Email: ${company.email}',
        if (company.tagline != null && company.tagline!.isNotEmpty) company.tagline!,
      ];

  List<String> _arLines() => [
        if (company.addressAr != null && company.addressAr!.isNotEmpty) company.addressAr!,
        if (company.vatNumber != null) '$_vatAr: ${company.vatNumber}',
        if (company.crNumber != null) '$_crAr: ${company.crNumber}',
        if (company.phone != null) '$_phoneAr: ${company.phone}',
        if (company.email != null) '$_emailAr: ${company.email}',
      ];

  pw.Widget _enColumn() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(company.name, style: theme.companyName()),
          pw.SizedBox(height: 3),
          for (final l in _enLines())
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5),
              child: pw.Text(l, style: theme.companyInfo()),
            ),
        ],
      );

  pw.Widget _arColumn() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(company.nameAr ?? company.name,
              style: theme.arabic(size: theme.scale.companyName, bold: true),
              textDirection: pw.TextDirection.rtl,),
          pw.SizedBox(height: 3),
          for (final l in _arLines())
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5),
              child: pw.Text(l,
                  style: theme.arabic(size: theme.scale.companyInfo, color: theme.palette.textMuted),
                  textDirection: pw.TextDirection.rtl,),
            ),
        ],
      );

  pw.Widget _logo() => pw.Container(
        width: 64,
        height: 64,
        alignment: pw.Alignment.center,
        child: company.logo != null
            ? pw.Image(pw.MemoryImage(company.logo!), fit: pw.BoxFit.contain)
            : null,
      );

  pw.Widget build() {
    final children = <pw.Widget>[];
    if (bilingual && (company.nameAr != null || company.addressAr != null)) {
      children.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _enColumn()),
            if (company.logo != null) _logo(),
            pw.Expanded(child: _arColumn()),
          ],
        ),
      );
    } else {
      final alignEnd = singleAlign == CellAlign.end;
      children.add(
        pw.Row(
          mainAxisAlignment:
              alignEnd ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            if (company.logo != null && !alignEnd) ...[_logo(), pw.SizedBox(width: 10)],
            pw.Column(
              crossAxisAlignment:
                  alignEnd ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(company.name, style: theme.companyName()),
                pw.SizedBox(height: 3),
                for (final l in _enLines())
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1.5),
                    child: pw.Text(l, style: theme.companyInfo()),
                  ),
              ],
            ),
            if (company.logo != null && alignEnd) ...[pw.SizedBox(width: 10), _logo()],
          ],
        ),
      );
    }

    children.add(pw.SizedBox(height: 8));
    children.add(pw.Container(height: 1, color: theme.palette.rule));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
