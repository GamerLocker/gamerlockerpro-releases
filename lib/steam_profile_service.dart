import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class SteamPublicProfile {
  final String steamId64;
  final String displayName;
  final String avatarUrl;
  final String onlineState;
  final String stateMessage;
  final String profileUrl;

  const SteamPublicProfile({
    required this.steamId64,
    required this.displayName,
    required this.avatarUrl,
    required this.onlineState,
    required this.stateMessage,
    required this.profileUrl,
  });

  bool get isOnline {
    final state = onlineState.toLowerCase();
    return state == 'online' ||
        state == 'in-game' ||
        state == 'busy' ||
        state == 'away' ||
        state == 'snooze' ||
        state == 'lookingtoplay' ||
        state == 'lookingtotrade';
  }

  String get statusLabel {
    if (stateMessage.trim().isNotEmpty) {
      return stateMessage.trim();
    }

    switch (onlineState.toLowerCase()) {
      case 'online':
        return 'Online';
      case 'in-game':
        return 'Em jogo';
      case 'busy':
        return 'Ocupado';
      case 'away':
        return 'Ausente';
      case 'snooze':
        return 'Ausente';
      default:
        return 'Offline';
    }
  }
}

class SteamProfileService {
  SteamProfileService._();
  static String loginReference(String login) =>
      'steam-login:${login.trim().toLowerCase()}';

  static const int _steamId64Base = 76561197960265728;

  static final Map<String, Future<SteamPublicProfile?>> _cache = {};
  static final Map<String, SteamPublicProfile> _lastSuccessful = {};
  static final Map<String, DateTime> _expiresAt = {};
  static final _changes = StreamController<String>.broadcast();
  static Stream<String> get changes => _changes.stream;
  static bool _localProfilesLoaded = false;
  static final Map<String, int> _revisions = {};

  static File get _profilesFile => File(
    '${Platform.environment['LOCALAPPDATA'] ?? Directory.current.path}'
    '${Platform.pathSeparator}GamerLocker${Platform.pathSeparator}steam_profiles.json',
  );

