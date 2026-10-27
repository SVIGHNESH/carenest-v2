import 'package:flutter/material.dart';

import '../core/initials.dart';
import '../l10n/gen/app_localizations.dart';
import 'tokens.dart';

enum CnButtonKind { primary, secondary, danger, text }

class CnButton extends StatelessWidget {
  const CnButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = CnButtonKind.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final CnButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final enabled = onPressed != null && !loading;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(CnSpace.radius));
    const size = Size(CnSpace.minTap, 52);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        else ...[
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
        ],
      ],
    );
    final text = Theme.of(context).textTheme.labelLarge;
    final handler = enabled ? onPressed : null;
    final Widget button = switch (kind) {
      CnButtonKind.primary || CnButtonKind.danger => FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: text,
            backgroundColor: kind == CnButtonKind.danger ? c.danger : c.accent,
            foregroundColor: c.accentFg,
            disabledBackgroundColor: loading ? c.accent : c.sunken,
            disabledForegroundColor: c.subtle,
          ),
          child: child,
        ),
      CnButtonKind.secondary => OutlinedButton(
          onPressed: handler,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: text,
            foregroundColor: c.fg,
            side: BorderSide(color: enabled ? c.borderStrong : c.border),
            backgroundColor: c.surface,
          ),
          child: child,
        ),
      CnButtonKind.text => TextButton(
          onPressed: handler,
          style: TextButton.styleFrom(
            minimumSize: size,
            shape: shape,
            textStyle: text,
            foregroundColor: c.accentText,
          ),
          child: child,
        ),
    };
    return Semantics(button: true, enabled: enabled, label: label, excludeSemantics: true, child: button);
  }
}

/// Flat card with a hairline border.
class CnCard extends StatelessWidget {
  const CnCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(CnSpace.lg),
    this.selected = false,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final radius = BorderRadius.circular(CnSpace.radius);
    final box = Ink(
      decoration: BoxDecoration(
        color: color ?? (selected ? c.accentSoft : c.surface),
        borderRadius: radius,
        border: Border.all(color: selected ? c.accent : c.border, width: selected ? 1.5 : 1),
      ),
      child: Padding(padding: padding, child: child),
    );
    final w = Material(
      type: MaterialType.transparency,
      child: onTap == null
          ? box
          : InkWell(onTap: onTap, borderRadius: radius, child: box),
    );
    return semanticLabel == null
        ? w
        : Semantics(label: semanticLabel, button: onTap != null, container: true, child: w);
  }
}

enum Tone { neutral, accent, success, warning, danger, info }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = Tone.neutral});
  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final (bg, fg) = switch (tone) {
      Tone.accent => (c.accentSoft, c.accentText),
      Tone.success => (c.successSoft, c.success),
      Tone.warning => (c.warningSoft, c.warning),
      Tone.danger => (c.dangerSoft, c.danger),
      Tone.info => (c.infoSoft, c.info),
      Tone.neutral => (c.sunken, c.fg2),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// Inline message box (info, warning, error).
class CnBanner extends StatelessWidget {
  const CnBanner({super.key, required this.message, this.tone = Tone.info, this.action});
  final String message;
  final Tone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final (bg, fg, icon) = switch (tone) {
      Tone.danger => (c.dangerSoft, c.danger, Icons.error_outline),
      Tone.warning => (c.warningSoft, c.warning, Icons.warning_amber_rounded),
      Tone.success => (c.successSoft, c.success, Icons.check_circle_outline),
      _ => (c.infoSoft, c.info, Icons.info_outline),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(CnSpace.md),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(CnSpace.radius)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: CnSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.fg)),
                    if (action != null) ...[const SizedBox(height: CnSpace.sm), action!],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar holding the primary action(s), above the system inset.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.note});
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note != null) ...[
                Text(note!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 10),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Title block with "Step x of y" and a thin progress bar for the booking flow.
class StepHeader extends StatelessWidget implements PreferredSizeWidget {
  const StepHeader({super.key, required this.step, required this.total, required this.title, this.onClose});
  final int step;
  final int total;
  final String title;
  final VoidCallback? onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppBar(
      title: Semantics(
        header: true,
        label: '$title, ${l.stepOf(step, total)}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(l.stepOf(step, total), style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
      actions: [
        if (onClose != null)
          IconButton(
            tooltip: l.close,
            constraints: const BoxConstraints(minWidth: CnSpace.minTap, minHeight: CnSpace.minTap),
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(6),
        child: LinearProgressIndicator(value: step / total, minHeight: 3),
      ),
    );
  }
}

class CnTextField extends StatelessWidget {
  const CnTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.prefixText,
    this.maxLength,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.errorText,
    this.helper,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final String? prefixText;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String? errorText;
  final String? helper;
  final TextCapitalization textCapitalization;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      maxLength: maxLength,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: readOnly ? c.muted : c.fg),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        counterText: '',
        errorText: errorText,
        helperText: helper,
        suffixIcon: suffix,
        fillColor: readOnly ? c.sunken : null,
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 56});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: TextStyle(fontFamily: 'Inter', fontSize: size * 0.36, fontWeight: FontWeight.w600, color: c.accentText),
        ),
      ),
    );
  }
}

/// Radio-style selectable row.
class SelectTile extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.disabled = false,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final theme = Theme.of(context).textTheme;
    final fg = disabled ? c.subtle : c.fg;
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      selected: selected,
      label: [title, if (subtitle != null) subtitle!].join(', '),
      excludeSemantics: true,
      onTap: disabled ? null : onTap,
      child: CnCard(
        onTap: disabled ? null : onTap,
        selected: selected,
        color: disabled ? c.sunken : null,
        padding: const EdgeInsets.symmetric(horizontal: CnSpace.lg, vertical: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: CnSpace.md)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.titleSmall?.copyWith(color: fg, fontSize: 15)),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.bodySmall?.copyWith(color: disabled ? c.muted : c.muted)),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: disabled ? c.subtle : (selected ? c.accent : c.borderStrong),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 108, child: Text(label, style: t.bodyMedium?.copyWith(color: context.cn.muted))),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: emphasize ? t.titleMedium : t.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CnLoading extends StatelessWidget {
  const CnLoading({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: AppLocalizations.of(context).loading,
          child: const CircularProgressIndicator(),
        ),
      );
}

class CnMessageView extends StatelessWidget {
  const CnMessageView({super.key, required this.icon, required this.title, this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.cn;
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: c.sunken, shape: BoxShape.circle),
                    child: Icon(icon, color: c.muted, size: 30),
                  ),
                ),
                const SizedBox(height: CnSpace.lg),
                Text(title, style: t.titleMedium, textAlign: TextAlign.center),
                if (body != null) ...[
                  const SizedBox(height: CnSpace.sm),
                  Text(body!, style: t.bodyMedium?.copyWith(color: c.muted), textAlign: TextAlign.center),
                ],
                if (actionLabel != null) ...[
                  const SizedBox(height: CnSpace.xl),
                  CnButton(label: actionLabel!, onPressed: onAction, kind: CnButtonKind.secondary, expand: false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
