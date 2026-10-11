import 'dart:async';

import 'package:flutter/material.dart';

import 'steam_profile_service.dart';

class SteamAccountAvatar extends StatefulWidget {
  final String reference;
  final String login;
  final double size;
  final double radius;
  const SteamAccountAvatar({
    super.key,
    required this.reference,
    required this.login,
    this.size = 46,
    this.radius = 13,
  });

  @override
  State<SteamAccountAvatar> createState() => _SteamAccountAvatarState();
}

class _SteamAccountAvatarState extends State<SteamAccountAvatar> {
  StreamSubscription<String>? subscription;
  SteamPublicProfile? profile;
  int revision = 0;
  String get loginReference => SteamProfileService.loginReference(widget.login);
  SteamPublicProfile? get cached =>
      SteamProfileService.cachedProfile(loginReference) ??
      SteamProfileService.cachedProfile(widget.reference);

  @override
  void initState() {
    super.initState();
    profile = cached;
    subscription = SteamProfileService.changes.listen((reference) {
      if (!mounted ||
          (reference != loginReference && reference != widget.reference.trim())) {
        return;
      }
      setState(() => profile = cached ?? profile);
    });
    load();
  }

  Future<void> load() async {
    final current = ++revision;
    final value = await SteamProfileService.fetchProfile(
      cached?.steamId64 ?? widget.reference,
    );
    if (!mounted || current != revision) return;
    setState(() => profile = cached ?? value ?? profile);
  }

  @override
  void didUpdateWidget(SteamAccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.login != widget.login ||
        oldWidget.reference != widget.reference) {
      profile = cached;
      load();
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.sports_esports, color: Colors.white);
    final url = profile?.avatarUrl ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                key: ValueKey(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
