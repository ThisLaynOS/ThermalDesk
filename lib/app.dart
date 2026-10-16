import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_desk/core/theme.dart';
import 'package:thermal_desk/providers/theme_provider.dart';
import 'package:thermal_desk/ui/home_page.dart';

class ThermalDeskApp extends ConsumerWidget {
  const ThermalDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'ThermalDesk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
    );
  }
}
