import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/builder/builder_screen.dart';
import '../features/preview/preview_screen.dart';
import '../features/processing/processing_screen.dart';
import '../features/batch/batch_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/reference/reference_screens.dart';
import '../shared/gl_tokens.dart';
import '../shared/gl_widgets.dart';

/// A single navigable destination.
class StudioDest {
  const StudioDest(this.group, this.label, this.icon, this.markerColor, this.build);
  final String group;
  final String label;
  final IconData icon;
  final Color markerColor;
  final Widget Function(BuildContext) build;
}

/// The Studio chrome: grouped left rail + top app bar + workspace. Mirrors the
/// approved Web IA (Overview · Build · Output · Process · Quality · Extend) and
/// collapses the rail to icons on narrow (tablet) widths.
class StudioShell extends StatefulWidget {
  const StudioShell({
    super.key,
    required this.client,
    required this.builder,
    required this.themeMode,
    required this.locale,
    required this.onToggleTheme,
    required this.onToggleLocale,
  });

  final PdfClient client;
  final BuilderController builder;
  final ThemeMode themeMode;
  final String locale;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  int _index = 0;

  late final List<StudioDest> _dests = <StudioDest>[
    StudioDest('OVERVIEW', 'Dashboard', Icons.grid_view_rounded, const Color(0xFF8D90A0),
        (c) => DashboardScreen(client: widget.client, builder: widget.builder, onNavigate: _goByLabel)),
    StudioDest('BUILD', 'Document Builder', Icons.description_outlined, const Color(0xFF4A7CFF),
        (c) => BuilderScreen(controller: widget.builder, onPreview: () => _goByLabel('PDF Preview'))),
    StudioDest('BUILD', 'Component Gallery', Icons.category_outlined, const Color(0xFF4A7CFF),
        (c) => const ComponentGalleryScreen()),
    StudioDest('OUTPUT', 'PDF Preview', Icons.visibility_outlined, const Color(0xFF4A7CFF),
        (c) => PreviewScreen(controller: widget.builder)),
    StudioDest('OUTPUT', 'Printing', Icons.print_outlined, const Color(0xFF4A7CFF),
        (c) => PreviewScreen(controller: widget.builder, printMode: true)),
    StudioDest('PROCESS', 'PDF Processing', Icons.content_cut_rounded, const Color(0xFF1DB88A),
        (c) => ProcessingScreen(client: widget.client, builder: widget.builder)),
    StudioDest('PROCESS', 'Batch Generation', Icons.layers_outlined, const Color(0xFF1DB88A),
        (c) => BatchScreen(client: widget.client, builder: widget.builder)),
    StudioDest('PROCESS', 'Job Manager', Icons.list_alt_rounded, const Color(0xFF1DB88A),
        (c) => JobsScreen(client: widget.client)),
    StudioDest('QUALITY', 'RTL & Localization', Icons.translate_rounded, const Color(0xFFF97316),
        (c) => RtlScreen(builder: widget.builder)),
    StudioDest('QUALITY', 'Error Handling', Icons.error_outline_rounded, const Color(0xFFF97316),
        (c) => const ErrorHandlingScreen()),
    StudioDest('QUALITY', 'Performance', Icons.speed_rounded, const Color(0xFFF97316),
        (c) => const PerformanceScreen()),
    StudioDest('EXTEND', 'Templates', Icons.dashboard_customize_outlined, const Color(0xFF8D90A0),
        (c) => TemplatesScreen(builder: widget.builder, onOpen: () => _goByLabel('Document Builder'))),
    StudioDest('EXTEND', 'API Reference', Icons.code_rounded, const Color(0xFF8D90A0),
        (c) => const ApiReferenceScreen()),
    StudioDest('EXTEND', 'Settings', Icons.settings_outlined, const Color(0xFF8D90A0),
        (c) => const SettingsScreen()),
  ];

