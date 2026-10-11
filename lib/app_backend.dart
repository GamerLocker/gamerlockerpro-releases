import 'package:supabase_flutter/supabase_flutter.dart';

import 'development_backend_config.dart';

class AppBackend {
  AppBackend._();

  static String supabaseUrl = const String.fromEnvironment('SUPABASE_URL');

  static String supabasePublishableKey = const String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get configured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static Future<void> initialize() async {
    final config = await developmentBackendConfig(
      definedUrl: supabaseUrl,
      definedKey: supabasePublishableKey,
    );
    supabaseUrl = config.url;
    supabasePublishableKey = config.key;
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
