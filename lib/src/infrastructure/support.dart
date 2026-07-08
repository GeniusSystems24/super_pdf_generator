// INFRASTRUCTURE · support adapters — logging + fonts.

import 'dart:developer' as developer;
import 'dart:typed_data';

import '../application/contracts.dart';

/// Discards all log events (the default).
class SilentPdfLogger implements PdfLogger {
  const SilentPdfLogger();
  @override
  void log(LogEvent event) {}
}

/// Forwards events to `dart:developer` — visible in the debugger/DevTools.
class ConsolePdfLogger implements PdfLogger {
  const ConsolePdfLogger();
  @override
  void log(LogEvent event) => developer.log(
        event.message,
        name: 'folio.${event.level}',
        error: event.data,
      );
}

/// A simple in-memory font registry. The app registers TTF bytes (e.g. loaded
/// via `PdfGoogleFonts`) for Latin + Arabic families; the renderer resolves
/// them for custom/RTL documents.
class InMemoryFontRegistry implements FontRegistry {
  final Map<String, Uint8List> _fonts = <String, Uint8List>{};

  String _key(String family, bool bold, bool italic) => '$family|$bold|$italic';

  @override
  Future<Uint8List?> resolve(String family, {bool bold = false, bool italic = false}) async =>
      _fonts[_key(family, bold, italic)] ?? _fonts[_key(family, false, false)];

  @override
  void register(String family, Uint8List bytes, {bool bold = false, bool italic = false}) =>
      _fonts[_key(family, bold, italic)] = bytes;
}
