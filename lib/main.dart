import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router.dart';
import 'features/pos/offline/offline_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th');
  runApp(const ProviderScope(child: TurboPosApp()));
}

class TurboPosApp extends ConsumerWidget {
  const TurboPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(offlineSyncInitProvider);

    return MaterialApp.router(
      title: 'Turbo POS',
      debugShowCheckedModeBanner: false,
      theme: _buildTurboLightTheme(),
      darkTheme: _buildTurboDarkTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

// Brand pink used by both themes — matches เงินเทอร์โบ's own primary CTA
// color across turbo.co.th and the Ngernturbo app.
const _turboPink = Color(0xFFE5007D);
const _turboNavy = Color(0xFF1A237E);

/// The app's default theme — turbo.co.th's own look: white surfaces, brand
/// pink for every primary action, navy as the secondary/gradient accent.
ThemeData _buildTurboLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  const scaffoldBg = Color(0xFFFDF7FA); // the faintest pink tint, not flat white
  const cardBg = Colors.white;
  const bodyColor = Color(0xFF1A1A2E);

  final colorScheme = ColorScheme.light(
    primary: _turboPink,
    onPrimary: Colors.white,
    primaryContainer: _turboNavy,
    onPrimaryContainer: Colors.white,
    secondary: const Color(0xFF00BFA5),
    surface: cardBg,
    surfaceContainerHighest: const Color(0xFFFCE4EF),
    onSurface: bodyColor,
    outline: const Color(0xFF8A8A9A),
    error: const Color(0xFFD32F2F),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    textTheme: GoogleFonts.promptTextTheme(base.textTheme).apply(
      bodyColor: bodyColor,
      displayColor: bodyColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: bodyColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0DCE7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _turboPink,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _turboPink,
        side: const BorderSide(color: _turboPink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _turboPink.withAlpha(30),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? _turboPink : const Color(0xFF8A8A9A),
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _turboPink.withAlpha(30),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFCE4EF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF0DCE7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _turboPink, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFF0DCE7)),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFFCE4EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1A2E),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Kept as an available (but no longer default) theme — switch
/// `themeMode` in TurboPosApp back to ThemeMode.dark, or wire up a
/// user-facing toggle, to bring this back.
ThemeData _buildTurboDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colorScheme = ColorScheme.dark(
    primary: _turboPink,
    onPrimary: Colors.white,
    primaryContainer: _turboNavy,
    secondary: const Color(0xFF00BFA5),
    surface: const Color(0xFF0F1318),
    surfaceContainerHighest: const Color(0xFF1A1F2B),
    onSurface: const Color(0xFFE8EAED),
    outline: const Color(0xFF5F6368),
    error: const Color(0xFFEF5350),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF0F1318),
    textTheme: GoogleFonts.promptTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFE8EAED),
      displayColor: const Color(0xFFE8EAED),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF141920),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1F2B),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _turboPink,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _turboPink,
        side: const BorderSide(color: _turboPink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF141920),
      indicatorColor: _turboPink.withAlpha(30),
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFF141920),
      indicatorColor: _turboPink.withAlpha(48),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1F2B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A3040)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _turboPink, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A3040)),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1A1F2B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1F2B),
      contentTextStyle: const TextStyle(color: Color(0xFFE8EAED)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
