import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/steam_account_screen.dart';
import 'package:steamvault2/steam_cooldown_service.dart';

SteamCooldownResult details({String inventoryStatus = 'ok'}) =>
    SteamCooldownResult(
      status: 'ok',
      personaName: 'Test account',
      accountDetails: {
        'steamId64': '76561198000000000',
        'gamesStatus': 'ok',
        'steamLevel': 4,
        'games': [
          {
            'appId': 730,
            'name': 'Counter-Strike 2',
            'minutes': 1500,
            'recentMinutes': 120,
          },
        ],
        'badges': ['Community badge'],
        'badgesStatus': 'ok',
        'inventoryAppId': 730,
        'inventoryStatus': inventoryStatus,
        'inventoryComplete': true,
        'inventory': inventoryStatus == 'ok'
            ? [
                {
                  'id': '1',
                  'name': 'Veteran Coin',
                  'type': 'Collectible',
                  'iconUrl': '',
                  'amount': '1',
                  'tradable': false,
                  'marketable': false,
                  'isMedal': true,
                },
              ]
            : [],
      },
    );

void main() {
  testWidgets(
    'account tabs show CS hours, library and medals outside the dashboard',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SteamAccountScreen(
            username: 'fixture',
            password: 'test',
            loadDetails: (_) async => details(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('25.0 h'), findsOneWidget);
      await tester.tap(find.text('Jogos'));
      await tester.pumpAndSettle();
      expect(find.text('Counter-Strike 2'), findsOneWidget);
      await tester.tap(find.text('Insígnias e medalhas'));
      await tester.pumpAndSettle();
      expect(find.text('Community badge'), findsOneWidget);
      expect(find.text('Veteran Coin'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('unavailable inventory is not presented as empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SteamAccountScreen(
          username: 'fixture',
          password: 'test',
          loadDetails: (_) async => details(inventoryStatus: 'unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Inventário'));
    await tester.tap(find.text('Inventário'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inventário indisponível'), findsOneWidget);
    expect(find.text('Inventário vazio.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
