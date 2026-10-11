import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'app_backend.dart';

const bool gamerLockerMicrosoftStoreBuild = bool.fromEnvironment(
  'MICROSOFT_STORE_BUILD',
);

const String gamerLockerCurrentVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.17',
);

class GamerLockerUpdateInfo {
  final String version;
  final String tagName;
  final String releaseName;
  final String installerUrl;
  final String releaseUrl;
  final String? sha256Digest;

  const GamerLockerUpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseName,
    required this.installerUrl,
    required this.releaseUrl,
    this.sha256Digest,
  });
}

class GamerLockerUpdateService {
  static const privateUpdates = bool.fromEnvironment('PRIVATE_UPDATES');
  static Uri get _privateEndpoint =>
      Uri.parse('${AppBackend.supabaseUrl}/functions/v1/private-updates');

  static Future<void> _authorize(HttpClientRequest request) async {
    if (!AppBackend.configured) throw StateError('Backend nao configurado.');
    var session = AppBackend.client.auth.currentSession;
    if (session == null) throw StateError('Entre na sua conta para atualizar.');
    if (session.isExpired) {
      session = (await AppBackend.client.auth.refreshSession()).session;
    }
    if (session == null) throw StateError('Sessao expirada.');
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${session.accessToken}',
    );
    request.headers.set('apikey', AppBackend.supabasePublishableKey);
  }

  static const _releasesRepository = String.fromEnvironment(
    'UPDATES_REPOSITORY',
    defaultValue: 'GamerLocker/gamerlocker-releases',
  );
  static const _releasesApi =
      'https://api.github.com/repos/$_releasesRepository/releases?per_page=10';

  static bool get shouldCheckAutomatically {
    if (gamerLockerMicrosoftStoreBuild) {
      return false;
    }
    if (!Platform.isWindows) {
      return false;
    }

    final executable = Platform.resolvedExecutable.toLowerCase();

    if (executable.contains(r'\build\windows\')) {
      return false;
    }

    return executable.endsWith(r'\gamerlocker.exe');
  }

  static Future<GamerLockerUpdateInfo?> checkForUpdate() async {
    if (!shouldCheckAutomatically) {
      return null;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'GamerLocker-Updater/$gamerLockerCurrentVersion';

    try {
      final request = await client.getUrl(
        privateUpdates ? _privateEndpoint : Uri.parse(_releasesApi),
      );
      if (privateUpdates) await _authorize(request);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');

      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return null;
      }

      GamerLockerUpdateInfo? best;

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final release = Map<String, dynamic>.from(item);

        if (release['draft'] == true) {
          continue;
        }

        final tagName = (release['tag_name'] ?? '').toString().trim();
        final version = _normalizeVersion(tagName);

        if (version == null ||
            _compareVersions(version, gamerLockerCurrentVersion) <= 0) {
          continue;
        }

        final assetsRaw = release['assets'];

        if (assetsRaw is! List) {
          continue;
        }

        String? installerUrl;

        for (final assetItem in assetsRaw) {
          if (assetItem is! Map) {
            continue;
          }

          final asset = Map<String, dynamic>.from(assetItem);
          final name = (asset['name'] ?? '').toString();
          final url = (asset['browser_download_url'] ?? '').toString();

          if (name.toLowerCase().startsWith('gamerlocker-setup-') &&
              name.toLowerCase().endsWith('.exe') &&
              url.isNotEmpty) {
            final uri = Uri.tryParse(url);

            if (uri != null &&
                uri.scheme == 'https' &&
                (privateUpdates
                    ? uri.origin == _privateEndpoint.origin &&
                          uri.path == _privateEndpoint.path
                    : uri.host.toLowerCase() == 'github.com')) {
              installerUrl = url;
              break;
            }
          }
        }

        if (installerUrl == null ||
            (privateUpdates && assetDigest(release, installerUrl) == null)) {
          continue;
        }

        final candidate = GamerLockerUpdateInfo(
          version: version,
          tagName: tagName,
          releaseName: (release['name'] ?? tagName).toString(),
          installerUrl: installerUrl,
          releaseUrl: (release['html_url'] ?? '').toString(),
          sha256Digest: assetDigest(release, installerUrl),
        );

        if (best == null ||
            _compareVersions(candidate.version, best.version) > 0) {
          best = candidate;
        }
      }

      return best;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> downloadInstaller(
    GamerLockerUpdateInfo update, {
    required void Function(double? progress) onProgress,
  }) async {
    final uri = Uri.parse(update.installerUrl);
    if (privateUpdates &&
        (uri.scheme != 'https' ||
            uri.origin != _privateEndpoint.origin ||
            uri.path != _privateEndpoint.path)) {
      throw const HttpException('Origem da atualizacao invalida.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'GamerLocker-Updater/$gamerLockerCurrentVersion';

    final tempDir = await Directory.systemTemp.createTemp(
      'gamerlocker_update_',
    );

    final installer = File(
      '${tempDir.path}${Platform.pathSeparator}'
      'GamerLocker-Setup-v${update.version}-windows-x64.exe',
    );

    IOSink? sink;

    try {
      final request = await client.getUrl(uri);
      if (privateUpdates) await _authorize(request);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Falha no download: HTTP ${response.statusCode}.');
      }

      final total = response.contentLength;
      var received = 0;

      sink = installer.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;

        if (total > 0) {
          onProgress(received / total);
        } else {
          onProgress(null);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final length = await installer.length();

      if (length < 200000) {
        throw const FileSystemException(
          'O instalador baixado parece estar incompleto.',
        );
      }

      if (total > 0 && length != total) {
        throw const FileSystemException(
          'O tamanho do instalador baixado nao confere.',
        );
      }

      if (privateUpdates) {
        final digest = update.sha256Digest;
        if (digest == null ||
            (await sha256.bind(installer.openRead()).first).toString() !=
                digest) {
          throw const FileSystemException(
            'A integridade do instalador nao confere.',
          );
        }
      }

      onProgress(1);
      return installer;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}

      try {
        if (await installer.exists()) {
          await installer.delete();
        }
      } catch (_) {}

      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> launchInstallerAfterExit(File installer) async {
    if (!Platform.isWindows) {
      throw const FileSystemException(
        'Atualizacao automatica disponivel somente no Windows.',
      );
    }

    if (!await installer.exists()) {
      throw const FileSystemException(
        'O instalador da atualizacao nao foi encontrado.',
      );
    }

    final logFile = File(
      '${installer.parent.path}${Platform.pathSeparator}'
      'gamerlocker_update_install.log',
    );

    const powershellCommand = r"""
$ErrorActionPreference = 'Stop'

$setupArgs = @(
  '/SP-',
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/CLOSEAPPLICATIONS',
  ('/LOG="' + $env:GAMERLOCKER_UPDATE_LOG + '"')
)

Start-Process -WindowStyle Hidden `
  -FilePath $env:GAMERLOCKER_UPDATE_SETUP `
  -ArgumentList $setupArgs

exit 0
""";

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        powershellCommand,
      ],
      environment: {
        ...Platform.environment,
        'GAMERLOCKER_UPDATE_SETUP': installer.path,
        'GAMERLOCKER_UPDATE_LOG': logFile.path,
      },
    );

    if (result.exitCode != 0) {
      final errorText = [
        result.stdout.toString().trim(),
        result.stderr.toString().trim(),
      ].where((value) => value.isNotEmpty).join('\n');

      throw ProcessException(
        'powershell.exe',
        const [],
        errorText.isEmpty
            ? 'Nao foi possivel iniciar o instalador.'
            : errorText,
        result.exitCode,
      );
    }
  }

  static String? assetDigest(Map<String, dynamic> release, String? url) {
    for (final asset in release['assets'] as List) {
      if (asset is Map && asset['browser_download_url'] == url) {
        final digest = asset['digest']?.toString() ?? '';
        if (RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) {
          return digest.substring(7).toLowerCase();
        }
      }
    }
    return null;
  }

  static String? _normalizeVersion(String value) {
    var normalized = value.trim().toLowerCase();

    if (normalized.startsWith('v')) {
      normalized = normalized.substring(1);
    }

    normalized = normalized.split('-').first;
    normalized = normalized.split('+').first;

    final parts = normalized.split('.');

    if (parts.length < 2 || parts.length > 4) {
      return null;
    }

    final numbers = <int>[];

    for (final part in parts) {
      final parsed = int.tryParse(part);

      if (parsed == null) {
        return null;
      }

      numbers.add(parsed);
    }

    while (numbers.length < 3) {
      numbers.add(0);
    }

    return numbers.take(3).join('.');
  }

  static int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);

    for (var i = 0; i < 3; i++) {
      if (leftParts[i] != rightParts[i]) {
        return leftParts[i].compareTo(rightParts[i]);
      }
    }

    return 0;
  }

  static List<int> _versionParts(String value) {
    final normalized = _normalizeVersion(value) ?? '0.0.0';

    return normalized
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
