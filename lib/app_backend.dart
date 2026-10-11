import 'package:supabase_flutter/supabase_flutter.dart';

class AppBackend {
  AppBackend._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get configured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!configured) {
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

  static SupabaseClient get client {
    if (!configured) {
      throw StateError('Backend GamerLocker nao configurado.');
    }

    return Supabase.instance.client;
  }
}
