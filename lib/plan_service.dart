import 'package:flutter/foundation.dart';

const bool gamerLockerMicrosoftStoreBuild = bool.fromEnvironment(
  'MICROSOFT_STORE_BUILD',
);

enum PlanTier { free, pro }

class PlanInfo {
  final PlanTier tier;
  final DateTime? expiresAt;
  final bool isLifetime;

  const PlanInfo({required this.tier, this.expiresAt, this.isLifetime = false});

  bool get isPro =>
      gamerLockerMicrosoftStoreBuild ||
      (tier == PlanTier.pro &&
          (isLifetime ||
              expiresAt == null ||
              expiresAt!.isAfter(DateTime.now())));

  int? remainingDaysAt(DateTime now) {
    if (isLifetime || expiresAt == null) return null;
    final remaining = expiresAt!.difference(now).inMicroseconds;
    return remaining <= 0
        ? 0
        : (remaining / const Duration(days: 1).inMicroseconds).ceil();
  }

  String get label {
    if (gamerLockerMicrosoftStoreBuild) {
      return 'STORE';
    }
    switch (isPro ? PlanTier.pro : PlanTier.free) {
      case PlanTier.free:
        return 'FREE';
      case PlanTier.pro:
        return 'PRO';
    }
  }

  int? get accountLimit {
    if (isPro) {
      return null;
    }

    return 3;
  }
}

class PlanService {
  PlanService._();

  static const int freeAccountLimit = 3;

  //
  // IMPORTANTE:
  // Isto e apenas o estado local da interface.
  //
  // A licenca PRO real NAO sera ativada localmente.
  // Na proxima etapa este ValueNotifier sera alimentado
  // pela API de licencas.
  //
  static final ValueNotifier<PlanInfo> current = ValueNotifier<PlanInfo>(
    const PlanInfo(tier: PlanTier.free),
  );

  static bool canAddAccount(int currentAccounts) {
    final plan = current.value;

    if (plan.isPro) {
      return true;
    }

    return currentAccounts < freeAccountLimit;
  }

  static int? remainingAccounts(int currentAccounts) {
    final plan = current.value;

    if (plan.isPro) {
      return null;
    }

    final remaining = freeAccountLimit - currentAccounts;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }
}
