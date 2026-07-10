// SHARED · GeniusLink widget vocabulary for Folio Studio.

import 'package:flutter/material.dart';

import 'gl_tokens.dart';

/// The signature 4px colored section-marker pill.
class GlSectionMarker extends StatelessWidget {
  const GlSectionMarker(this.color, {super.key, this.height = 18});
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: GlRadius.pill),
      );
}

/// The fundamental surface card: hairline border, 8px radius, soft lift.
class GlCard extends StatelessWidget {
  const GlCard({super.key, required this.child, this.padding = const EdgeInsets.all(GlSpace.s5)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gl.surface,
        borderRadius: GlRadius.card,
        border: Border.all(color: gl.border),
        boxShadow: [BoxShadow(color: gl.shadow, blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: child,
    );
  }
}

class GlSectionHeader extends StatelessWidget {
  const GlSectionHeader({super.key, required this.markerColor, required this.title, this.subtitle, this.trailing});
  final Color markerColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GlSectionMarker(markerColor, height: subtitle == null ? 18 : 34),
        const SizedBox(width: GlSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GlType.body(context, size: 15, weight: FontWeight.w700, color: context.gl.fg1)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: GlType.body(context, size: 12, color: context.gl.fg3)),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class GlEyebrow extends StatelessWidget {
  const GlEyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: GlType.label(context, color: color ?? context.gl.accent).copyWith(letterSpacing: 1.4));
}

class GlStatusPill extends StatelessWidget {
  const GlStatusPill(this.label, {super.key, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha:0.16), borderRadius: const BorderRadius.all(GlRadius.xl)),
        child: Text(label.toUpperCase(),
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: color)),
      );
}

class GlStatCard extends StatelessWidget {
  const GlStatCard({super.key, required this.label, required this.value, this.sub, this.subColor});
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return GlCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GlType.label(context).copyWith(fontSize: 9.5)),
          const SizedBox(height: 8),
          Text(value, style: GlType.mono(context, size: 24, color: gl.fg1, weight: FontWeight.w700)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: GlType.body(context, size: 11, color: subColor ?? gl.fg3)),
          ],
        ],
      ),
    );
  }
}

class GlPrimaryButton extends StatelessWidget {
  const GlPrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Material(
      color: gl.accent,
      borderRadius: const BorderRadius.all(GlRadius.md),
      child: InkWell(
        borderRadius: const BorderRadius.all(GlRadius.md),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (busy)
              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else if (icon != null)
              Icon(icon, size: 15, color: Colors.white),
            if (busy || icon != null) const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class GlGhostButton extends StatelessWidget {
  const GlGhostButton({super.key, required this.label, this.onPressed, this.icon, this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final fg = danger ? gl.danger : gl.fg2;
    return Material(
      color: gl.input,
      borderRadius: const BorderRadius.all(GlRadius.md),
      child: InkWell(
        borderRadius: const BorderRadius.all(GlRadius.md),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(GlRadius.md),
            border: Border.all(color: gl.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 7)],
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class GlSegmented<T> extends StatelessWidget {
  const GlSegmented({super.key, required this.value, required this.segments, required this.onChanged});
  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: gl.input,
        borderRadius: const BorderRadius.all(GlRadius.md),
        border: Border.all(color: gl.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final entry in segments.entries)
          GestureDetector(
            onTap: () => onChanged(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: entry.key == value ? gl.surface : Colors.transparent,
                borderRadius: const BorderRadius.all(GlRadius.sm),
                boxShadow: entry.key == value
                    ? [BoxShadow(color: gl.shadow, blurRadius: 3, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(entry.value,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: entry.key == value ? gl.fg1 : gl.fg3)),
            ),
          ),
      ]),
    );
  }
}

/// A labelled form field wrapper (uppercase label above the control).
class GlField extends StatelessWidget {
  const GlField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GlType.label(context).copyWith(fontSize: 9.5)),
          const SizedBox(height: 7),
          child,
        ],
      );
}
