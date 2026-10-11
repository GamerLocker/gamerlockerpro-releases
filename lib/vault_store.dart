import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

class VaultException implements Exception {
  final String message;

  const VaultException(this.message);

  @override
  String toString() => message;
}

class VaultStore {
  VaultStore._();

  static final VaultStore instance = VaultStore._();

  final AesGcm _cipher = AesGcm.with256bits();

  static const int _argonMemory = 32 * 1024;
  static const int _argonParallelism = 2;
  static const int _argonIterations = 2;
  static const int _argonHashLength = 32;

  static const String _passwordAad = 'steamvault-master-password-v1';

  static const String _recoveryAad = 'steamvault-master-recovery-v1';

  static const String _vaultAad = 'steamvault-data-v1';

  SecretKey? _masterKey;
  Map<String, dynamic>? _envelope;

  bool get isUnlocked => _masterKey != null;

  Future<File> _vaultFile() async {
    final base = await getApplicationSupportDirectory();

    final directory = Directory(
      '${base.path}${Platform.pathSeparator}SteamVault',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}${Platform.pathSeparator}vault.sv');
  }

  Future<bool> exists() async {
    final file = await _vaultFile();
    return file.exists();
  }

  Future<String> getVaultPath() async {
    final file = await _vaultFile();
    return file.path;
  }

