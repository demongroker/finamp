import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:finamp/services/finamp_settings_helper.dart';

const jellyfinBlueColor = Color(0xFF00A4DC);
const jellyfinPurpleColor = Color(0xFFAA5CC3);

/// Jellyamp light fallback: purple primary for brand cohesion.
const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Primary — Jellyfin purple
  primary: Color(0xFF8B3BA8),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFAD7FF),
  onPrimaryContainer: Color(0xFF330044),
  // Secondary
  secondary: Color(0xFF675A66),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFEFDBE8),
  onSecondaryContainer: Color(0xFF221920),
  // Tertiary — Jellyfin blue as pair
  tertiary: Color(0xFF00668A),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFC4E8FF),
  onTertiaryContainer: Color(0xFF001E2C),
  // Error
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  // Background & Surface
  background: Color(0xFFFFF7FC),
  onBackground: Color(0xFF1E1A1E),
  surface: Color(0xFFFFF7FC),
  surfaceContainerHighest: Color(0xFFF6EEF4),
  onSurface: Color(0xFF1E1A1E),
  surfaceVariant: Color(0xFFEBDFE8),
  onSurfaceVariant: Color(0xFF4D444C),
  // Other colors
  outline: Color(0xFF7E747C),
  onInverseSurface: Color(0xFFF7EFF3),
  inverseSurface: Color(0xFF332F33),
  inversePrimary: Color(0xFFEFB0FF),
  shadow: Color(0xFF000000),
  surfaceTint: jellyfinPurpleColor,
  outlineVariant: Color(0xFFCFC3CC),
  scrim: Color(0xFF000000),
);

/// Jellyamp dark fallback: Jellyfin purple primary (not stock Finamp blue).
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Primary — Jellyfin purple
  primary: jellyfinPurpleColor,
  onPrimary: Color(0xFF3D0050),
  primaryContainer: Color(0xFF762A90),
  onPrimaryContainer: Color(0xFFFAD7FF),
  // Secondary — cool slate for contrast
  secondary: Color(0xFFB0C8D4),
  onSecondary: Color(0xFF1B333F),
  secondaryContainer: Color(0xFF334A55),
  onSecondaryContainer: Color(0xFFCCE8F8),
  // Tertiary — Jellyfin blue as accent pair
  tertiary: Color(0xFF7BD0FF),
  onTertiary: Color(0xFF001E2C),
  tertiaryContainer: Color(0xFF004C68),
  onTertiaryContainer: Color(0xFFC3E7FF),
  // Error
  error: Color(0xFFFFB4AB),
  errorContainer: Color(0xFF93000A),
  onError: Color(0xFF690005),
  onErrorContainer: Color(0xFFFFDAD6),
  // Background & Surface — slightly lifted, less muddy
  background: Color(0xFF0E0F12),
  onBackground: Color(0xFFE6E2E8),
  surface: Color(0xFF0E0F12),
  surfaceContainerHighest: Color(0xFF1A1620),
  onSurface: Color(0xFFE6E2E8),
  surfaceVariant: Color(0xFF3A3440),
  onSurfaceVariant: Color(0xFFCBC3D0),
  // Other colors
  outline: Color(0xFF958E99),
  onInverseSurface: Color(0xFF1C1B1F),
  inverseSurface: Color(0xFFE6E2E8),
  inversePrimary: Color(0xFF8B3BA8),
  shadow: Color(0xFF000000),
  surfaceTint: jellyfinPurpleColor,
  outlineVariant: Color(0xFF4A4450),
  scrim: Color(0xFF000000),
);

/// If [color] is provided -> returns a generated color scheme
/// otherwise falls back to default color schemes
/// [lightColorScheme] or [darkColorScheme]
ColorScheme getColorScheme(Color? color, Brightness brightness, bool amoledTheme) {
  ColorScheme scheme = brightness == Brightness.dark ? darkColorScheme : lightColorScheme;

  if (color != null) {
    scheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }

  if (amoledTheme && brightness == Brightness.dark) {
    scheme = scheme.copyWith(background: Color(0xFF000000), surface: Color(0xFF000000));
  }

  return scheme;
}
