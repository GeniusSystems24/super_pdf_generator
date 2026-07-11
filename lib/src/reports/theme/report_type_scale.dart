/// The type scale recovered from the reference documents, expressed once so
/// every component stays visually consistent. Values are PDF points; the
/// reference body copy sits at ~9pt with 8–8.5pt table content and ~13–15pt
/// document titles.
class ReportTypeScale {
  const ReportTypeScale({
    this.companyName = 11,
    this.companyInfo = 8.5,
    this.titleArabic = 14,
    this.title = 14,
    this.subtitle = 9.5,
    this.printed = 8,
    this.boxHeader = 9,
    this.label = 8.5,
    this.value = 9,
    this.tableHeader = 8.5,
    this.tableCell = 8.5,
    this.groupHeader = 9.5,
    this.subtotal = 9,
    this.grandTotal = 10,
    this.summaryTitle = 11,
    this.summaryRow = 9,
    this.summaryTotal = 10.5,
    this.note = 8.5,
    this.footer = 8,
    this.signature = 9,
    this.caption = 7.5,
  });

  final double companyName;
  final double companyInfo;
  final double titleArabic;
  final double title;
  final double subtitle;
  final double printed;
  final double boxHeader;
  final double label;
  final double value;
  final double tableHeader;
  final double tableCell;
  final double groupHeader;
  final double subtotal;
  final double grandTotal;
  final double summaryTitle;
  final double summaryRow;
  final double summaryTotal;
  final double note;
  final double footer;
  final double signature;
  final double caption;

  static const ReportTypeScale standard = ReportTypeScale();
}
