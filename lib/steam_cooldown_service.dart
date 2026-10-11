import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'steam_profile_service.dart';

class SteamCooldownResult {
  final String status;
  final int penaltySeconds;
  final int penaltyReason;
  final bool vacBanned;
  final String? message;
  final String? guardType;
  final String? sessionWarning;
  final String? groupStatus;
  final String? groupMessage;
  final String? steamId64;
  final String? avatarUrl;
  final String? personaName;
  final Map<String, dynamic>? accountDetails;
  final int? cs2Level;
  final bool? prime;

  const SteamCooldownResult({
    required this.status,
    this.penaltySeconds = 0,
    this.penaltyReason = 0,
    this.vacBanned = false,
    this.message,
    this.guardType,
    this.sessionWarning,
    this.groupStatus,
    this.groupMessage,
    this.steamId64,
    this.avatarUrl,
    this.personaName,
    this.accountDetails,
    this.cs2Level,
    this.prime,
  });

  bool get hasCooldown => status == 'ok' && penaltySeconds > 0;
  bool get shouldShowCompetitiveAccess => status == 'ok' && prime == false;
  bool get needsSteamGuard =>
      status == 'steam_guard_required' || status == 'two_factor_required';

  factory SteamCooldownResult.fromJson(Map<String, dynamic> json) {
    return SteamCooldownResult(
      status: json['status']?.toString() ?? 'error',
      penaltySeconds:
          int.tryParse(json['penaltySeconds']?.toString() ?? '') ?? 0,
      penaltyReason: int.tryParse(json['penaltyReason']?.toString() ?? '') ?? 0,
      vacBanned: json['vacBanned'] == true,
      message: json['message']?.toString(),
      guardType: json['guardType']?.toString(),
      sessionWarning: json['sessionWarning']?.toString(),
      groupStatus: json['groupStatus']?.toString(),
      groupMessage: json['groupMessage']?.toString(),
      steamId64: json['steamId64']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      personaName: json['personaName']?.toString(),
      cs2Level: (json['cs2Level'] as num?)?.toInt(),
      prime: json['prime'] is bool ? json['prime'] as bool : null,
      accountDetails: json['accountDetails'] is Map
          ? Map<String, dynamic>.from(json['accountDetails'] as Map)
          : null,
    );
  }
}

class SteamCooldownService {
  SteamCooldownService._();

  static final Map<String, SteamCooldownResult> _cache = {};
  static final Map<String, SteamCooldownResult> _detailsCache = {};
  static SteamCooldownResult? cachedDetails(String login) =>
      _detailsCache[login.trim()];
  static bool _diskCacheLoaded = false;

  static String get _cacheFilePath {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final base = (localAppData != null && localAppData.isNotEmpty)
        ? localAppData
        : Directory.current.path;
    return '$base${Platform.pathSeparator}GamerLocker${Platform.pathSeparator}cooldown_cache.json';
  }

  static SteamCooldownResult? cached(String login) {
    _loadDiskCacheOnce();
    return _cache[login.trim()];
  }

