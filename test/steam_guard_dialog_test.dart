import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/steam_guard_dialog.dart';
import 'package:steamvault2/steam_cooldown_service.dart';

void main() {
  testWidgets('Guard code dialog survives closing animation and reopening', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                submitted = await askSteamGuardCode(context, hint: 'Código');
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(submitted, '12345');
      expect(tester.takeException(), isNull);
    }
  });
  test('competitive indicator is limited to confirmed non-Prime accounts', () {
    expect(
      const SteamCooldownResult(
        status: 'ok',
        prime: true,
      ).shouldShowCompetitiveAccess,
      false,
    );
    expect(
      const SteamCooldownResult(status: 'ok').shouldShowCompetitiveAccess,
      false,
    );
    expect(
      const SteamCooldownResult(
        status: 'ok',
        prime: false,
      ).shouldShowCompetitiveAccess,
      true,
    );
  });
}
