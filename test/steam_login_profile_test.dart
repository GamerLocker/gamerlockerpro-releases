import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/main.dart'
    show AccountEntry, AccountCard, SteamCooldownSummary;
import 'package:steamvault2/steam_profile_service.dart';

void main() {
  testWidgets(
    'Steam account without profile still offers cooldown verification',
    (tester) async {
      final account = AccountEntry(
        name: 'Test',
        type: 'Steam',
        fields: {'Login': 'no-profile-test', 'Senha': 'test-only'},
      );
      expect(account.hasSteamProfile, false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountCard(
                account: account,
                onTap: () {},
                onEdit: () {},
                onDelete: () {},
                onToggleFavorite: () {},
                onOpenSteamProfile: null,
                isExpanded: true,
                onToggleExpanded: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SteamCooldownSummary), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('authenticated login discovers profile without a manually entered reference', () async {
    final account = AccountEntry(
      name: 'Test',
      type: 'Steam',
      fields: {'Login': 'discovered-profile-test'},
    );
    final reference = account.steamProfileReference;
    expect(await SteamProfileService.fetchProfile(reference), null);
    SteamProfileService.rememberAuthenticatedProfile(
      reference: reference,
      steamId64: '76561198000000000',
      avatarUrl: 'https://avatars.steamstatic.com/${'1' * 40}_full.jpg',
      persist: false,
    );
    expect(account.steamId, '76561198000000000');
    expect(account.hasSteamProfile, true);
    account.fields['Perfil Steam'] = 'wrong-manual-reference';
    expect(account.steamId, '76561198000000000');
    expect(
      SteamProfileService.cachedProfile(reference)?.steamId64,
      account.steamId,
    );
  });
}
