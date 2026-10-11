import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/development_backend_config.dart';

void main() {
  late Directory workspace;
  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('gamerlocker-config-');
    await File('${workspace.path}/pubspec.yaml')
        .writeAsString('name: steamvault2\n');
    await Directory('${workspace.path}/config').create();
    await File('${workspace.path}/config/dev.json').writeAsString(
      '{"SUPABASE_URL":"https://local-test.example","SUPABASE_PUBLISHABLE_KEY":"test-public-key"}',
    );
  });
  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  test(
    'bare debug run finds local config from Windows runner directory',
    () async {
      final runner = await Directory(
        '${workspace.path}/build/windows/x64/runner/Debug',
      ).create(recursive: true);
      final result = await developmentBackendConfig(
        definedUrl: '',
        definedKey: '',
        allowLocalFile: true,
        searchRoots: [runner],
      );
      expect(result.url, 'https://local-test.example');
      expect(result.key, 'test-public-key');
    },
  );
  test('release never reads local development config', () async {
    final result = await developmentBackendConfig(
      definedUrl: '',
      definedKey: '',
      allowLocalFile: false,
      searchRoots: [workspace],
    );
    expect(result, (url: '', key: ''));
  });
  test('explicit backend cannot be mixed with local configuration', () async {
    final result = await developmentBackendConfig(
      definedUrl: 'https://explicit.example',
      definedKey: '',
      allowLocalFile: true,
      searchRoots: [workspace],
    );
    expect(result, (url: 'https://explicit.example', key: ''));
  });
  test('unrelated project config is ignored', () async {
    await File('${workspace.path}/pubspec.yaml')
        .writeAsString('name: other_app\n');
    final result = await developmentBackendConfig(
      definedUrl: '',
      definedKey: '',
      allowLocalFile: true,
      searchRoots: [workspace],
    );
    expect(result, (url: '', key: ''));
  });
}