  static void _loadDiskCacheOnce() {
    if (_diskCacheLoaded) return;
    _diskCacheLoaded = true;

    try {
      final file = File(_cacheFilePath);
      if (!file.existsSync()) return;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final raw = Map<String, dynamic>.from(entry.value as Map);
        final status = raw['status']?.toString() ?? 'error';
        final expiresAt = int.tryParse(raw['expiresAt']?.toString() ?? '') ?? 0;
        final savedPenalty =
            int.tryParse(raw['penaltySeconds']?.toString() ?? '') ?? 0;
        final remaining = expiresAt > 0
            ? (expiresAt - now).clamp(0, 2147483647)
            : savedPenalty;

        _cache[entry.key] = SteamCooldownResult(
          status: status,
          penaltySeconds: remaining,
          penaltyReason:
              int.tryParse(raw['penaltyReason']?.toString() ?? '') ?? 0,
          vacBanned: raw['vacBanned'] == true,
          message: raw['message']?.toString(),
          guardType: raw['guardType']?.toString(),
          steamId64: raw['steamId64']?.toString(),
          avatarUrl: raw['avatarUrl']?.toString(),
          personaName: raw['personaName']?.toString(),
          cs2Level: (raw['cs2Level'] as num?)?.toInt(),
          prime: raw['prime'] is bool ? raw['prime'] as bool : null,
        );
      }
    } catch (_) {
      // Cache local is apenas uma conveniencia. Nunca deve impedir o app de abrir.
    }
  }

  static void _persistSuccessfulResult(
    String login,
    SteamCooldownResult result,
  ) {
    try {
      final file = File(_cacheFilePath);
      file.parent.createSync(recursive: true);

      Map<String, dynamic> all = <String, dynamic>{};
      if (file.existsSync()) {
        try {
          final decoded = jsonDecode(file.readAsStringSync());
          if (decoded is Map<String, dynamic>) all = decoded;
        } catch (_) {}
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      all[login] = <String, dynamic>{
        'status': result.status,
        'penaltySeconds': result.penaltySeconds,
        'penaltyReason': result.penaltyReason,
        'vacBanned': result.vacBanned,
        'message': result.message,
        'steamId64': result.steamId64,
        'avatarUrl': result.avatarUrl,
        'personaName': result.personaName,
        'cs2Level': result.cs2Level,
        'prime': result.prime,
        'checkedAt': now,
        'expiresAt': result.penaltySeconds > 0
            ? now + result.penaltySeconds
            : 0,
      };
      file.writeAsStringSync(jsonEncode(all));
    } catch (_) {
      // Se o cache falhar, a consulta atual continua valida normalmente.
    }
  }

  static Future<SteamCooldownResult> check({
    required String username,
    required String password,
    String? authCode,
    String? twoFactorCode,
    bool forceRefresh = true,
    String? profileReference,
    bool detailsOnly = false,
    int inventoryAppId = 730,
    void Function(SteamCooldownResult)? onProgress,
  }) async {
    final normalizedUser = username.trim();
    _loadDiskCacheOnce();
    if (normalizedUser.isEmpty || password.isEmpty) {
      return const SteamCooldownResult(
        status: 'missing_credentials',
        message: 'Informe Login e Senha na conta Steam.',
      );
    }

    if (!detailsOnly && !forceRefresh && _cache.containsKey(normalizedUser)) {
      return _cache[normalizedUser]!;
    }

    final helper = await _findHelper();
    if (helper == null) {
      return const SteamCooldownResult(
        status: 'helper_missing',
        message: 'Componente Steam GC nao encontrado. Execute tools/steam_gc_helper/build.ps1 e gere o app novamente.',
      );
    }

    Process? process;
    try {
      process = await Process.start(
        helper.path,
        const [],
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      final request = <String, dynamic>{
        'username': normalizedUser,
        'password': password,
        'authCode': authCode?.trim() ?? '',
        'twoFactorCode': twoFactorCode?.trim() ?? '',
        'timeoutSeconds': 75,
        'preferDeviceConfirmation':
            twoFactorCode == null || twoFactorCode.trim().isEmpty,
        'joinGamerLockerGroup': !detailsOnly,
        'detailsOnly': detailsOnly,
        'inventoryAppId': inventoryAppId,
      };

      process.stdin.writeln(jsonEncode(request));
      await process.stdin.close();

      final stdoutFuture = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) {
            try {
              final progress = SteamCooldownResult.fromJson(
                jsonDecode(line) as Map<String, dynamic>,
              );
              if (progress.status == 'waiting_device_confirmation') {
                onProgress?.call(progress);
              }
            } catch (_) {}
            return line;
          })
          .join('\n');
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 100),
      );
      final output = (await stdoutFuture).trim();
      final errorOutput = (await stderrFuture).trim();

      if (output.isEmpty) {
        return SteamCooldownResult(
          status: 'error',
          message: errorOutput.isNotEmpty
              ? errorOutput
              : 'O componente Steam GC terminou sem retornar dados (codigo $exitCode).',
        );
      }

      final lines = output
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final decoded = jsonDecode(lines.last) as Map<String, dynamic>;
      final result = SteamCooldownResult.fromJson(decoded);
      if (result.steamId64 != null && result.avatarUrl != null) {
        for (final reference in {
          SteamProfileService.loginReference(normalizedUser),
          result.steamId64!,
          if (profileReference != null && profileReference.trim().isNotEmpty)
            profileReference,
        }) {
          SteamProfileService.rememberAuthenticatedProfile(
            reference: reference,
            steamId64: result.steamId64!,
            avatarUrl: result.avatarUrl!,
            displayName: result.personaName,
          );
        }
      }

      if (detailsOnly && result.accountDetails != null) {
        _detailsCache[normalizedUser] = result;
      }
      if (!detailsOnly && result.status == 'ok') {
        _cache[normalizedUser] = result;
        _persistSuccessfulResult(normalizedUser, result);
      }

      return result;
    } on TimeoutException {
      process?.kill();
      return const SteamCooldownResult(
        status: 'timeout',
        message: 'Tempo esgotado ao consultar o Game Coordinator do CS2.',
      );
    } catch (error) {
      process?.kill();
      return SteamCooldownResult(
        status: 'error',
        message: 'Falha ao consultar o Steam GC: $error',
      );
    }
  }

  static Future<File?> _findHelper() async {
    if (!Platform.isWindows) {
      return null;
    }

    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final separator = Platform.pathSeparator;

    final candidates = <String>[
      '$executableDir${separator}steam_gc_helper${separator}GamerLocker.SteamGcHelper.exe',
      '$executableDir${separator}GamerLocker.SteamGcHelper.exe',
      '$currentDir${separator}steam_gc_helper${separator}GamerLocker.SteamGcHelper.exe',
      '$currentDir${separator}tools${separator}steam_gc_helper${separator}publish${separator}GamerLocker.SteamGcHelper.exe',
    ];

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }

    return null;
  }
}
