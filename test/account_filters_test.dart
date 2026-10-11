import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/account_filters.dart';
import 'package:steamvault2/steam_cooldown_service.dart';
import 'package:steamvault2/main.dart' show AccountEntry;

void main() {
  final now = DateTime.utc(2026, 10, 11, 20);
  AccountViewFacts fact(SteamCooldownResult? result, {int? minutes}) =>
      AccountViewFacts(
        name: 'Account',
        favorite: false,
        result: result,
        csMinutes: minutes,
      );
  SteamCooldownResult timed(int seconds) => SteamCooldownResult(
    status: 'ok',
    penaltySeconds: seconds,
    checkedAt: now,
    cooldownEndsAt: now.add(Duration(seconds: seconds)),
  );

  test('unknown Prime is neither Prime nor confirmed non-Prime', () {
    expect(
      matchesAccountFilter(
        fact(const SteamCooldownResult(status: 'ok')),
        AccountFilter.nonPrime,
        now,
      ),
      false,
    );
    expect(
      matchesAccountFilter(
        fact(const SteamCooldownResult(status: 'ok', prime: false)),
        AccountFilter.nonPrime,
        now,
      ),
      true,
    );
    expect(
      matchesAccountFilter(fact(null), AccountFilter.unverified, now),
      true,
    );
    expect(
      matchesAccountFilter(
        fact(const SteamCooldownResult(status: 'error')),
        AccountFilter.clear,
        now,
      ),
      false,
    );
  });
  test(
    'VAC and expired timers are not marked clear without a fresh confirmation',
    () {
      expect(
        matchesAccountFilter(
          fact(const SteamCooldownResult(status: 'ok', vacBanned: true)),
          AccountFilter.clear,
          now,
        ),
        false,
      );
      expect(
        matchesAccountFilter(
          fact(const SteamCooldownResult(status: 'ok', vacBanned: true)),
          AccountFilter.penalty,
          now,
        ),
        true,
      );
      final expired = timed(60);
      expect(
        expired.remainingSecondsAt(now.add(const Duration(seconds: 20))),
        40,
      );
      expect(
        expired.remainingSecondsAt(now.add(const Duration(minutes: 2))),
        0,
      );
      expect(
        matchesAccountFilter(
          fact(expired),
          AccountFilter.unverified,
          now.add(const Duration(minutes: 2)),
        ),
        true,
      );
      expect(
        matchesAccountFilter(
          fact(expired),
          AccountFilter.clear,
          now.add(const Duration(minutes: 2)),
        ),
        false,
      );
      expect(
        matchesAccountFilter(
          fact(const SteamCooldownResult(status: 'ok')),
          AccountFilter.clear,
          now,
        ),
        true,
      );
    },
  );
  test(
    'finite cooldowns sort by remaining time ahead of unknown durations',
    () {
      expect(
        compareAccountFacts(
          fact(timed(30)),
          fact(timed(60)),
          AccountSort.cooldown,
          now,
        ),
        lessThan(0),
      );
      expect(
        compareAccountFacts(
          fact(timed(30)),
          fact(
            const SteamCooldownResult(status: 'ok', penaltySeconds: 4294967295),
          ),
          AccountSort.cooldown,
          now,
        ),
        lessThan(0),
      );
      expect(
        compareAccountFacts(
          fact(null, minutes: 100),
          fact(null),
          AccountSort.csHours,
          now,
        ),
        lessThan(0),
      );
      expect(
        compareAccountFacts(
          fact(null, minutes: 100),
          fact(null, minutes: 200),
          AccountSort.csHours,
          now,
        ),
        greaterThan(0),
      );
    },
  );
  test(
    'timestamp from GC determines end before helper metadata work completes',
    () {
      final result = SteamCooldownResult.fromJson({
        'status': 'ok',
        'penaltySeconds': 60,
        'checkedAt': now.millisecondsSinceEpoch ~/ 1000,
      });
      expect(result.checkedAt, now);
      expect(result.cooldownEndsAt, now.add(const Duration(minutes: 1)));
      expect(
        result.remainingSecondsAt(
          now.add(const Duration(seconds: 59, milliseconds: 500)),
        ),
        1,
      );
      expect(
        result.remainingSecondsAt(now.add(const Duration(seconds: 61))),
        0,
      );
    },
  );
  test('authenticated CS2 minutes survive vault serialization and unavailable responses', () {
    final account = AccountEntry(name: 'Account', type: 'Steam', fields: {});
    account.applySteamSnapshot(
      const SteamCooldownResult(
        status: 'ok',
        detailsOnly: true,
        accountDetails: {
          'gamesStatus': 'ok',
          'games': [
            {'appId': 730, 'minutes': 1200},
          ],
        },
      ),
    );
    expect(account.steamCs2Minutes, 1200);
    expect(AccountEntry.fromJson(account.toJson()).steamCs2Minutes, 1200);
    account.applySteamSnapshot(
      const SteamCooldownResult(
        status: 'ok',
        detailsOnly: true,
        accountDetails: {'gamesStatus': 'unavailable', 'games': []},
      ),
    );
    expect(account.steamCs2Minutes, 1200);
  });
}
