import 'dart:async';

import 'package:flutter/material.dart' hide Text, SelectableText;

import 'app_localizations.dart';
import 'update_service.dart';
import 'app_backend.dart';

class GamerLockerUpdateGate extends StatefulWidget {
  final Widget child;

  const GamerLockerUpdateGate({super.key, required this.child});

  @override
  State<GamerLockerUpdateGate> createState() => _GamerLockerUpdateGateState();
}

class _GamerLockerUpdateGateState extends State<GamerLockerUpdateGate> {
  bool _checked = false;
  StreamSubscription<dynamic>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (GamerLockerUpdateService.privateUpdates && AppBackend.configured) {
      _authSubscription = AppBackend.client.auth.onAuthStateChange.listen((
        event,
      ) {
        if (event.session != null && mounted) unawaited(_checkUpdate());
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkUpdate());
    });
  }

  Future<void> _checkUpdate() async {
    if (_checked || !GamerLockerUpdateService.shouldCheckAutomatically) {
      return;
    }

    if (GamerLockerUpdateService.privateUpdates &&
        (!AppBackend.configured ||
            AppBackend.client.auth.currentSession == null)) {
      return;
    }

    _checked = true;

    final update = await GamerLockerUpdateService.checkForUpdate();

    if (!mounted || update == null) {
      return;
    }

    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151821),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3B3457)),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update_alt_rounded, color: Color(0xFFAA9BFF)),
              SizedBox(width: 10),
              Expanded(child: Text('Nova versão disponível')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GamerLocker $gamerLockerCurrentVersion → ${update.version}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Uma atualização do GamerLocker está pronta para instalar.',
                  style: TextStyle(color: Colors.grey.shade300, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF9A87FF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seu cofre permanece no mesmo local durante a atualização.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Agora não'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Atualizar'),
            ),
          ],
        );
      },
    );

    if (shouldUpdate == true && mounted) {
      await _downloadAndUpdate(update);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _downloadAndUpdate(GamerLockerUpdateInfo update) async {
    final progress = ValueNotifier<double?>(0);
    final status = ValueNotifier<String>(
      'Baixando GamerLocker ${update.version}...',
    );

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: const Color(0xFF151821),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF3B3457)),
              ),
              title: const Text('Atualizando GamerLocker'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: status,
                      builder: (context, value, child) {
                        return Text(
                          value,
                          style: TextStyle(color: Colors.grey.shade300),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    ValueListenableBuilder<double?>(
                      valueListenable: progress,
                      builder: (context, value, child) {
                        return Column(
                          children: [
                            LinearProgressIndicator(
                              value: value,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                value == null
                                    ? 'Baixando...'
                                    : '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'O GamerLocker será fechado, atualizado e aberto novamente.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    try {
      final installer = await GamerLockerUpdateService.downloadInstaller(
        update,
        onProgress: (value) {
          progress.value = value;
        },
      );

      status.value = 'Preparando instalação...';
      progress.value = 1;

      status.value = 'Iniciando instalador...';

      await GamerLockerUpdateService.launchInstallerAfterExit(installer);

      status.value = 'Instalando atualização...';

      // O GamerLocker permanece aberto.
      // O Inno Setup fecha o aplicativo pelo /CLOSEAPPLICATIONS,
      // instala a nova versão e abre o GamerLocker novamente.
      await Future<void>.delayed(const Duration(minutes: 10));
    } catch (error) {
      if (!mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Não foi possível atualizar'),
            content: Text(
              'O GamerLocker continua funcionando normalmente.\n\n'
              'Detalhe: $error',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      progress.dispose();
      status.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
