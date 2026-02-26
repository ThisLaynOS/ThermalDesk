import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zebra_label_pro/core/theme.dart';
import 'package:zebra_label_pro/providers/theme_provider.dart';
import 'package:zebra_label_pro/ui/home_page.dart';

class ZebraLabelApp extends ConsumerWidget {
  const ZebraLabelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Zebra Label Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
    );
  }
}
