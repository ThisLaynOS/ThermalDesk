import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_desk/app.dart';
import 'package:thermal_desk/ui/widgets/thermaldesk_logo.dart';

void main() {
  testWidgets('Abre o ecrã inicial e o menu com a identidade ThermalDesk', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: ThermalDeskApp()));
    await tester.pumpAndSettle();
    expect(find.text('ThermalDesk'), findsOneWidget);
    expect(find.byType(ThermalDeskLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('ThermalDesk'), findsNWidgets(2));
    expect(find.byType(ThermalDeskLogo), findsNWidgets(2));
    await tester.drag(
      find.descendant(of: find.byType(Drawer), matching: find.byType(ListView)),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('ThermalDesk v2.1.0 • ZPL II | Feito com ❤️ por LaynOS'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
