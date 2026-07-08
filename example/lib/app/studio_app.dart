import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import 'studio_shell.dart';
import 'studio_theme.dart';

/// Root of Folio Studio — the reference demonstration application.
///
/// Owns the single [PdfClient] (built at this composition seam via
/// `createStudioClient`) and the [BuilderController] presentation model, plus
/// the UI theme mode and locale. Everything below reads these; nothing else
/// news up the client.
class StudioApp extends StatefulWidget {
  const StudioApp({super.key});
  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  late final PdfClient _client = createStudioClient();
  late final BuilderController _builder = BuilderController(_client);

  ThemeMode _mode = ThemeMode.dark;
  String _locale = 'en';

  @override
  void dispose() {
    _builder.dispose();
    _client.dispose();
    super.dispose();
  }

  void _toggleTheme() =>
      setState(() => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void _toggleLocale() => setState(() {
        _locale = _locale == 'en' ? 'ar' : 'en';
        _builder.setDirection(_locale == 'ar' ? PdfDirection.rtl : PdfDirection.ltr);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Folio Studio',
      theme: StudioTheme.light(),
      darkTheme: StudioTheme.dark(),
      themeMode: _mode,
      home: StudioShell(
        client: _client,
        builder: _builder,
        themeMode: _mode,
        locale: _locale,
        onToggleTheme: _toggleTheme,
        onToggleLocale: _toggleLocale,
      ),
    );
  }
}
