import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'vault_store.dart';

class BackupException implements Exception {
  final String message;

  const BackupException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  BackupService._();

  static const XTypeGroup _backupType = XTypeGroup(
    label: 'SteamVault backup',
    extensions: <String>['sv'],
  );

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String _timestamp() {
    final now = DateTime.now();

    return '${now.year}'
        '${_two(now.month)}'
        '${_two(now.day)}_'
        '${_two(now.hour)}'
        '${_two(now.minute)}'
        '${_two(now.second)}';
  }

  static String _suggestedBackupName() {
    final now = DateTime.now();

    return 'SteamVault_Backup_'
        '${now.year}-'
        '${_two(now.month)}-'
        '${_two(now.day)}_'
        '${_two(now.hour)}'
        '${_two(now.minute)}'
        '.sv';
  }

  static Future<String> localVaultPath() async {
    return VaultStore.instance.getVaultPath();
  }

  static Future<String> automaticBackupPath() async {
    final vaultPath = await localVaultPath();
    return '$vaultPath.bak';
  }

  static Future<bool> automaticBackupExists() async {
    final path = await automaticBackupPath();
    return File(path).exists();
  }

  static Future<String?> exportBackup() async {
    final sourcePath = await localVaultPath();
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw const BackupException('Nenhum cofre local foi encontrado.');
    }

    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_backupType],
      suggestedName: _suggestedBackupName(),
      confirmButtonText: 'Salvar backup',
    );

    if (location == null) {
      return null;
    }

    final bytes = await source.readAsBytes();

    await File(location.path).writeAsBytes(bytes, flush: true);

    return location.path;
  }

  static Future<String?> restoreFromPicker() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_backupType],
      confirmButtonText: 'Restaurar backup',
    );

    if (selected == null) {
      return null;
    }

    final bytes = await selected.readAsBytes();

    _validateBackup(bytes);

    final targetPath = await localVaultPath();
    final target = File(targetPath);

    if (await target.exists()) {
      final safetyCopy = File('$targetPath.before_restore_${_timestamp()}.sv');

      await target.copy(safetyCopy.path);
    }

    await target.writeAsBytes(bytes, flush: true);

    VaultStore.instance.lock();

    return selected.name;
  }

  static Future<void> restoreAutomaticBackup() async {
    final targetPath = await localVaultPath();

    final target = File(targetPath);
    final backup = File('$targetPath.bak');

    if (!await backup.exists()) {
      throw const BackupException(
        'Ainda nao existe um backup automatico local.',
      );
    }

    _validateBackup(await backup.readAsBytes());

    if (await target.exists()) {
      final safetyCopy = File(
        '$targetPath.before_auto_restore_${_timestamp()}.sv',
      );

      await target.copy(safetyCopy.path);
    }

    await backup.copy(target.path);

    VaultStore.instance.lock();
  }

  static void _validateBackup(List<int> bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);

      final raw = jsonDecode(decoded);

      if (raw is! Map) {
        throw const BackupException('Arquivo de backup invalido.');
      }

      final data = Map<String, dynamic>.from(raw);

      if (data['format'] != 'steamvault') {
        throw const BackupException('Este arquivo nao e um backup SteamVault.');
      }

      if (data['version'] != 1) {
        throw const BackupException('Versao de backup nao suportada.');
      }

      final requiredFields = <String>[
        'kdf',
        'passwordSalt',
        'recoverySalt',
        'masterByPassword',
        'masterByRecovery',
        'vault',
      ];

      for (final field in requiredFields) {
        if (!data.containsKey(field)) {
          throw const BackupException(
            'O backup esta incompleto ou corrompido.',
          );
        }
      }

      base64Decode(data['passwordSalt'] as String);

      base64Decode(data['recoverySalt'] as String);

      base64Decode(data['masterByPassword'] as String);

      base64Decode(data['masterByRecovery'] as String);

      base64Decode(data['vault'] as String);
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'O arquivo selecionado nao parece ser um backup SteamVault valido.',
      );
    }
  }
}
