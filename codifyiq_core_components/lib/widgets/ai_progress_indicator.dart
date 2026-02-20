import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A subtle progress indicator for AI-enabled features.
///
/// Intended to provide a gentle visual cue that an AI-powered action is
/// being executed, distinguishing it from standard loading states. The widget
/// combines a [CircularProgressIndicator] with a [Shimmer] effect that sweeps
/// across the indicator and accompanying text.
///
/// ## Theming & Color Customization
///
/// By default, colors are derived from the app's [ThemeData]:
/// - Shimmer base color: `colorScheme.onSurface`
/// - Shimmer highlight colors: `colorScheme.primary` and `colorScheme.tertiary`
/// - Text style: `textTheme.bodyLarge`
///
/// To use custom colors instead of the theme defaults, provide a custom
/// [ThemeData] or [ColorScheme] via a [Theme] widget wrapping the indicator,
/// or override the text appearance directly via [textStyle].
///
/// ## Shimmer Tuning
///
/// The shimmer effect can be tuned via [shimmerPeriod] to control sweep speed
/// and [shimmerIntensity] to boost highlight color contrast. The intensity
/// boost is brightness-aware, adjusting automatically for light and dark
/// modes. An optional [backgroundColor] can be applied to increase visibility
/// against certain surfaces.
///
/// ## Progress Indicator
///
/// The [CircularProgressIndicator] can be hidden by setting
/// [showProgressIndicator] to `false`, leaving only the shimmer text.
class AiProgressIndicator extends StatelessWidget {
  /// Creates an [AiProgressIndicator].
  ///
  /// [text] is the message displayed alongside the progress indicator.
  /// [textStyle] optionally overrides the default text style.
  const AiProgressIndicator({
    super.key,
    required this.text,
    this.textStyle,
    this.backgroundColor,
    this.shimmerPeriod = const Duration(milliseconds: 1500),
    this.shimmerIntensity = 0.0,
    this.showProgressIndicator = true,
  });

  /// The message displayed alongside the progress indicator.
  final String text;

  /// Optional text style override.
  ///
  /// Defaults to `Theme.of(context).textTheme.bodyLarge`.
  final TextStyle? textStyle;

  /// Optional background color applied behind the shimmer content.
  ///
  /// Helps increase shimmer visibility against certain surfaces.
  final Color? backgroundColor;

  /// Duration of one full shimmer sweep cycle.
  ///
  /// Slower values make the shimmer more deliberate and visible.
  /// Defaults to 1500 milliseconds.
  final Duration shimmerPeriod;

  /// Controls the color intensity boost applied to the shimmer highlight colors.
  ///
  /// A value of `0.0` (default) uses the theme colors as-is. Higher values
  /// increase the saturation and lightness of the highlight colors to create
  /// stronger contrast against the base color. Values are clamped to `[0.0, 1.0]`.
  final double shimmerIntensity;

  /// Whether to display the [CircularProgressIndicator].
  ///
  /// Defaults to `true`. Set to `false` to show only the shimmer text.
  final bool showProgressIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intensity = shimmerIntensity.clamp(0.0, 1.0);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = _boostBase(
      theme.colorScheme.onSurface,
      intensity,
      isDark,
    );
    Widget shimmer = Shimmer(
      period: shimmerPeriod,
      gradient: LinearGradient(
        colors: [
          baseColor,
          _boost(theme.colorScheme.tertiary, intensity, isDark),
          _boost(theme.colorScheme.primary, intensity, isDark),
          _boost(theme.colorScheme.tertiary, intensity, isDark),
          baseColor,
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgressIndicator) ...[
            Padding(
              padding: const EdgeInsets.all(4),
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Flexible(
            child: Text(
              text,
              style: textStyle ?? theme.textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (backgroundColor != null) {
      shimmer = Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: shimmer,
      );
    }
    return shimmer;
  }

  /// Shifts the base (non-highlight) color toward a mid-tone so the shimmer
  /// sweep remains visible at higher intensities.
  ///
  /// In light mode, `onSurface` is near-black which drowns the shimmer effect.
  /// This pulls the base toward a mid-gray proportional to [amount].
  static Color _boostBase(Color color, double amount, bool isDark) {
    if (amount == 0.0) return color;
    final hsl = HSLColor.fromColor(color);
    final targetLightness = isDark ? 0.65 : 0.35;
    final boostedLightness =
        hsl.lightness + (targetLightness - hsl.lightness) * amount;
    return hsl.withLightness(boostedLightness.clamp(0.1, 0.9)).toColor();
  }

  /// Adjusts the highlight [color]'s saturation and lightness by [amount]
  /// (0.0–1.0) to maximize shimmer contrast against the base color.
  ///
  /// Saturation is increased to make highlight colors more vivid. Lightness
  /// is pushed toward a vibrant target so the highlights stand out from the
  /// base in both light and dark modes.
  static Color _boost(Color color, double amount, bool isDark) {
    if (amount == 0.0) return color;
    final hsl = HSLColor.fromColor(color);
    final targetLightness = isDark ? 0.75 : 0.55;
    final boostedLightness =
        hsl.lightness + (targetLightness - hsl.lightness) * amount;
    return hsl
        .withSaturation((hsl.saturation + amount * 0.5).clamp(0.0, 1.0))
        .withLightness(boostedLightness.clamp(0.1, 0.9))
        .toColor();
  }
}
