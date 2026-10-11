import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/main.dart' as app;
import 'package:steamvault2/steam_cooldown_service.dart';
import 'package:steamvault2/app_localizations.dart' show GamerLockerLocale;

app.AccountEntry account(String login, {Map<String, dynamic>? verified}) =>
    app.AccountEntry(
      name: login,
      type: 'Steam',
      fields: {'Login': login, 'Senha': 'test-only'},
      security: {
        'twoFactor': true,
        'emailVerified': true,
        'phoneVerified': true,
      },
      verifiedSecurity: verified,
    );

void main() {
  setUp(() {
    GamerLockerLocale.current.value = const Locale('pt', 'BR');
  });
  tearDown(() {
    GamerLockerLocale.current.value = null;
  });

  testWidgets('dashboard keeps equal columns while resizing', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = app.VaultData(
      name: 'Teste',
      email: '',
      accounts: List.generate(7, (index) => account('layout-test-$index')),
    );
    for (final width in [1900.0, 900.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpWidget(
        MaterialApp(home: app.DashboardScreen(data: data)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final cards = find.byType(app.AccountCard);
      expect(cards, findsNWidgets(7));
      final first = tester.getSize(cards.at(0));
      for (var index = 1; index < 7; index++) {
        expect(tester.getSize(cards.at(index)), first);
      }
      final expectedColumns = width == 1900 ? 5 : 2;
      expect(
        tester.getTopLeft(cards.at(expectedColumns)).dx,
        tester.getTopLeft(cards.at(0)).dx,
      );
      expect(
        tester.getTopLeft(cards.at(expectedColumns)).dy,
        greaterThan(tester.getTopLeft(cards.at(0)).dy),
      );
    }
  });
  test('manual Steam checkboxes never count as authenticated protections', () {
    expect(account('unverified').securityScore, -1);
    expect(
      account('partial', verified: {'steamGuard': true}).securityScore,
      -1,
    );
    final verified = account(
      'checked',
      verified: {
        'steamGuard': true,
        'twoFactor': false,
        'emailVerified': true,
        'phoneVerified': false,
        'checkedAt': 1760000000,
      },
    );
    expect(verified.securityScore, 50);
    final restored = app.AccountEntry.fromJson(verified.toJson());
    expect(restored.verifiedSecurity, verified.verifiedSecurity);
  });

  test('unsigned GC penalties preserve values above signed int range', () {
    final result = SteamCooldownResult.fromJson({
      'status': 'ok',
      'penaltySeconds': 4294948439,
      'penaltyReason': 4294967295,
    });
    expect(result.penaltySeconds, 4294948439);
    expect(result.penaltyReason, 4294967295);
    expect(result.hasCooldown, isTrue);
  });

  test('expired wrapped timed cooldown is clear while unknown bans remain', () {
    for (final reason in [22, 23]) {
      final result = SteamCooldownResult.fromJson({
        'status': 'ok',
        'penaltySeconds': 4294947254,
        'penaltyReason': reason,
      });
      expect(result.penaltySeconds, 0);
      expect(result.hasCooldown, isFalse);
    }
    expect(
      SteamCooldownResult.fromJson({
        'status': 'ok',
        'penaltySeconds': 500000,
        'penaltyReason': 22,
      }).hasCooldown,
      isTrue,
    );
    expect(
      SteamCooldownResult.fromJson({
        'status': 'ok',
        'penaltySeconds': 4294947254,
        'penaltyReason': 1,
      }).hasCooldown,
      isTrue,
    );
  });

  test(
    'authenticated fields fill automatically without inventing missing data',
    () {
      final entry = account('auto');
      entry.fields['Senha do e-mail'] = 'user-saved-email-password';
      entry.fields['Telefone vinculado'] = '+55 11999999999';
      final result = SteamCooldownResult.fromJson({
        'status': 'ok',
        'steamId64': '76561198000000000',
        'personaName': 'Steam name',
        'prime': false,
        'premierRating': 15000,
        'linkedEmail': 'test@example.com',
        'linkedPhone': '+55 ** *****-1234',
      });
      expect(entry.applySteamSnapshot(result), isTrue);
      expect(entry.fields['Prime'], 'Não');
      expect(entry.fields['Premier Rating'], '15000');
      expect(entry.fields['Nome no perfil'], 'Steam name');
      expect(entry.fields['E-mail vinculado'], 'test@example.com');
      expect(
        entry.fields['Perfil Steam'],
        'https://steamcommunity.com/profiles/76561198000000000',
      );
      expect(entry.fields['Telefone vinculado'], '+55 11999999999');
      expect(entry.fields['Senha do e-mail'], 'user-saved-email-password');
      expect(
        entry.applySteamSnapshot(const SteamCooldownResult(status: 'timeout')),
        isFalse,
      );
      expect(entry.fields['Prime'], 'Não');
      final empty = account('empty');
      expect(empty.fields['Premier Rating'], isNull);
      expect(
        empty.fieldDisplayValue('Premier Rating'),
        'Classificação não informada pelo GC',
      );
      expect(
        empty.fieldDisplayValue('Senha do e-mail'),
        'Não disponível pela Steam',
      );
    },
  );

  testWidgets('Steam security distinguishes unknown from confirmed disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: app.SteamSecuritySummary(account: account('unverified')),
        ),
      ),
    );
    expect(find.text('Não informado'), findsNWidgets(4));
    expect(find.text('Não ativo / não verificado'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: app.SteamSecuritySummary(
            account: account(
              'verified',
              verified: {
                'steamGuard': true,
                'twoFactor': false,
                'emailVerified': true,
                'phoneVerified': null,
                'checkedAt': 1760000000,
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Confirmado'), findsNWidgets(2));
    expect(find.text('Não ativo / não verificado'), findsOneWidget);
    expect(find.text('Não informado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uniform Steam cards fit narrow columns and long account names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget card(app.AccountEntry entry) => SizedBox(
      width: 350,
      child: app.AccountCard(
        account: entry,
        onTap: () {},
        onEdit: () {},
        onDelete: () {},
        onToggleFavorite: () {},
        onOpenSteamProfile: null,
        dragIndex: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              card(
                account(
                  'A very long account display name that must be truncated',
                ),
              ),
              card(
                account(
                  'Another',
                  verified: {
                    'steamGuard': true,
                    'twoFactor': true,
                    'emailVerified': true,
                    'phoneVerified': true,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final cards = find.byType(app.AccountCard);
    expect(tester.getSize(cards.at(0)), tester.getSize(cards.at(1)));
    expect(find.byType(app.SteamCooldownSummary), findsNWidgets(2));
    expect(find.textContaining('Segurança: não verificada'), findsOneWidget);
    expect(find.textContaining('Proteções: 4/4'), findsOneWidget);
  });
}
