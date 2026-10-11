import 'package:flutter_test/flutter_test.dart';

import 'package:steamvault2/plan_service.dart';
import 'package:steamvault2/product_key_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);
  test('remaining time rounds partial days up and never becomes negative', () {
    expect(
      PlanInfo(
        tier: PlanTier.pro,
        expiresAt: now.add(const Duration(days: 60)),
      ).remainingDaysAt(now),
      60,
    );
    expect(
      PlanInfo(
        tier: PlanTier.pro,
        expiresAt: now.add(const Duration(seconds: 1)),
      ).remainingDaysAt(now),
      1,
    );
    expect(
      PlanInfo(
        tier: PlanTier.pro,
        expiresAt: now.subtract(const Duration(days: 1)),
      ).remainingDaysAt(now),
      0,
    );
  });
  test('lifetime is explicit and has no countdown', () {
    const plan = PlanInfo(tier: PlanTier.pro, isLifetime: true);
    expect(plan.isPro, true);
    expect(plan.remainingDaysAt(now), null);
    expect(const PlanInfo(tier: PlanTier.pro).isLifetime, false);
    final result = ProductKeyRedeemResult.fromMap({
      'ok': true,
      'is_lifetime': true,
      'new_pro_until': null,
    });
    expect(result.isLifetime, true);
    expect(result.newProUntil, null);
  });
  test('expired license no longer grants unlimited accounts', () {
    final plan = PlanInfo(tier: PlanTier.pro, expiresAt: DateTime.utc(2000));
    expect(plan.isPro, false);
    expect(plan.accountLimit, 3);
    expect(plan.label, 'FREE');
  });
}
