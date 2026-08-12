import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';

class HomeScreenQuickActionButton extends StatelessWidget {
  final String text;
  final String? label;
  final IconData icon;
  final double width;
  final bool vertical;
  final void Function() onPressed;
  final void Function()? onSecondaryPressed;
  final bool disabled;

  const HomeScreenQuickActionButton({
    super.key,
    required this.text,
    this.label,
    required this.icon,
    required this.width,
    this.vertical = false,
    required this.onPressed,
    this.onSecondaryPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final accentColor = disabled ? scheme.primary.withOpacity(0.5) : scheme.primary;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;

    final buttonChildren = [
      Icon(icon, size: vertical ? 20 : 18, color: accentColor, weight: 1.0, applyTextScaling: true),
      Text(
        text,
        style: TextStyle(
          color:
              (isDark
                      ? scheme.onSurface
                      : Color.alphaBlend(accentColor.withOpacity(0.28), scheme.onSurface))
                  .withOpacity(disabled ? 0.5 : 1.0),
          fontSize: 13,
          height: 1.05,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ];

    final buttonContent = vertical
        ? Column(mainAxisAlignment: MainAxisAlignment.center, spacing: isDesktop ? 6.0 : 5.0, children: buttonChildren)
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            spacing: 8.0,
            children: buttonChildren,
          );

    final bg = isDark
        ? Color.alphaBlend(accentColor.withOpacity(disabled ? 0.06 : 0.14), scheme.surfaceContainerHighest)
        : Color.alphaBlend(accentColor.withOpacity(disabled ? 0.08 : 0.16), scheme.surface);

    return Semantics(
      label: text,
      tooltip: label,
      button: true,
      focusable: true,
      onLongPressHint: label,
      excludeSemantics: true, // replace child semantics with custom semantics
      container: true,
      child: SizedBox(
        width: width,
        child: GestureDetector(
          onLongPress: disabled || onSecondaryPressed == null
              ? null
              : () {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  onSecondaryPressed!();
                },
          onSecondaryTap: disabled || onSecondaryPressed == null
              ? null
              : () {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  onSecondaryPressed!();
                },
          child: FilledButton(
            onPressed: disabled
                ? null
                : () {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    onPressed();
                  },
            style: ButtonStyle(
              elevation: WidgetStateProperty.all(0),
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 10 : 14),
                  side: BorderSide(
                    color: accentColor.withOpacity(isDark ? 0.22 : 0.18),
                    width: 0.8,
                  ),
                ),
              ),
              padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: 10, vertical: isDesktop ? 14 : (vertical ? 12 : 10)),
              ),
              backgroundColor: WidgetStateProperty.all<Color>(bg),
              overlayColor: WidgetStateProperty.all<Color>(accentColor.withOpacity(0.12)),
            ),
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
