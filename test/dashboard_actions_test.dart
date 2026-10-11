import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/main.dart' as app;
import 'package:steamvault2/account_dashboard_extras.dart';
import 'package:steamvault2/account_filters.dart';
import 'package:steamvault2/steam_cooldown_service.dart';
import 'package:steamvault2/plan_service.dart';
import 'package:steamvault2/app_localizations.dart' show GamerLockerLocale;

void main() {
  setUp(() {
    GamerLockerLocale.current.value = const Locale('pt', 'BR');
  });
  tearDown(() {
    GamerLockerLocale.current.value = null;
    PlanService.lookupError.value = null;
  });
  final accounts = ['Zulu', 'Alpha']
      .map(
        (name) => app.AccountEntry(
          name: name,
          type: 'Steam',
          fields: {'Login': 'actions-$name', 'Senha': 'test-only'},
        ),
      )
      .toList();
  test(
    'batch stops after current check and does not start the next account',
    () async {
      var stopped = false, calls = 0;
      final result = await verifyAccountBatch(
        accounts,
        stopped: () => stopped,
        progress: (_, _, _) {},
        guard: (_, _) async => null,
        check: (_, _, _) async {
          calls++;
          stopped = true;
          return const SteamCooldownResult(status: 'ok');
        },
        finished: (_, _) {},
      );
      expect(calls, 1);
      expect(result.done, 1);
    },
  );
  test('batch retries Guard and continues after a failed account', () async {
    var calls = 0, guardCalls = 0;
    final result = await verifyAccountBatch(
      accounts,
      stopped: () => false,
      progress: (_, _, _) {},
      guard: (_, mobile) async {
        expect(mobile, true);
        guardCalls++;
        return '12345';
      },
      check: (_, code, _) async {
        calls++;
        if (calls == 1) {
          return const SteamCooldownResult(
            status: 'two_factor_required',
            guardType: 'mobile',
          );
        }
        if (calls == 2) {
          expect(code, '12345');
          return const SteamCooldownResult(status: 'error');
        }
        return const SteamCooldownResult(status: 'ok');
      },
      finished: (_, _) {},
    );
    expect(calls, 3);
    expect(guardCalls, 1);
    expect(result, (done: 2, failed: 1));
  });
  testWidgets(
    'filters combine with search and name sort preserves stored order',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = app.VaultData(name: 'Teste', email: '', accounts: accounts);
      await tester.pumpWidget(
        MaterialApp(home: app.DashboardScreen(data: data)),
      );
      await tester.tap(find.byType(DropdownButtonFormField<AccountSort>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nome').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<app.AccountCard>(find.byType(app.AccountCard).first)
            .account
            .name,
        'Alpha',
      );
      expect(data.accounts.first.name, 'Zulu');
      await tester.tap(find.text('Prime (0)'));
      await tester.pump();
      expect(find.byType(app.AccountCard), findsNothing);
      await tester.tap(find.text('Não verificadas (2)'));
      await tester.pump();
      expect(find.byType(app.AccountCard), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).first, 'Zulu');
      await tester.pump();
      expect(find.byType(app.AccountCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('list view fits a narrow window without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: AccountListOverview(
              accounts: accounts,
              verifying: false,
              onOpen: (_) {},
              resultFor: (_) => null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Horas CS2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'cooldown reaches zero without claiming a newly confirmed clear status',
    (tester) async {
      final entry = accounts.first;
      var now = DateTime.utc(2026, 10, 11, 20);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: app.SteamCooldownSummary(account: entry, clock: () => now),
          ),
        ),
      );
      SteamCooldownService.notifyResult(
        entry.fields['Login']!,
        SteamCooldownResult(
          status: 'ok',
          penaltySeconds: 1,
          checkedAt: now,
          cooldownEndsAt: now.add(const Duration(seconds: 1)),
        ),
      );
      await tester.pump();
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Prazo encerrado; verifique novamente'), findsOneWidget);
      expect(find.text('Sem penalidade'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('plan lookup failure is distinct from confirmed FREE', (
    tester,
  ) async {
    PlanService.lookupError.value = 'Não foi possível consultar o plano.';
    await tester.pumpWidget(
      const MaterialApp(home: app.PlanScreen(accountCount: 14)),
    );
    expect(find.text('Não foi possível consultar o plano.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('FREE'), findsNothing);
  });
}
