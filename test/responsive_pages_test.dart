import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/ui/home_page.dart';
import 'package:thermal_desk/models/label_job.dart';
import 'package:thermal_desk/ui/pages/batch_print_page.dart';
import 'package:thermal_desk/ui/pages/dashboard_page.dart';
import 'package:thermal_desk/ui/pages/history_page.dart';
import 'package:thermal_desk/ui/pages/printers_page.dart';
import 'package:thermal_desk/ui/pages/settings_page.dart';
import 'package:thermal_desk/ui/pages/template_picker_page.dart';

void main() {
  for (final width in [320.0, 600.0, 1280.0]) {
    for (final page in <String, Widget>{
      'home': const HomePage(),
      'dashboard': const DashboardPage(),
      'printers': const PrintersPage(),
      'history': const HistoryPage(),
      'settings': const SettingsPage(),
      'batch': const BatchPrintPage(),
      'templates': const TemplatePicker(current: LabelTemplate.basic),
    }.entries) {
      testWidgets('${page.key} sem overflow a ${width.toInt()}px', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: page.value)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
