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
      darkTheme: _buildTurboTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

ThemeData _buildTurboTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colorScheme = ColorScheme.dark(
    primary: const Color(0xFFFF2D95),             // Turbo Pink — matches เงินเทอร์โบ's own brand pink, primary CTA
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF1A237E),     // Deep Navy — matches the brand's blue accent
    secondary: const Color(0xFF00BFA5),            // Turbo Teal — success
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
        backgroundColor: const Color(0xFFFF2D95),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFF2D95),
        side: const BorderSide(color: Color(0xFFFF2D95)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF141920),
      indicatorColor: const Color(0xFFFF2D95).withAlpha(30),
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF141920),
      indicatorColor: Color(0x30FF2D95),
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
        borderSide: const BorderSide(color: Color(0xFFFF2D95), width: 2),
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
