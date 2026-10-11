import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steamvault2/main.dart' show SteamProfileSummary;
import 'package:steamvault2/steam_profile_service.dart';
import 'package:steamvault2/steam_cooldown_service.dart';

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _Response extends Fake implements HttpClientResponse {
  _Response(this.statusCode, this.body);
  _Response.image(this.imageBytes) : statusCode = 200, body = '';
  List<int>? imageBytes;
  @override
  final int statusCode;
  final String body;
  @override
  int get contentLength => imageBytes?.length ?? utf8.encode(body).length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(imageBytes ?? utf8.encode(body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  Future<E> drain<E>([E? futureValue]) =>
      const Stream<List<int>>.empty().drain<E>(futureValue);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => response;
}

class _Client extends Fake implements HttpClient {
  final responses = <_Response>[];
  int requests = 0;
  Completer<void>? gate;
  @override
  set autoUncompress(bool value) {}
  @override
  set connectionTimeout(Duration? value) {}
  @override
  set userAgent(String? value) {}
  @override
  void close({bool force = false}) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    if (gate != null) await gate!.future;
    return _Request(responses.removeAt(0));
  }
}

String _profile({String? full, String? medium}) => '''
<profile><steamID64>76561198000000000</steamID64>
<steamID><![CDATA[Photo test]]></steamID><onlineState>offline</onlineState>
${full == null ? '' : '<avatarFull><![CDATA[$full]]></avatarFull>'}
${medium == null ? '' : '<avatarMedium><![CDATA[$medium]]></avatarMedium>'}
</profile>''';

void main() {
  test('temporary failure retries and refresh keeps the last successful photo', () async {
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      client.responses.add(_Response(503, 'temporary failure'));
      expect(await SteamProfileService.fetchProfile('photo_retry_test'), isNull);

      client.responses.add(_Response(200, _profile(full: 'https://cdn.example.invalid/avatar.jpg')));
      final loaded = await SteamProfileService.fetchProfile('photo_retry_test', forceRefresh: true);
      expect(loaded?.avatarUrl, 'https://cdn.example.invalid/avatar.jpg');
      expect(loaded?.statusLabel, 'Offline');

      client.responses.add(_Response(503, 'temporary failure'));
      final retained = await SteamProfileService.fetchProfile('photo_retry_test', forceRefresh: true);
      expect(retained?.avatarUrl, loaded?.avatarUrl);

      client.responses.add(_Response(200, _profile()));
      final missingPhoto = await SteamProfileService.fetchProfile('photo_retry_test', forceRefresh: true);
      expect(missingPhoto?.avatarUrl, loaded?.avatarUrl);
      expect(client.requests, 4);
    }, createHttpClient: (_) => client);
  });

  test('medium avatar works when full avatar is missing', () async {
    final client = _Client()..responses.add(
      _Response(200, _profile(medium: 'https://cdn.example.invalid/medium.jpg')),
    );
    await HttpOverrides.runZoned(() async {
      final profile = await SteamProfileService.fetchProfile('photo_medium_test');
      expect(profile?.avatarUrl, 'https://cdn.example.invalid/medium.jpg');
    }, createHttpClient: (_) => client);
  });

  test('group failure does not discard a successful cooldown', () {
    final result = SteamCooldownResult.fromJson({
      'status': 'ok', 'penaltySeconds': 400000,
      'groupStatus': 'failed', 'groupMessage': 'Group unavailable',
    });
    expect(result.hasCooldown, isTrue);
    expect(result.groupStatus, 'failed');
    expect(result.groupMessage, 'Group unavailable');
  });

  test('an older public request cannot replace the authenticated account photo', () async {
    final client = _Client()
      ..gate = Completer<void>()
      ..responses.add(_Response(200, _profile(full: 'https://cdn.example.invalid/old.jpg')));
    await HttpOverrides.runZoned(() async {
      final pending = SteamProfileService.fetchProfile('auth_photo_race_test');
      SteamProfileService.rememberAuthenticatedProfile(
        reference: 'auth_photo_race_test', steamId64: '76561198000000000',
        avatarUrl: 'https://avatars.fastly.steamstatic.com/1111111111111111111111111111111111111111_full.jpg',
        displayName: 'Authenticated account', persist: false,
      );
      client.gate!.complete();
      expect((await pending)?.displayName, 'Authenticated account');
      expect(SteamProfileService.cachedProfile('auth_photo_race_test')?.steamId64, '76561198000000000');
    }, createHttpClient: (_) => client);
  });

  testWidgets('the profile widget renders the authenticated account image', (tester) async {
    final png = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const ui.Color(0xff00ff00), ui.BlendMode.src);
      final image = await recorder.endRecording().toImage(1, 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    final client = _Client()..responses.add(_Response.image(png!));
    SteamProfileService.rememberAuthenticatedProfile(
      reference: 'auth_photo_widget_test', steamId64: '76561198000000000',
      avatarUrl: 'https://avatars.fastly.steamstatic.com/1111111111111111111111111111111111111111_full.jpg',
      displayName: 'Authenticated photo', persist: false,
    );
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(
        body: SteamProfileSummary(steamId: 'auth_photo_widget_test'),
      )));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.text('Authenticated photo'), findsOneWidget);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.takeException(), isNull);

      // A verification updates an already-visible profile, not only a newly built one.
      client.responses.add(_Response.image(png));
      SteamProfileService.rememberAuthenticatedProfile(
        reference: 'auth_photo_widget_test', steamId64: '76561198000000000',
        avatarUrl: 'https://avatars.fastly.steamstatic.com/2222222222222222222222222222222222222222_full.jpg',
        displayName: 'Updated authenticated photo', persist: false,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('Updated authenticated photo'), findsOneWidget);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(client.requests, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, createHttpClient: (_) => client);
  });
}
