// DOMAIN · sharing targets. Pure Dart. No Flutter, no dart:io, no plugins.
//
// The SDK models the delivery targets a share action can route to. The concrete
// [ShareGateway] adapter maps these onto the platform share sheet (which itself
// surfaces email, Bluetooth and installed apps) — see infrastructure.

/// A destination a produced document can be shared to.
///
/// The platform share sheet is the router: selecting [system] opens the full
/// sheet, while the more specific targets are hints the adapter honours where
/// the OS exposes them (otherwise it falls back to the system sheet).
enum PdfShareTarget {
  /// The full platform share sheet (email, Bluetooth, apps, cloud …).
  system,

  /// An email client, pre-addressed where possible.
  email,

  /// Bluetooth device transfer.
  bluetooth,

  /// A messaging app (WhatsApp, Signal, SMS …).
  messaging,

  /// A cloud drive / files provider.
  cloud,

  /// Hand off to the OS print pipeline.
  print,
}

/// Human-readable labels (EN/AR) for a [PdfShareTarget].
extension PdfShareTargetLabels on PdfShareTarget {
  String get label => switch (this) {
        PdfShareTarget.system => 'Share sheet',
        PdfShareTarget.email => 'Email',
        PdfShareTarget.bluetooth => 'Bluetooth',
        PdfShareTarget.messaging => 'Messaging',
        PdfShareTarget.cloud => 'Cloud drive',
        PdfShareTarget.print => 'Print',
      };

  String get labelAr => switch (this) {
        PdfShareTarget.system => 'قائمة المشاركة',
        PdfShareTarget.email => 'البريد الإلكتروني',
        PdfShareTarget.bluetooth => 'بلوتوث',
        PdfShareTarget.messaging => 'المراسلة',
        PdfShareTarget.cloud => 'التخزين السحابي',
        PdfShareTarget.print => 'طباعة',
      };
}