  Argon2id _argon({
    required int memory,
    required int parallelism,
    required int iterations,
    required int hashLength,
  }) {
    return Argon2id(
      memory: memory,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: hashLength,
    );
  }

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
    required int memory,
    required int parallelism,
    required int iterations,
    required int hashLength,
  }) {
    return _argon(
      memory: memory,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: hashLength,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  String _encodeBox(SecretBox box) {
    return base64Encode(box.concatenation());
  }

  SecretBox _decodeBox(String encoded) {
    return SecretBox.fromConcatenation(
      base64Decode(encoded),
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();

    return List<int>.generate(
      length,
      (_) => random.nextInt(256),
      growable: false,
    );
  }

  String _generateRecoveryKey() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final random = Random.secure();

    final groups = List.generate(
      8,
      (_) => List.generate(
        4,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join(),
    );

    return 'SV-${groups.join('-')}';
  }

  String _normalizeRecoveryKey(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<String> createVault({
    required String password,
    required Map<String, dynamic> initialData,
  }) async {
    final file = await _vaultFile();

    if (await file.exists()) {
      throw const VaultException('Já existe um cofre neste dispositivo.');
    }

    if (password.length < 8) {
      throw const VaultException('A senha deve ter pelo menos 8 caracteres.');
    }

    final masterKey = await _cipher.newSecretKey();
    final masterBytes = await masterKey.extractBytes();

    final passwordSalt = _randomBytes(16);
    final recoverySalt = _randomBytes(16);

    final recoveryKey = _generateRecoveryKey();

    final passwordKey = await _deriveKey(
      password: password,
      salt: passwordSalt,
      memory: _argonMemory,
      parallelism: _argonParallelism,
      iterations: _argonIterations,
      hashLength: _argonHashLength,
    );

    final recoveryDerivedKey = await _deriveKey(
      password: recoveryKey,
      salt: recoverySalt,
      memory: _argonMemory,
      parallelism: _argonParallelism,
      iterations: _argonIterations,
      hashLength: _argonHashLength,
    );

    final wrappedByPassword = await _cipher.encrypt(
      masterBytes,
      secretKey: passwordKey,
      aad: utf8.encode(_passwordAad),
    );

    final wrappedByRecovery = await _cipher.encrypt(
      masterBytes,
      secretKey: recoveryDerivedKey,
      aad: utf8.encode(_recoveryAad),
    );

    final encryptedVault = await _cipher.encrypt(
      utf8.encode(jsonEncode(initialData)),
      secretKey: masterKey,
      aad: utf8.encode(_vaultAad),
    );

    final envelope = <String, dynamic>{
      'format': 'steamvault',
      'version': 1,
      'kdf': {
        'algorithm': 'argon2id',
        'memory': _argonMemory,
        'parallelism': _argonParallelism,
        'iterations': _argonIterations,
        'hashLength': _argonHashLength,
      },
      'passwordSalt': base64Encode(passwordSalt),
      'recoverySalt': base64Encode(recoverySalt),
      'masterByPassword': _encodeBox(wrappedByPassword),
      'masterByRecovery': _encodeBox(wrappedByRecovery),
      'vault': _encodeBox(encryptedVault),
    };

    await _writeEnvelope(envelope);

    _masterKey = masterKey;
    _envelope = envelope;

    return recoveryKey;
  }

  Future<Map<String, dynamic>> unlockWithPassword(String password) async {
    final envelope = await _readEnvelope();

    final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);

    final salt = base64Decode(envelope['passwordSalt'] as String);

    final derived = await _deriveKey(
      password: password,
      salt: salt,
      memory: kdf['memory'] as int,
      parallelism: kdf['parallelism'] as int,
      iterations: kdf['iterations'] as int,
      hashLength: kdf['hashLength'] as int,
    );

    try {
      final wrapped = _decodeBox(envelope['masterByPassword'] as String);

      final masterBytes = await _cipher.decrypt(
        wrapped,
        secretKey: derived,
        aad: utf8.encode(_passwordAad),
      );

      final masterKey = SecretKey(masterBytes);

      final data = await _decryptVault(envelope, masterKey);

      _masterKey = masterKey;
      _envelope = envelope;

      return data;
    } on SecretBoxAuthenticationError {
      throw const VaultException('Senha incorreta.');
    } catch (_) {
      throw const VaultException('Não foi possível abrir o cofre.');
    }
  }

  Future<Map<String, dynamic>> unlockWithRecoveryKey(String recoveryKey) async {
    final envelope = await _readEnvelope();

    final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);

    final salt = base64Decode(envelope['recoverySalt'] as String);

    final normalized = _normalizeRecoveryKey(recoveryKey);

    final derived = await _deriveKey(
      password: normalized,
      salt: salt,
      memory: kdf['memory'] as int,
      parallelism: kdf['parallelism'] as int,
      iterations: kdf['iterations'] as int,
      hashLength: kdf['hashLength'] as int,
    );

    try {
      final wrapped = _decodeBox(envelope['masterByRecovery'] as String);

      final masterBytes = await _cipher.decrypt(
        wrapped,
        secretKey: derived,
        aad: utf8.encode(_recoveryAad),
      );

      final masterKey = SecretKey(masterBytes);

      final data = await _decryptVault(envelope, masterKey);

      _masterKey = masterKey;
      _envelope = envelope;

      return data;
    } on SecretBoxAuthenticationError {
      throw const VaultException('Recovery Key incorreta.');
    } catch (_) {
      throw const VaultException('Não foi possível recuperar o cofre.');
    }
  }

  Future<Map<String, dynamic>> _decryptVault(
    Map<String, dynamic> envelope,
    SecretKey masterKey,
  ) async {
    final encrypted = _decodeBox(envelope['vault'] as String);

    final bytes = await _cipher.decrypt(
      encrypted,
      secretKey: masterKey,
      aad: utf8.encode(_vaultAad),
    );

    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  }

  Future<void> saveVault(Map<String, dynamic> data) async {
    final masterKey = _masterKey;
    final envelope = _envelope;

    if (masterKey == null || envelope == null) {
      throw const VaultException('O cofre está bloqueado.');
    }

    final encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: masterKey,
      aad: utf8.encode(_vaultAad),
    );

    envelope['vault'] = _encodeBox(encrypted);

    await _writeEnvelope(envelope);
  }

  Future<Map<String, dynamic>> _readEnvelope() async {
    final file = await _vaultFile();

    if (!await file.exists()) {
      throw const VaultException('Nenhum cofre foi encontrado.');
    }

    try {
      final content = await file.readAsString();

      final envelope = Map<String, dynamic>.from(jsonDecode(content) as Map);

      if (envelope['format'] != 'steamvault' || envelope['version'] != 1) {
        throw const VaultException('Formato de cofre incompatível.');
      }

      return envelope;
    } on VaultException {
      rethrow;
    } catch (_) {
      throw const VaultException(
        'O arquivo do cofre está inválido ou corrompido.',
      );
    }
  }

  Future<void> _writeEnvelope(Map<String, dynamic> envelope) async {
    final file = await _vaultFile();

    if (await file.exists()) {
      final backup = File('${file.path}.bak');

      try {
        await file.copy(backup.path);
      } catch (_) {}
    }

    await file.writeAsString(jsonEncode(envelope), flush: true);
  }

  void lock() {
    _masterKey = null;
    _envelope = null;
  }
}
