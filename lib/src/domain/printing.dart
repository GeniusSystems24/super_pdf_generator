// DOMAIN · printing. Pure Dart. Printer descriptors and print settings.

import 'package:meta/meta.dart';

import 'value_objects.dart';

/// A discovered printer device.
@immutable
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    this.url,
    this.model,
    this.location,
    this.isDefault = false,
    this.isAvailable = true,
  });

  /// Stable identifier (the platform printer URL/handle).
  final String id;
  final String name;
  final String? url;
  final String? model;
  final String? location;
  final bool isDefault;
  final bool isAvailable;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'url': url,
        'model': model,
        'location': location,
        'isDefault': isDefault,
        'isAvailable': isAvailable,
      };
}

/// Colour handling for a print job.
enum PrintColorMode { color, monochrome }

/// Duplex mode for a print job.
enum PrintDuplexMode { simplex, longEdge, shortEdge }

/// User-selectable print settings. Applied best-effort by the print gateway;
/// some platforms surface these in the native dialog rather than honouring
/// them directly.
@immutable
class PrintSettings {
  const PrintSettings({
    this.copies = 1,
    this.colorMode = PrintColorMode.color,
    this.duplex = PrintDuplexMode.simplex,
    this.paperSize,
    this.orientation,
    this.pageRanges = const <String>[],
  });

  final int copies;
  final PrintColorMode colorMode;
  final PrintDuplexMode duplex;
  final PdfPageSize? paperSize;
  final PdfPageOrientation? orientation;

  /// Human page ranges, e.g. ['1-3', '5']. Empty = all pages.
  final List<String> pageRanges;

  PrintSettings copyWith({
    int? copies,
    PrintColorMode? colorMode,
    PrintDuplexMode? duplex,
    PdfPageSize? paperSize,
    PdfPageOrientation? orientation,
    List<String>? pageRanges,
  }) =>
      PrintSettings(
        copies: copies ?? this.copies,
        colorMode: colorMode ?? this.colorMode,
        duplex: duplex ?? this.duplex,
        paperSize: paperSize ?? this.paperSize,
        orientation: orientation ?? this.orientation,
        pageRanges: pageRanges ?? this.pageRanges,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'copies': copies,
        'colorMode': colorMode.name,
        'duplex': duplex.name,
        'paperSize': paperSize?.toJson(),
        'orientation': orientation?.name,
        'pageRanges': pageRanges,
      };
}
