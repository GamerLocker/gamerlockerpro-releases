import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef BackendConfig = ({String url, String key});

/// Runtime fallback only for local debug runs. Release builds use dart-defines.
Future<BackendConfig> developmentBackendConfig({
  required String definedUrl,
  required String definedKey,
  bool allowLocalFile = kDebugMode,
  List<Directory>? searchRoots,
}) async {
  final defined = (url: definedUrl, key: definedKey);
  // Explicit build configuration always wins, including partial configuration.
  if (!allowLocalFile || definedUrl.isNotEmpty || definedKey.isNotEmpty) {
    return defined;
  }
  final visited = <String>{};
  for (final start
      in searchRoots ??
          [Directory.current, File(Platform.resolvedExecutable).parent]) {
    var directory = start.absolute;
    for (var depth = 0; depth < 10; depth++) {
      if (visited.add(directory.path)) {
        final pubspec = File('${directory.path}/pubspec.yaml');
        final config = File('${directory.path}/config/dev.json');
        if (await pubspec.exists() &&
            await config.exists() &&
            RegExp(
              r'^name:\s*steamvault2\s*$',
              multiLine: true,
            ).hasMatch(await pubspec.readAsString())) {
          final json = jsonDecode(await config.readAsString());
          if (json is! Map ||
              json['SUPABASE_URL'] is! String ||
              json['SUPABASE_PUBLISHABLE_KEY'] is! String) {
            throw const FormatException(
              'config/dev.json: configuração do backend inválida.',
            );
          }
          return (
            url: json['SUPABASE_URL'] as String,
            key: json['SUPABASE_PUBLISHABLE_KEY'] as String,
          );
        }
      }
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
  }
  return defined;
}
