import 'steam_cooldown_service.dart';

enum AccountFilter {
  all('Todas'),
  prime('Prime'),
  nonPrime('Sem Prime'),
  clear('Sem penalidade'),
  penalty('Com penalidade'),
  vac('VAC'),
  unverified('Não verificadas');

  final String label;
  const AccountFilter(this.label);
}

enum AccountSort {
  manual('Ordem manual'),
  cooldown('Cooldown termina primeiro'),
  recent('Últimas verificadas'),
  favorites('Favoritas primeiro'),
  csHours('Mais horas de CS2'),
  name('Nome');

  final String label;
  const AccountSort(this.label);
}

class AccountViewFacts {
  final String name;
  final bool favorite;
  final SteamCooldownResult? result;
  final int? csMinutes;
  const AccountViewFacts({
    required this.name,
    required this.favorite,
    this.result,
    this.csMinutes,
  });
}

bool matchesAccountFilter(
  AccountViewFacts facts,
  AccountFilter filter,
  DateTime now,
) {
  final result = facts.result;
  final verified =
      result != null && result.status == 'ok' && !result.detailsOnly;
  return switch (filter) {
    AccountFilter.all => true,
    AccountFilter.prime => result?.prime == true,
    AccountFilter.nonPrime => result?.prime == false,
    AccountFilter.clear => verified && result.clearAt(now),
    AccountFilter.penalty =>
      verified &&
          (result.vacBanned ||
              result.hasCooldown && !result.cooldownElapsedAt(now)),
    AccountFilter.vac => verified && result.vacBanned,
    AccountFilter.unverified =>
      !verified || result.cooldownElapsedAt(now) && !result.vacBanned,
  };
}

int compareAccountFacts(
  AccountViewFacts a,
  AccountViewFacts b,
  AccountSort sort,
  DateTime now,
) {
  int knownFirst(num? x, num? y, {bool descending = false}) {
    if (x == null || y == null) {
      return x == y
          ? 0
          : x == null
          ? 1
          : -1;
    }
    return descending ? y.compareTo(x) : x.compareTo(y);
  }

  int? remaining(AccountViewFacts f) =>
      f.result?.status == 'ok' &&
          f.result!.hasTimedCooldown &&
          !f.result!.vacBanned &&
          !f.result!.cooldownElapsedAt(now)
      ? f.result!.remainingSecondsAt(now)
      : null;
  return switch (sort) {
    AccountSort.manual => 0,
    AccountSort.cooldown => knownFirst(remaining(a), remaining(b)),
    AccountSort.recent => knownFirst(
      a.result?.checkedAt?.millisecondsSinceEpoch,
      b.result?.checkedAt?.millisecondsSinceEpoch,
      descending: true,
    ),
    AccountSort.favorites => (b.favorite ? 1 : 0).compareTo(a.favorite ? 1 : 0),
    AccountSort.csHours => knownFirst(
      a.csMinutes,
      b.csMinutes,
      descending: true,
    ),
    AccountSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  };
}