  static void _loadLocalProfiles() {
    if (_localProfilesLoaded) return;
    _localProfilesLoaded = true;
    try {
      final file = _profilesFile;
      if (!file.existsSync()) return;
      final profiles =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in profiles.entries) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        final id = value['steamId64']?.toString() ?? '';
        final avatar = value['avatarUrl']?.toString() ?? '';
        if (!_validAuthenticatedAvatar(id, avatar)) continue;
        _lastSuccessful[entry.key] = SteamPublicProfile(
          steamId64: id,
          displayName: value['displayName']?.toString() ?? id,
          avatarUrl: avatar,
          onlineState: 'offline',
          stateMessage: '',
          profileUrl: 'https://steamcommunity.com/profiles/$id',
        );
      }
    } catch (_) {
      // Public profile cache must not prevent the app from opening.
    }
  }

  static bool _validAuthenticatedAvatar(String id, String avatar) {
    final uri = Uri.tryParse(avatar);
    return RegExp(r'^\d{17}$').hasMatch(id) &&
        uri != null &&
        uri.scheme == 'https' &&
        (uri.host == 'steamstatic.com' ||
            uri.host.endsWith('.steamstatic.com'));
  }

  static SteamPublicProfile? cachedProfile(String reference) {
    _loadLocalProfiles();
    return _lastSuccessful[reference.trim()];
  }

  static void rememberAuthenticatedProfile({
    required String reference,
    required String steamId64,
    required String avatarUrl,
    String? displayName,
    bool persist = true,
  }) {
    if (reference.trim().isEmpty ||
        !_validAuthenticatedAvatar(steamId64, avatarUrl)) {
      return;
    }
    _loadLocalProfiles();
    final key = reference.trim();
    final previous = _lastSuccessful[key];
    final sameAccount = previous?.steamId64 == steamId64;
    final profile = SteamPublicProfile(
      steamId64: steamId64,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : sameAccount
          ? previous!.displayName
          : steamId64,
      avatarUrl: avatarUrl,
      onlineState: sameAccount ? previous!.onlineState : 'offline',
      stateMessage: sameAccount ? previous!.stateMessage : '',
      profileUrl: 'https://steamcommunity.com/profiles/$steamId64',
    );
    _lastSuccessful[key] = profile;
    _revisions[key] = (_revisions[key] ?? 0) + 1;
    _cache[key] = Future.value(profile);
    _expiresAt[key] = DateTime.now().add(const Duration(minutes: 5));
    try {
      if (!persist) {
        _changes.add(key);
        return;
      }
      final file = _profilesFile;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode(
          _lastSuccessful.map(
            (key, value) => MapEntry(key, {
              'steamId64': value.steamId64,
              'displayName': value.displayName,
              'avatarUrl': value.avatarUrl,
            }),
          ),
        ),
      );
    } catch (_) {
      // Current in-memory profile still updates if disk caching fails.
    }
    _changes.add(key);
  }

  static Future<SteamPublicProfile?> fetchProfile(
    String rawSteamId, {
    bool forceRefresh = false,
  }) {
    _loadLocalProfiles();
    final key = rawSteamId.trim();

    if (key.isEmpty) {
      return Future.value(null);
    }
    if (key.startsWith('steam-login:') && !_lastSuccessful.containsKey(key)) {
      return Future.value(null);
    }

    if (forceRefresh ||
        (_expiresAt[key] != null && DateTime.now().isAfter(_expiresAt[key]!))) {
      _cache.remove(key);
    }

    return _cache.putIfAbsent(key, () async {
      final revision = _revisions[key] ?? 0;
      final profile = await _fetchProfile(
        _lastSuccessful[key]?.steamId64 ?? key,
      );
      if ((_revisions[key] ?? 0) != revision) return _lastSuccessful[key];
      if (profile != null) {
        final previous = _lastSuccessful[key];
        final resolved = profile.avatarUrl.isEmpty && previous != null
            ? SteamPublicProfile(
                steamId64: profile.steamId64,
                displayName: profile.displayName,
                avatarUrl: previous.avatarUrl,
                onlineState: profile.onlineState,
                stateMessage: profile.stateMessage,
                profileUrl: profile.profileUrl,
              )
            : profile;
        _lastSuccessful[key] = resolved;
        _expiresAt[key] = DateTime.now().add(const Duration(minutes: 5));
        return resolved;
      }
      // Do not permanently cache a temporary HTTP failure or erase a known photo.
      _expiresAt[key] = DateTime.now().add(const Duration(seconds: 5));
      return _lastSuccessful[key];
    });
  }

  static Future<SteamPublicProfile?> _fetchProfile(String rawSteamId) async {
    final profileUri = profileUriFor(rawSteamId);

    if (profileUri == null) {
      return null;
    }

    final xmlUri = profileUri.replace(queryParameters: const {'xml': '1'});

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..userAgent = 'GamerLocker/1.0';

    try {
      final request = await client.getUrl(xmlUri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/xml,text/xml;q=0.9,*/*;q=0.8',
      );

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }

      final xml = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));

      final displayName = _readTag(xml, 'steamID');
      final fullAvatar = _readTag(xml, 'avatarFull');
      final mediumAvatar = _readTag(xml, 'avatarMedium');
      final avatar = fullAvatar.isNotEmpty
          ? fullAvatar
          : mediumAvatar.isNotEmpty
          ? mediumAvatar
          : _readTag(xml, 'avatarIcon');
      final onlineState = _readTag(xml, 'onlineState');
      final stateMessage = _readTag(xml, 'stateMessage');
      final steamId64 = _readTag(xml, 'steamID64');

      if (displayName.isEmpty && steamId64.isEmpty) {
        return null;
      }

      return SteamPublicProfile(
        steamId64: steamId64,
        displayName: displayName.isEmpty ? rawSteamId : displayName,
        avatarUrl: avatar,
        onlineState: onlineState,
        stateMessage: stateMessage,
        profileUrl: profileUri.toString(),
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> openProfile(String rawSteamId) async {
    final uri = profileUriFor(rawSteamId);

    if (uri == null) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Uri? profileUriFor(String rawSteamId) {
    var value = rawSteamId.trim();

    if (value.isEmpty) {
      return null;
    }

    final pastedUri = Uri.tryParse(value);

    if (pastedUri != null &&
        pastedUri.hasScheme &&
        pastedUri.host.toLowerCase() == 'steamcommunity.com') {
      final segments = pastedUri.pathSegments;

      if (segments.length >= 2 &&
          (segments.first == 'profiles' || segments.first == 'id')) {
        return Uri(
          scheme: 'https',
          host: 'steamcommunity.com',
          pathSegments: [segments.first, segments[1]],
        );
      }

      return null;
    }

    final steam2 = RegExp(
      r'^STEAM_[0-5]:([01]):(\d+)$',
      caseSensitive: false,
    ).firstMatch(value);

    if (steam2 != null) {
      final y = int.parse(steam2.group(1)!);
      final z = int.parse(steam2.group(2)!);
      value = (_steamId64Base + (z * 2) + y).toString();
    }

    final steam3 = RegExp(
      r'^\[U:1:(\d+)\]$',
      caseSensitive: false,
    ).firstMatch(value);

    if (steam3 != null) {
      final accountId = int.parse(steam3.group(1)!);
      value = (_steamId64Base + accountId).toString();
    }

    if (RegExp(r'^\d{17}$').hasMatch(value)) {
      return Uri(
        scheme: 'https',
        host: 'steamcommunity.com',
        pathSegments: ['profiles', value],
      );
    }

    if (RegExp(r'^[A-Za-z0-9_-]{2,64}$').hasMatch(value)) {
      return Uri(
        scheme: 'https',
        host: 'steamcommunity.com',
        pathSegments: ['id', value],
      );
    }

    return null;
  }

  static String _readTag(String xml, String tag) {
    final escapedTag = RegExp.escape(tag);

    final cdata = RegExp(
      '<$escapedTag>\\s*<!\\[CDATA\\[(.*?)\\]\\]>\\s*</$escapedTag>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(xml);

    if (cdata != null) {
      return _decodeXml(cdata.group(1) ?? '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final normal = RegExp(
      '<$escapedTag[^>]*>(.*?)</$escapedTag>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(xml);

    if (normal == null) {
      return '';
    }

    return _decodeXml(normal.group(1) ?? '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }

  static String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
  }
}
