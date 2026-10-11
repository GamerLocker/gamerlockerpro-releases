import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_backend.dart';
import 'plan_service.dart';

class AccountService {
  AccountService._();

  static SupabaseClient get _client => AppBackend.client;

  static User? get currentUser => _client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: 'https://gamerlocker.github.io/auth-confirmed/',
    );

    if (response.session != null) {
      await refreshPlan();
    }

    return response;
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    await refreshPlan();
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();

    PlanService.current.value = const PlanInfo(tier: PlanTier.free);
  }

  static Future<void> refreshPlan() async {
    if (!isLoggedIn) {
      PlanService.current.value = const PlanInfo(tier: PlanTier.free);
      return;
    }

    final result = await _client.rpc('get_my_entitlement');

    Map<String, dynamic>? data;

    if (result is List && result.isNotEmpty) {
      data = Map<String, dynamic>.from(result.first as Map);
    } else if (result is Map) {
      data = Map<String, dynamic>.from(result);
    }

    if (data == null) {
      PlanService.current.value = const PlanInfo(tier: PlanTier.free);
      return;
    }

    final plan = data['plan']?.toString();

    final proUntilRaw = data['pro_until']?.toString();

    final proUntil = proUntilRaw == null
        ? null
        : DateTime.tryParse(proUntilRaw);

    PlanService.current.value = PlanInfo(
      tier: plan == 'pro' ? PlanTier.pro : PlanTier.free,
      expiresAt: proUntil,
    );
  }
}