  void _goByLabel(String label) {
    final i = _dests.indexWhere((d) => d.label == label);
    if (i >= 0) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    final dest = _dests[_index];
    return Scaffold(
      backgroundColor: gl.bg,
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              dests: _dests,
              index: _index,
              collapsed: !wide,
              onSelect: (i) => setState(() => _index = i),
            ),
            Expanded(
              child: Column(
                children: [
                  _AppBar(
                    group: dest.group,
                    label: dest.label,
                    builder: widget.builder,
                    themeMode: widget.themeMode,
                    locale: widget.locale,
                    onToggleTheme: widget.onToggleTheme,
                    onToggleLocale: widget.onToggleLocale,
                  ),
                  Expanded(child: dest.build(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.dests, required this.index, required this.collapsed, required this.onSelect});
  final List<StudioDest> dests;
  final int index;
  final bool collapsed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final width = collapsed ? 60.0 : 226.0;
    String? lastGroup;
    final children = <Widget>[];
    for (var i = 0; i < dests.length; i++) {
      final d = dests[i];
      if (d.group != lastGroup) {
        lastGroup = d.group;
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(collapsed ? 0 : 12, 14, 12, 5),
          child: collapsed
              ? Center(child: Container(width: 16, height: 1.5, color: gl.border))
              : Text(d.group, style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 9, letterSpacing: 1.3)),
        ));
      }
      children.add(_NavItem(dest: d, selected: i == index, collapsed: collapsed, onTap: () => onSelect(i)));
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: gl.bg,
        border: Border(right: BorderSide(color: gl.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 0 : 14, 14, 14, 8),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: gl.accent, borderRadius: const BorderRadius.all(GlRadius.md)),
                  alignment: Alignment.center,
                  child: const Text('F', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 9),
                  Text('Folio', style: GlType.display(context, size: 15)),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: gl.border), borderRadius: GlRadius.pill),
                    child: Text('STUDIO', style: TextStyle(fontSize: 8, color: gl.fg4, letterSpacing: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 12), children: children)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.dest, required this.selected, required this.collapsed, required this.onTap});
  final StudioDest dest;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final content = Container(
      margin: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 8, vertical: 1),
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 9, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? gl.hover : Colors.transparent,
        borderRadius: const BorderRadius.all(GlRadius.md),
        border: Border(left: BorderSide(color: selected ? gl.accent : Colors.transparent, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(dest.icon, size: 16, color: selected ? gl.accent : gl.fg3),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(dest.label,
                  overflow: TextOverflow.ellipsis,
                  style: GlType.body(context,
                      size: 12.5,
                      weight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? gl.fg1 : gl.fg3)),
            ),
          ],
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(GlRadius.md),
        onTap: onTap,
        child: collapsed ? Tooltip(message: dest.label, child: content) : content,
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.group,
    required this.label,
    required this.builder,
    required this.themeMode,
    required this.locale,
    required this.onToggleTheme,
    required this.onToggleLocale,
  });
  final String group;
  final String label;
  final BuilderController builder;
  final ThemeMode themeMode;
  final String locale;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Container(
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
      child: Row(
        children: [
          Text('$group', style: GlType.label(context).copyWith(fontSize: 10)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('•', style: TextStyle(color: gl.fg4)),
          ),
          Text(label.toUpperCase(), style: GlType.label(context, color: gl.fg1).copyWith(fontSize: 10)),
          const Spacer(),
          _GenerationStatus(builder: builder),
          const SizedBox(width: 14),
          GlSegmented<String>(
            value: locale,
            segments: const {'en': 'EN', 'ar': 'ع'},
            onChanged: (_) => onToggleLocale(),
          ),
          const SizedBox(width: 8),
          GlSegmented<ThemeMode>(
            value: themeMode,
            segments: const {ThemeMode.dark: 'Dark', ThemeMode.light: 'Light'},
            onChanged: (_) => onToggleTheme(),
          ),
        ],
      ),
    );
  }
}

/// Live generation-status indicator, bound to the builder's presentation model.
class _GenerationStatus extends StatelessWidget {
  const _GenerationStatus({required this.builder});
  final BuilderController builder;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return AnimatedBuilder(
      animation: builder,
      builder: (context, _) {
        final (label, color, busy) = switch (builder.generation) {
          PdfGenIdle() => ('Renderer ready', gl.green, false),
          PdfGenPreparing() => ('Preparing…', gl.accent, true),
          PdfGenGenerating(:final progress) => ('Generating ${(progress * 100).round()}%', gl.accent, true),
          PdfGenCompleted() => ('Generated', gl.green, false),
          PdfGenFailed() => ('Generation failed', gl.danger, false),
          PdfGenCancelled() => ('Cancelled', gl.fg3, false),
        };
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(width: 9, height: 9, child: CircularProgressIndicator(strokeWidth: 1.8, color: color))
            else
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(label, style: GlType.body(context, size: 11.5, color: color)),
          ],
        );
      },
    );
  }
}
