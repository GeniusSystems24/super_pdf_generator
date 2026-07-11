/// Reading direction for a report.
enum ReportDir {
  ltr,
  rtl;

  bool get isRtl => this == ReportDir.rtl;
  bool get isLtr => this == ReportDir.ltr;
}
