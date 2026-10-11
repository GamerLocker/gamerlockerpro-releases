import 'dart:async';

import 'package:flutter/material.dart' hide Text, SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations.dart';
import 'vault_store.dart';
import 'backup_service.dart';
import 'plan_service.dart';
import 'purchase_pro_screen.dart';
import 'product_key_service.dart';
import 'plan_validity.dart';
import 'app_backend.dart';
import 'auth_screens.dart';
import 'steam_profile_service.dart';
import 'steam_cooldown_service.dart';
import 'steam_account_screen.dart';
import 'steam_account_avatar.dart';
import 'update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBackend.initialize();
  await GamerLockerLocale.load();

  runApp(const GamerLockerApp());
}

class GamerLockerApp extends StatelessWidget {
  const GamerLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: GamerLockerLocale.current,
      builder: (context, locale, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GamerLocker',
          locale: locale,
          supportedLocales: GamerLockerLocale.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (locale != null) {
              return locale;
            }

            if (deviceLocale?.languageCode.toLowerCase() == 'pt') {
              return const Locale('pt', 'BR');
            }

            return const Locale('en', 'US');
          },
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C5CFC),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0D0F14),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF171A21),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF292D38)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF7C5CFC),
                  width: 1.5,
                ),
              ),
            ),
          ),
          home: GamerLockerUpdateGate(
            child: AccountAuthGate(nextBuilder: (_) => const StartupScreen()),
          ),
        );
      },
    );
  }
}

class AccountEntry {
  static const Set<String> defaultDashboardFields = {
    'Login',
    'Premier Rating',
    'Prime',
  };

  String name;
  String type;
  Map<String, String> fields;
  bool favorite;
  Set<String> dashboardFields;
  Map<String, bool> security;

  AccountEntry({
    required this.name,
    required this.type,
    required this.fields,
    this.favorite = false,
    Set<String>? dashboardFields,
    Map<String, bool>? security,
  }) : dashboardFields = dashboardFields ?? {...defaultDashboardFields},
       security = security ?? <String, bool>{};

  String get steamProfile {
    final login = fields['Login']?.trim() ?? '';
    if (type == 'Steam' && login.isNotEmpty) {
      final authenticated = SteamProfileService.cachedProfile(
        SteamProfileService.loginReference(login),
      )?.steamId64 ?? SteamCooldownService.cached(login)?.steamId64;
      if (authenticated != null && authenticated.isNotEmpty) return authenticated;
    }
    final profile = fields['Perfil Steam']?.trim() ?? '';

    if (profile.isNotEmpty) {
      return profile;
    }

    return fields['SteamID']?.trim() ?? '';
  }

  // Mantido por compatibilidade com os pontos existentes do app.
  // O valor pode ser SteamID, vanity ID ou URL completa do perfil.
  String get steamId => steamProfile;
  String get steamProfileReference => steamProfile.isNotEmpty
      ? steamProfile
      : SteamProfileService.loginReference(fields['Login'] ?? '');

  bool get hasSteamProfile => type == 'Steam' && steamProfile.isNotEmpty;

  String get displayName {
    final configuredName = name.trim();

    if (configuredName.isNotEmpty) {
      return configuredName;
    }

    final login = fields['Login']?.trim() ?? '';

    if (login.isNotEmpty) {
      return login;
    }

    final configuredType = type.trim();

    return configuredType.isEmpty ? 'Conta' : configuredType;
  }

  int get securityScore {
    final checks = <bool>[
      (fields['E-mail vinculado'] ?? '').trim().isNotEmpty,
      (fields['Telefone vinculado'] ?? '').trim().isNotEmpty,
      security['twoFactor'] == true,
      security['recoveryCode'] == true,
      security['backupCodes'] == true,
      security['emailVerified'] == true,
      security['phoneVerified'] == true,
    ];

    final completed = checks.where((value) => value).length;
    return ((completed / checks.length) * 100).round();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'fields': fields,
      'favorite': favorite,
      'dashboardFields': dashboardFields.toList(),
      'security': security,
    };
  }

  factory AccountEntry.fromJson(Map<String, dynamic> json) {
    final rawFields = Map<String, dynamic>.from(json['fields'] as Map? ?? {});

    final rawDashboard = json['dashboardFields'];

    final dashboardFields = rawDashboard is List
        ? rawDashboard.map((item) => item.toString()).toSet()
        : {...defaultDashboardFields};

    final rawSecurity = Map<String, dynamic>.from(
      json['security'] as Map? ?? {},
    );

    final security = rawSecurity.map(
      (key, value) => MapEntry(
        key,
        value == true || value?.toString().toLowerCase() == 'true',
      ),
    );

    return AccountEntry(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      fields: rawFields.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      favorite: json['favorite'] == true,
      dashboardFields: dashboardFields,
      security: security,
    );
  }
}

class VaultData {
  final String name;
  final String email;
  final List<AccountEntry> accounts;
  String dashboardTheme;
  String dashboardView;

  VaultData({
    required this.name,
    required this.email,
    required this.accounts,
    this.dashboardTheme = 'midnight',
    this.dashboardView = 'cards',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'accounts': accounts.map((account) => account.toJson()).toList(),
      'dashboardTheme': dashboardTheme,
      'dashboardView': dashboardView,
    };
  }

  factory VaultData.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'] as List? ?? [];
    final rawDashboardView = json['dashboardView']?.toString();

    return VaultData(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      accounts: rawAccounts
          .map(
            (item) =>
                AccountEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      dashboardTheme: json['dashboardTheme']?.toString() ?? 'midnight',
      dashboardView: rawDashboardView == 'compact' ? 'compact' : 'cards',
    );
  }
}

class DashboardThemeOption {
  final String id;
  final String name;
  final String description;
  final List<Color> colors;

  const DashboardThemeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.colors,
  });

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );
}

const dashboardThemes = <DashboardThemeOption>[
  DashboardThemeOption(
    id: 'midnight',
    name: 'Midnight',
    description: 'Escuro e discreto',
    colors: [Color(0xFF0D0F14), Color(0xFF141826), Color(0xFF0D0F14)],
  ),
  DashboardThemeOption(
    id: 'rgb',
    name: 'RGB Neon',
    description: 'Roxo, azul e verde em estilo gamer',
    colors: [Color(0xFF24002F), Color(0xFF071A3D), Color(0xFF003827)],
  ),
  DashboardThemeOption(
    id: 'violet',
    name: 'Violet',
    description: 'Roxo profundo',
    colors: [Color(0xFF120B26), Color(0xFF32145F), Color(0xFF101426)],
  ),
  DashboardThemeOption(
    id: 'cyber',
    name: 'Cyber Blue',
    description: 'Azul e ciano',
    colors: [Color(0xFF03131C), Color(0xFF07364A), Color(0xFF101326)],
  ),
  DashboardThemeOption(
    id: 'crimson',
    name: 'Crimson',
    description: 'Vermelho escuro',
    colors: [Color(0xFF1C080C), Color(0xFF471020), Color(0xFF11131A)],
  ),
  DashboardThemeOption(
    id: 'emerald',
    name: 'Emerald',
    description: 'Verde profundo',
    colors: [Color(0xFF061711), Color(0xFF073B2A), Color(0xFF10141B)],
  ),
];

DashboardThemeOption dashboardThemeById(String id) {
  return dashboardThemes.firstWhere(
    (theme) => theme.id == id,
    orElse: () => dashboardThemes.first,
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

String formatPremierRating(String input) {
  var text = input.trim().toUpperCase().replaceAll(' ', '');

  if (text.isEmpty) {
    return '';
  }

  if (text.endsWith('K')) {
    final number = text.substring(0, text.length - 1).replaceAll(',', '.');

    final parsed = double.tryParse(number);

    if (parsed == null) {
      return text;
    }

    return formatK(parsed);
  }

  if (RegExp(r'^\d{1,3}[.,]\d{3}$').hasMatch(text)) {
    final raw = text.replaceAll('.', '').replaceAll(',', '');

    final parsed = int.tryParse(raw);

    if (parsed != null) {
      return formatK(parsed / 1000);
    }
  }

  final decimal = double.tryParse(text.replaceAll(',', '.'));

  if (decimal != null && decimal < 1000) {
    return formatK(decimal);
  }

  final raw = text.replaceAll(RegExp(r'[^0-9]'), '');

  final parsed = int.tryParse(raw);

  if (parsed != null) {
    return formatK(parsed / 1000);
  }

  return text;
}

String formatK(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()}K';
  }

  var result = value.toStringAsFixed(2);

  result = result.replaceFirst(RegExp(r'0+$'), '');

  result = result.replaceFirst(RegExp(r'\.$'), '');

  return '${result}K';
}

Future<void> copySecurely(String value) async {
  await Clipboard.setData(ClipboardData(text: value));

  Future.delayed(const Duration(seconds: 30), () async {
    try {
      final current = await Clipboard.getData(Clipboard.kTextPlain);

      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {}
  });
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: VaultStore.instance.exists(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const UnlockScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'GamerLocker',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Seu cofre pessoal para contas de jogos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhum cofre local foi encontrado neste dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 38),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateVaultScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Criar novo cofre'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RestoreVaultScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restaurar meu cofre'),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'O backup permanece criptografado.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateVaultScreen extends StatefulWidget {
  const CreateVaultScreen({super.key});

  @override
  State<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends State<CreateVaultScreen> {
  final nameController = TextEditingController();

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final confirmController = TextEditingController();

  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();

    super.dispose();
  }

  Future<void> create() async {
    final name = nameController.text.trim();

    final email = emailController.text.trim();

    final password = passwordController.text;

    if (name.isEmpty) {
      showError('Informe seu nome.');
      return;
    }

    if (!email.contains('@')) {
      showError('Informe um e-mail válido.');
      return;
    }

    if (password.length < 8) {
      showError('Use uma senha com pelo menos 8 caracteres.');
      return;
    }

    if (password != confirmController.text) {
      showError('As senhas não são iguais.');
      return;
    }

    setState(() {
      loading = true;
    });

    final data = VaultData(name: name, email: email, accounts: []);

    try {
      final recoveryKey = await VaultStore.instance.createVault(
        password: password,
        initialData: data.toJson(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RecoveryKeyScreen(recoveryKey: recoveryKey, data: data),
        ),
        (_) => false,
      );
    } on VaultException catch (e) {
      showError(e.message);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar cofre')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crie seu cofre',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: gl('Nome'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: gl('E-mail'),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: gl('Senha do cofre'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: gl('Confirmar senha'),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : create,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar cofre'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecoveryKeyScreen extends StatefulWidget {
  final String recoveryKey;
  final VaultData data;

  const RecoveryKeyScreen({
    super.key,
    required this.recoveryKey,
    required this.data,
  });

  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  bool confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                const Icon(
                  Icons.key_rounded,
                  size: 72,
                  color: Color(0xFF9A87FF),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sua Recovery Key',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ela pode desbloquear seu cofre caso você esqueça a senha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171A21),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF363B49)),
                  ),
                  child: Column(
                    children: [
                      SelectableText(
                        widget.recoveryKey,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await copySecurely(widget.recoveryKey);

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Recovery Key copiada. O clipboard será limpo em 30 segundos.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF211A12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'O GamerLocker não armazena esta chave em texto legível. Guarde-a fora deste computador também.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  title: const Text(
                    'Salvei minha Recovery Key em um local seguro.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      confirmed = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: confirmed
                        ? () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DashboardScreen(data: widget.data),
                              ),
                              (_) => false,
                            );
                          }
                        : null,
                    child: const Text('Entrar no cofre'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final passwordController = TextEditingController();

  bool showPassword = false;
  bool loading = false;

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  Future<void> unlock() async {
    if (passwordController.text.isEmpty) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final raw = await VaultStore.instance.unlockWithPassword(
        passwordController.text,
      );

      final data = VaultData.fromJson(raw);

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(data: data)),
        (_) => false,
      );
    } on VaultException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.lock, size: 38),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GamerLocker',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Desbloqueie seu cofre',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: passwordController,
                  autofocus: true,
                  obscureText: !showPassword,
                  onSubmitted: (_) => unlock(),
                  decoration: InputDecoration(
                    labelText: gl('Senha do cofre'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : unlock,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Desbloquear'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecoveryUnlockScreen(),
                      ),
                    );
                  },
                  child: const Text('Usar Recovery Key'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecoveryUnlockScreen extends StatefulWidget {
  const RecoveryUnlockScreen({super.key});

  @override
  State<RecoveryUnlockScreen> createState() => _RecoveryUnlockScreenState();
}

class _RecoveryUnlockScreenState extends State<RecoveryUnlockScreen> {
  final controller = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> recover() async {
    setState(() {
      loading = true;
    });

    try {
      final raw = await VaultStore.instance.unlockWithRecoveryKey(
        controller.text,
      );

      final data = VaultData.fromJson(raw);

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(data: data)),
        (_) => false,
      );
    } on VaultException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Key')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: gl('Recovery Key'),
                    hintText: gl('SV-XXXX-XXXX-...'),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : recover,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Recuperar cofre'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VaultData data;

  const DashboardScreen({super.key, required this.data});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late VaultData data;

  final searchController = TextEditingController();

  bool saving = false;
  String searchQuery = '';
  final Set<int> expandedAccountIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> persist() async {
    try {
      setState(() {
        saving = true;
      });

      await VaultStore.instance.saveVault(data.toJson());
    } on VaultException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> addAccount() async {
    if (!PlanService.canAddAccount(data.accounts.length)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanScreen(accountCount: data.accounts.length),
        ),
      );
      return;
    }

    final account = await Navigator.push<AccountEntry>(
      context,
      MaterialPageRoute(builder: (_) => const AccountFormScreen()),
    );

    if (account == null) {
      return;
    }

    setState(() {
      data.accounts.add(account);
    });

    await persist();
  }

  Future<void> importAccounts() async {
    final imported = await Navigator.push<List<AccountEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => BulkImportScreen(
          existingAccounts: List<AccountEntry>.unmodifiable(data.accounts),
        ),
      ),
    );

    if (imported == null || imported.isEmpty) {
      return;
    }

    setState(() {
      data.accounts.addAll(imported);
    });

    await persist();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${imported.length} conta${imported.length == 1 ? '' : 's'} importada${imported.length == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  Future<void> editAccount(int index) async {
    final updated = await Navigator.push<AccountEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(account: data.accounts[index]),
      ),
    );

    if (updated == null) {
      return;
    }

    setState(() {
      data.accounts[index] = updated;
    });

    await persist();
  }

  Future<void> deleteAccount(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir conta?'),
          content: Text(
            'Deseja excluir "${data.accounts[index].displayName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      data.accounts.removeAt(index);
    });

    await persist();
  }

  Future<void> openAccount(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountDetailsScreen(
          account: data.accounts[index],
          onChanged: (updated) async {
            setState(() {
              data.accounts[index] = updated;
            });
            await persist();
          },
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> toggleFavorite(int index) async {
    setState(() {
      data.accounts[index].favorite = !data.accounts[index].favorite;
    });

    await persist();
  }

  Future<void> openSteamProfile(AccountEntry account) async {
    try {
      final opened = await SteamProfileService.openProfile(account.steamId);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nao foi possivel abrir o perfil. Confira o Perfil Steam informado.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o perfil Steam.')),
      );
    }
  }

  List<_IndexedAccount> get visibleAccounts {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    final items = data.accounts
        .asMap()
        .entries
        .map((entry) {
          return _IndexedAccount(index: entry.key, account: entry.value);
        })
        .where((item) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          final searchable = <String>[
            item.account.displayName,
            item.account.type,
            ...item.account.fields.entries
                .where((field) => !field.key.toLowerCase().contains('senha'))
                .expand((field) => [field.key, field.value]),
          ].join(' ').toLowerCase();

          return searchable.contains(normalizedQuery);
        })
        .toList();

    return items;
  }

  Future<void> moveAccount(int fromIndex, int toIndex) async {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= data.accounts.length ||
        toIndex >= data.accounts.length) {
      return;
    }

    setState(() {
      final moved = data.accounts.removeAt(fromIndex);
      var insertIndex = toIndex;

      if (fromIndex < toIndex) {
        insertIndex--;
      }

      data.accounts.insert(insertIndex, moved);
    });

    await persist();
  }

  Widget buildAccountGrid(List<_IndexedAccount> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = available >= 1160
            ? 3
            : available >= 760
            ? 2
            : 1;

        final expandedWidth = columns == 1
            ? available
            : (available - ((columns - 1) * 18)) / columns;
        final compactWidth = available < 760
            ? available
            : (available >= 1160 ? 330.0 : 320.0);

        final dragEnabled =
            searchQuery.trim().isEmpty && data.accounts.length > 1;

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: items.map((item) {
            final isExpanded = expandedAccountIndexes.contains(item.index);

            return DragTarget<int>(
              onWillAcceptWithDetails: (details) {
                return dragEnabled && details.data != item.index;
              },
              onAcceptWithDetails: (details) {
                moveAccount(details.data, item.index);
              },
              builder: (context, candidateData, rejectedData) {
                final hovering = candidateData.isNotEmpty;

                return AnimatedScale(
                  scale: hovering ? 1.015 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: isExpanded ? expandedWidth : compactWidth,
                    child: AccountCard(
                      account: item.account,
                      isExpanded: isExpanded,
                      onToggleExpanded: () {
                        setState(() {
                          if (isExpanded) {
                            expandedAccountIndexes.remove(item.index);
                          } else {
                            expandedAccountIndexes.add(item.index);
                          }
                        });
                      },
                      dragIndex: dragEnabled ? item.index : null,
                      onTap: () => openAccount(item.index),
                      onEdit: () => editAccount(item.index),
                      onDelete: () => deleteAccount(item.index),
                      onToggleFavorite: () => toggleFavorite(item.index),
                      onOpenSteamProfile: item.account.hasSteamProfile
                          ? () => openSteamProfile(item.account)
                          : null,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildSection(String title, List<_IndexedAccount> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        buildAccountGrid(items),
        const SizedBox(height: 28),
      ],
    );
  }

  Future<void> chooseDashboardTheme() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Escolher fundo do dashboard'),
          children: dashboardThemes.map((theme) {
            final selectedTheme = data.dashboardTheme == theme.id;

            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, theme.id),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: theme.gradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selectedTheme
                        ? const Color(0xFFAA9BFF)
                        : const Color(0xFF343947),
                    width: selectedTheme ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedTheme
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            theme.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            theme.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );

    if (selected == null || selected == data.dashboardTheme) {
      return;
    }

    setState(() {
      data.dashboardTheme = selected;
    });

    await persist();
  }

  Future<void> reorderAccounts() async {
    final reordered = await Navigator.push<List<AccountEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountOrderScreen(accounts: data.accounts),
      ),
    );

    if (reordered == null) {
      return;
    }

    setState(() {
      data.accounts
        ..clear()
        ..addAll(reordered);
    });

    await persist();
  }

  void lockVault() {
    VaultStore.instance.lock();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = visibleAccounts;
    final favorites = filtered.where((item) => item.account.favorite).toList();
    final others = filtered.where((item) => !item.account.favorite).toList();
    final dashboardTheme = dashboardThemeById(data.dashboardTheme);
    final favoriteCount = data.accounts
        .where((account) => account.favorite)
        .length;
    final protectedCount = data.accounts
        .where((account) => account.securityScore >= 70)
        .length;
    final attentionCount = data.accounts
        .where((account) => account.securityScore < 70)
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'GamerLocker',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          PlanBadge(accountCount: data.accounts.length),
          const SizedBox(width: 4),
          IconButton(
            tooltip: gl('Idioma'),
            onPressed: () {
              showGamerLockerLanguageDialog(context);
            },
            icon: const Icon(Icons.language_rounded),
          ),
          IconButton(
            tooltip: gl('Escolher fundo'),
            onPressed: chooseDashboardTheme,
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            tooltip: gl('Backup'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
            icon: const Icon(Icons.backup_outlined),
          ),
          IconButton(
            tooltip: gl('Bloquear cofre'),
            onPressed: lockVault,
            icon: const Icon(Icons.lock),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: dashboardTheme.gradient),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${data.name}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${data.accounts.length} conta${data.accounts.length == 1 ? '' : 's'} no seu GamerLocker.',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
              DashboardStats(
                total: data.accounts.length,
                favorites: favoriteCount,
                protected: protectedCount,
                attention: attentionCount,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: gl(
                          'Pesquisar nome, login, perfil Steam, patente...',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: gl('Limpar pesquisa'),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: importAccounts,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Importar contas'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: addAccount,
                    icon: const Icon(Icons.add),
                    label: const Text('Nova conta'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: data.accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 52,
                              color: Color(0xFF9A87FF),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Seu cofre ainda esta vazio.',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: addAccount,
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar primeira conta'),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: importAccounts,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Importar varias contas'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma conta encontrada para "$searchQuery".',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : SingleChildScrollView(
                        child: searchQuery.trim().isNotEmpty
                            ? buildSection(
                                'Resultados (${filtered.length})',
                                filtered,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildSection('★ Favoritas', favorites),
                                  buildSection('Todas as contas', others),
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardStats extends StatelessWidget {
  final int total;
  final int favorites;
  final int protected;
  final int attention;

  const DashboardStats({
    super.key,
    required this.total,
    required this.favorites,
    required this.protected,
    required this.attention,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 4
            : width >= 560
            ? 2
            : 1;

        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _DashboardStatCard(
              width: cardWidth,
              icon: Icons.inventory_2_outlined,
              label: 'Contas',
              value: total.toString(),
              accent: const Color(0xFF9A87FF),
            ),
            _DashboardStatCard(
              width: cardWidth,
              icon: Icons.star_rounded,
              label: 'Favoritas',
              value: favorites.toString(),
              accent: Colors.amberAccent,
            ),
            _DashboardStatCard(
              width: cardWidth,
              icon: Icons.verified_user_outlined,
              label: 'Protegidas',
              value: protected.toString(),
              accent: Colors.greenAccent,
            ),
            _DashboardStatCard(
              width: cardWidth,
              icon: Icons.shield_outlined,
              label: 'Atenção',
              value: attention.toString(),
              accent: attention > 0 ? Colors.orangeAccent : Colors.greenAccent,
            ),
          ],
        );
      },
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _DashboardStatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.10),
            const Color(0xFF151821).withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.23)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountOrderScreen extends StatefulWidget {
  final List<AccountEntry> accounts;

  const AccountOrderScreen({super.key, required this.accounts});

  @override
  State<AccountOrderScreen> createState() => _AccountOrderScreenState();
}

class _AccountOrderScreenState extends State<AccountOrderScreen> {
  late List<AccountEntry> ordered;

  @override
  void initState() {
    super.initState();
    ordered = [...widget.accounts];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizar contas'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ordered),
            icon: const Icon(Icons.check),
            label: const Text('Salvar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Arraste as contas para a ordem que quiser. Favoritas continuam aparecendo na secao de favoritas, respeitando esta ordem.',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: ordered.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex--;
                      }

                      final moved = ordered.removeAt(oldIndex);
                      ordered.insert(newIndex, moved);
                    });
                  },
                  itemBuilder: (context, index) {
                    final account = ordered[index];

                    return Card(
                      key: ValueKey(account),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(
                          account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          account.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (account.favorite)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.star,
                                  color: Colors.amberAccent,
                                  size: 20,
                                ),
                              ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexedAccount {
  final int index;
  final AccountEntry account;

  const _IndexedAccount({required this.index, required this.account});
}

class AccountCard extends StatefulWidget {
  final AccountEntry account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onOpenSteamProfile;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final int? dragIndex;

  const AccountCard({
    super.key,
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onOpenSteamProfile,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.dragIndex,
  });

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool hovered = false;

  AccountEntry get account => widget.account;

  MapEntry<String, String>? get levelEntry {
    for (final field in account.fields.entries) {
      final key = field.key
          .toLowerCase()
          .replaceAll('í', 'i')
          .replaceAll('é', 'e');

      if ((key == 'nivel' || key == 'level' || key == 'lv') &&
          field.value.trim().isNotEmpty) {
        return field;
      }
    }

    return null;
  }

  Color get levelColor {
    final level = levelEntry?.value.toUpperCase() ?? '';

    if (level.contains('LV1')) {
      return const Color(0xFF64B5F6);
    }

    if (level.contains('LV2')) {
      return const Color(0xFFBA68C8);
    }

    if (level.contains('LV3')) {
      return const Color(0xFFFFB74D);
    }

    if (level.contains('LV4')) {
      return const Color(0xFFFF7043);
    }

    if (level.contains('LV5')) {
      return const Color(0xFFE57373);
    }

    return const Color(0xFF9A87FF);
  }

  Color get securityColor {
    if (account.securityScore >= 70) {
      return Colors.greenAccent;
    }

    if (account.securityScore >= 40) {
      return Colors.amberAccent;
    }

    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final level = levelEntry;
    final collapsed = !widget.isExpanded;

    final dashboardFields = account.fields.entries.where((field) {
      if (!account.dashboardFields.contains(field.key)) {
        return false;
      }

      if (field.value.trim().isEmpty) {
        return false;
      }

      if (field.key.toLowerCase().contains('senha')) {
        return false;
      }

      if (level != null && field.key == level.key) {
        return false;
      }

      return true;
    }).toList();

    final login = account.fields['Login']?.trim() ?? '';
    final password = account.fields['Senha']?.trim() ?? '';

    final accent = account.favorite ? Colors.amberAccent : levelColor;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              blurRadius: hovered ? 24 : 14,
              spreadRadius: hovered ? 1 : 0,
              offset: const Offset(0, 8),
              color: accent.withValues(alpha: hovered ? 0.18 : 0.07),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(19),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: hovered ? 0.10 : 0.045),
                    const Color(0xFF151821),
                    const Color(0xFF12151D),
                  ],
                  stops: const [0, 0.38, 1],
                ),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: hovered
                      ? accent.withValues(alpha: 0.56)
                      : account.favorite
                      ? Colors.amberAccent.withValues(alpha: 0.42)
                      : const Color(0xFF292D38),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.20),
                            accent,
                            const Color(0xFF8A6BFF),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accent.withValues(alpha: 0.28),
                                      const Color(0xFF232735),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.20),
                                  ),
                                ),
                                child: account.type == 'Steam'
                                    ? SteamAccountAvatar(reference: account.steamProfileReference, login: login)
                                    : const Icon(Icons.videogame_asset, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            account.displayName,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (level != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: levelColor.withValues(
                                                alpha: 0.13,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: levelColor.withValues(
                                                  alpha: 0.38,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              level.value.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: levelColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      account.type,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: gl(
                                  account.favorite
                                      ? 'Remover dos favoritos'
                                      : 'Adicionar aos favoritos',
                                ),
                                onPressed: widget.onToggleFavorite,
                                icon: Icon(
                                  account.favorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: account.favorite
                                      ? Colors.amberAccent
                                      : Colors.grey.shade500,
                                ),
                              ),
                              if (widget.dragIndex != null && widget.isExpanded)
                                Tooltip(
                                  message: 'Arrastar para reorganizar',
                                  child: Draggable<int>(
                                    data: widget.dragIndex!,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF292D38),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF7E69E8),
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              blurRadius: 18,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.drag_indicator_rounded,
                                          color: Color(0xFFAA9BFF),
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: const Opacity(
                                      opacity: 0.30,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                        ),
                                      ),
                                    ),
                                    child: const MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: gl(
                                  collapsed
                                      ? 'Expandir conta'
                                      : 'Minimizar conta',
                                ),
                                onPressed: widget.onToggleExpanded,
                                icon: Icon(
                                  collapsed
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'open':
                                      widget.onTap();
                                      break;
                                    case 'edit':
                                      widget.onEdit();
                                      break;
                                    case 'profile':
                                      widget.onOpenSteamProfile?.call();
                                      break;
                                    case 'delete':
                                      widget.onDelete();
                                      break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Text('Abrir conta'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  if (widget.onOpenSteamProfile != null)
                                    const PopupMenuItem(
                                      value: 'profile',
                                      child: Text('Abrir perfil Steam'),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Excluir',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (collapsed) ...[
                            const SizedBox(height: 14),
                            if (login.isNotEmpty)
                              Row(
                                children: [
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(
                                      login,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 15,
                                  color: securityColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Segurança ${account.securityScore}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  account.securityScore >= 70
                                      ? 'Boa'
                                      : account.securityScore >= 40
                                      ? 'Atenção'
                                      : 'Baixa',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: securityColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: account.securityScore / 100,
                                minHeight: 5,
                                backgroundColor: const Color(0xFF252936),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  securityColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (login.isNotEmpty)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await copySecurely(login);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            duration: Duration(seconds: 2),
                                            content: Text(
                                              'Login copiado. Clipboard sera limpo em 30 segundos.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy, size: 15),
                                      label: const Text('Login'),
                                    ),
                                  ),
                                if (login.isNotEmpty && password.isNotEmpty)
                                  const SizedBox(width: 8),
                                if (password.isNotEmpty)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await copySecurely(password);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            duration: Duration(seconds: 2),
                                            content: Text(
                                              'Senha copiada. Clipboard sera limpo em 30 segundos.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.key_rounded, size: 15),
                                      label: const Text('Senha'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (!collapsed) ...[
                            if (account.type == 'Steam') ...[
                              const SizedBox(height: 14),
                              SteamProfileSummary(steamId: account.steamProfileReference),
                              const SizedBox(height: 10),
                              SteamCooldownSummary(account: account),
                            ],
                            if (dashboardFields.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ...dashboardFields.map(
                                (field) => Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          field.key,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          field.value,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 17,
                                  color: securityColor,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Segurança ${account.securityScore}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  account.securityScore >= 70
                                      ? 'Boa'
                                      : account.securityScore >= 40
                                      ? 'Atenção'
                                      : 'Baixa',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: securityColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: account.securityScore / 100,
                                minHeight: 6,
                                backgroundColor: const Color(0xFF252936),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  securityColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (login.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await copySecurely(login);

                                      if (!context.mounted) {
                                        return;
                                      }

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              duration: Duration(seconds: 2),
                                              content: Text(
                                                'Login copiado. Clipboard sera limpo em 30 segundos.',
                                              ),
                                            ),
                                          );
                                    },
                                    icon: const Icon(Icons.copy, size: 17),
                                    label: const Text('Login'),
                                  ),
                                if (password.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await copySecurely(password);

                                      if (!context.mounted) {
                                        return;
                                      }

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              duration: Duration(seconds: 2),
                                              content: Text(
                                                'Senha copiada. Clipboard sera limpo em 30 segundos.',
                                              ),
                                            ),
                                          );
                                    },
                                    icon: const Icon(
                                      Icons.key_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Senha'),
                                  ),
                                if (widget.onOpenSteamProfile != null)
                                  OutlinedButton.icon(
                                    onPressed: widget.onOpenSteamProfile,
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      size: 17,
                                    ),
                                    label: const Text('Perfil Steam'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class SteamCooldownSummary extends StatefulWidget {
  final AccountEntry account;

  const SteamCooldownSummary({super.key, required this.account});

  @override
  State<SteamCooldownSummary> createState() => _SteamCooldownSummaryState();
}

class _SteamCooldownSummaryState extends State<SteamCooldownSummary> {
  bool checking = false;
  SteamCooldownResult? result;

  String get login => widget.account.fields['Login']?.trim() ?? '';
  String get password => widget.account.fields['Senha'] ?? '';

  @override
  void initState() {
    super.initState();
    result = SteamCooldownService.cached(login);
  }

  Future<String?> _askGuardCode(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: hint),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.trim();
  }

  Future<void> _check() async {
    if (checking) return;

    setState(() => checking = true);

    var next = await SteamCooldownService.check(
      username: login,
      password: password,
      profileReference: widget.account.steamProfileReference,
    );

    if (!mounted) return;

    if (next.needsSteamGuard) {
      final mobile = next.guardType == 'mobile' || next.status == 'two_factor_required';
      final code = await _askGuardCode(
        'Steam Guard',
        mobile ? 'Codigo do autenticador' : 'Codigo recebido por e-mail',
      );

      if (code != null && code.isNotEmpty) {
        next = await SteamCooldownService.check(
          username: login,
          password: password,
          profileReference: widget.account.steamProfileReference,
          authCode: mobile ? null : code,
          twoFactorCode: mobile ? code : null,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      result = next;
      checking = false;
    });
  }

  String _durationLabel(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    parts.add('${minutes}min');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    final hasCredentials = login.isNotEmpty && password.isNotEmpty;

    Color statusColor = Colors.grey;
    IconData icon = Icons.sports_esports_outlined;
    String label = 'Cooldown CS2 nao verificado';

    if (current != null) {
      if (current.status == 'ok' && current.hasCooldown) {
        statusColor = Colors.orangeAccent;
        icon = Icons.timer_outlined;
        label = 'Cooldown ativo: ${_durationLabel(current.penaltySeconds)}';
      } else if (current.status == 'ok' && current.vacBanned) {
        statusColor = Colors.redAccent;
        icon = Icons.block;
        label = 'VAC sinalizado pelo GC';
      } else if (current.status == 'ok') {
        statusColor = Colors.greenAccent;
        icon = Icons.verified_outlined;
        label = 'Sem cooldown ativo';
      } else {
        statusColor = Colors.amberAccent;
        icon = Icons.info_outline;
        label = current.message ?? 'Nao foi possivel verificar o cooldown.';
      }
    } else if (!hasCredentials) {
      label = 'Adicione Login e Senha para verificar o cooldown.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (current?.status == 'ok' && current!.penaltyReason > 0)
                  Text(
                    'Motivo GC: ${current.penaltyReason}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                if (current?.status == 'ok') ...[
                  Text(current!.prime == null ? 'Prime: não confirmado'
                      : current.prime! ? 'Prime ativo' : 'Sem Prime',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  if (current.cs2Level != null && current.cs2Level! > 0)
                    Text('Nível CS2: ${current.cs2Level}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  Text('Competitivo: não confirmado', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
                if (current?.sessionWarning != null)
                  Text(
                    current!.sessionWarning!,
                    style: TextStyle(fontSize: 10, color: Colors.amber.shade300),
                  ),
                if (current?.groupMessage != null)
                  Text(
                    current!.groupMessage!,
                    style: TextStyle(
                      fontSize: 10,
                      color: current.groupStatus == 'failed'
                          ? Colors.amber.shade300
                          : Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: checking || !hasCredentials ? null : _check,
            icon: checking
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(checking ? 'Verificando' : 'Verificar'),
          ),
        ],
      ),
    );
  }
}

class SteamProfileSummary extends StatefulWidget {
  final String steamId;

  const SteamProfileSummary({super.key, required this.steamId});

  @override
  State<SteamProfileSummary> createState() => _SteamProfileSummaryState();
}

class _SteamProfileSummaryState extends State<SteamProfileSummary> {
  late Future<SteamPublicProfile?> profileFuture;
  Timer? retryTimer;
  int retries = 0;
  SteamPublicProfile? lastProfile;
  StreamSubscription<String>? profileSubscription;
  int photoRevision = 0;

  @override
  void initState() {
    super.initState();
    lastProfile = SteamProfileService.cachedProfile(widget.steamId);
    profileSubscription = SteamProfileService.changes.listen((reference) {
      if (!mounted || reference != widget.steamId.trim()) return;
      retryTimer?.cancel();
      retries = 0;
      photoRevision++;
      lastProfile = SteamProfileService.cachedProfile(reference);
      setState(() => _loadProfile());
    });
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant SteamProfileSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steamId != widget.steamId) {
      retryTimer?.cancel();
      retries = 0;
      photoRevision++;
      lastProfile = SteamProfileService.cachedProfile(widget.steamId);
      _loadProfile();
    }
  }

  void _loadProfile({bool forceRefresh = false}) {
    final requestedId = widget.steamId;
    profileFuture = SteamProfileService.fetchProfile(
      requestedId,
      forceRefresh: forceRefresh,
    );
    profileFuture.then((profile) {
      if (!mounted || widget.steamId != requestedId) return;
      if (profile != null) lastProfile = profile;
      if (profile == null || profile.avatarUrl.isEmpty) _scheduleRetry();
    });
  }

  void _scheduleRetry() {
    if (retries >= 3 || retryTimer?.isActive == true) return;
    retryTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      retries++;
      setState(() => _loadProfile(forceRefresh: true));
    });
  }

  @override
  void dispose() {
    retryTimer?.cancel();
    profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SteamPublicProfile?>(
      future: profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && lastProfile == null) {
          return Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 9),
              Text(
                'Carregando perfil Steam...',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          );
        }

        final profile = snapshot.connectionState == ConnectionState.done
            ? snapshot.data ?? lastProfile
            : lastProfile ?? snapshot.data;

        if (profile == null) {
          return Text(
            widget.steamId.startsWith('steam-login:')
                ? 'Clique em Verificar para identificar o perfil Steam.'
                : 'Perfil Steam vinculado',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          );
        }

        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: profile.avatarUrl.isEmpty
                  ? Container(
                      width: 34,
                      height: 34,
                      color: const Color(0xFF232735),
                      child: const Icon(Icons.person, size: 18),
                    )
                  : Image.network(
                      profile.avatarUrl,
                      key: ValueKey('${profile.avatarUrl}:$retries:$photoRevision'),
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        _scheduleRetry();
                        return Container(
                        width: 34,
                        height: 34,
                        color: const Color(0xFF232735),
                        child: const Icon(Icons.person, size: 18),
                        );
                      },
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    profile.statusLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: profile.isOnline
                          ? Colors.greenAccent
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class AccountDetailsScreen extends StatefulWidget {
  final AccountEntry account;
  final Future<void> Function(AccountEntry account) onChanged;

  const AccountDetailsScreen({
    super.key,
    required this.account,
    required this.onChanged,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late AccountEntry account;

  bool showPasswords = false;

  @override
  void initState() {
    super.initState();
    account = widget.account;
  }

  Future<void> edit() async {
    final updated = await Navigator.push<AccountEntry>(
      context,
      MaterialPageRoute(builder: (_) => AccountFormScreen(account: account)),
    );

    if (updated == null) {
      return;
    }

    setState(() {
      account = updated;
    });

    await widget.onChanged(updated);
  }

  Future<void> openSteamProfile() async {
    final opened = await SteamProfileService.openProfile(account.steamId);

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nao foi possivel abrir o perfil. Confira o Perfil Steam informado.',
        ),
      ),
    );
  }

  Widget securityItem(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 18,
            color: done ? Colors.greenAccent : Colors.amberAccent,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = account.fields['E-mail vinculado']?.trim() ?? '';
    final phone = account.fields['Telefone vinculado']?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(account.displayName),
        actions: [
          if (account.type == 'Steam') IconButton(
            tooltip: 'Dados Steam', icon: const Icon(Icons.sports_esports_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SteamAccountScreen(
              username: account.fields['Login'] ?? '', password: account.fields['Senha'] ?? '',
            ))),
          ),
          IconButton(
            tooltip: gl('Editar'),
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: gl(showPasswords ? 'Ocultar senhas' : 'Mostrar senhas'),
            onPressed: () {
              setState(() {
                showPasswords = !showPasswords;
              });
            },
            icon: Icon(showPasswords ? Icons.visibility_off : Icons.visibility),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF232735),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: account.type == 'Steam'
                          ? SteamAccountAvatar(reference: account.steamProfileReference,
                              login: account.fields['Login'] ?? '', size: 64, radius: 18)
                          : const Icon(Icons.videogame_asset, size: 32),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.displayName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            account.type,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (account.hasSteamProfile)
                      OutlinedButton.icon(
                        onPressed: openSteamProfile,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir perfil Steam'),
                      ),
                  ],
                ),
                if (account.type == 'Steam') ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151821),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF292D38)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SteamProfileSummary(steamId: account.steamProfileReference),
                        const SizedBox(height: 10),
                        SteamCooldownSummary(account: account),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF292D38)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF9A87FF),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Segurança ${account.securityScore}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: account.securityScore / 100,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      const SizedBox(height: 16),
                      securityItem('E-mail vinculado', email.isNotEmpty),
                      securityItem('Telefone vinculado', phone.isNotEmpty),
                      securityItem(
                        '2FA / autenticador ativo',
                        account.security['twoFactor'] == true,
                      ),
                      securityItem(
                        'Recovery Code salvo',
                        account.security['recoveryCode'] == true,
                      ),
                      securityItem(
                        'Backup Codes salvos',
                        account.security['backupCodes'] == true,
                      ),
                      securityItem(
                        'E-mail verificado',
                        account.security['emailVerified'] == true,
                      ),
                      securityItem(
                        'Telefone verificado',
                        account.security['phoneVerified'] == true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ...account.fields.entries.map((field) {
                  final isPassword = field.key.toLowerCase().contains('senha');
                  final empty = field.value.trim().isEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151821),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            field.key,
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            empty
                                ? 'Não informado'
                                : isPassword && !showPasswords
                                ? '••••••••••••'
                                : field.value,
                            style: TextStyle(
                              color: empty ? Colors.grey.shade600 : null,
                            ),
                          ),
                        ),
                        if (!empty)
                          IconButton(
                            tooltip: gl('Copiar'),
                            onPressed: () async {
                              await copySecurely(field.value);

                              if (!context.mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 2),
                                  content: Text(
                                    '${field.key} copiado. Clipboard será limpo em 30 segundos.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 19),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomFieldController {
  final TextEditingController nameController;
  final TextEditingController valueController;
  bool showOnDashboard;

  CustomFieldController({
    String name = '',
    String value = '',
    this.showOnDashboard = false,
  }) : nameController = TextEditingController(text: name),
       valueController = TextEditingController(text: value);

  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
}

class AccountFormScreen extends StatefulWidget {
  final AccountEntry? account;

  const AccountFormScreen({super.key, this.account});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  late String accountType;
  late Set<String> dashboardFields;

  final accountNameController = TextEditingController();
  final serviceController = TextEditingController();
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  final steamIdController = TextEditingController();
  final profileNameController = TextEditingController();
  final premierController = TextEditingController();
  final faceitController = TextEditingController();
  final linkedEmailController = TextEditingController();
  final linkedEmailPasswordController = TextEditingController();
  final linkedPhoneController = TextEditingController();

  final List<CustomFieldController> customFields = [];

  bool? prime;
  bool showPassword = false;
  bool showEmailPassword = false;

  bool twoFactor = false;
  bool recoveryCode = false;
  bool backupCodes = false;
  bool emailVerified = false;
  bool phoneVerified = false;

  bool get editing => widget.account != null;

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    if (account == null) {
      accountType = 'Steam';
      dashboardFields = {...AccountEntry.defaultDashboardFields};
      return;
    }

    accountType = account.type == 'Steam' ? 'Steam' : 'Custom';
    dashboardFields = {...account.dashboardFields};

    if (dashboardFields.remove('SteamID')) {
      dashboardFields.add('Perfil Steam');
    }

    accountNameController.text = account.name;
    loginController.text = account.fields['Login'] ?? '';
    passwordController.text = account.fields['Senha'] ?? '';
    linkedEmailController.text = account.fields['E-mail vinculado'] ?? '';
    linkedEmailPasswordController.text =
        account.fields['Senha do e-mail'] ?? '';
    linkedPhoneController.text = account.fields['Telefone vinculado'] ?? '';

    twoFactor = account.security['twoFactor'] == true;
    recoveryCode = account.security['recoveryCode'] == true;
    backupCodes = account.security['backupCodes'] == true;
    emailVerified = account.security['emailVerified'] == true;
    phoneVerified = account.security['phoneVerified'] == true;

    if (accountType == 'Steam') {
      steamIdController.text =
          account.fields['Perfil Steam'] ?? account.fields['SteamID'] ?? '';
      profileNameController.text = account.fields['Nome no perfil'] ?? '';
      premierController.text = account.fields['Premier Rating'] ?? '';
      faceitController.text = account.fields['FACEIT'] ?? '';

      switch (account.fields['Prime']) {
        case 'Sim':
          prime = true;
          break;
        case 'Não':
          prime = false;
          break;
      }
    } else {
      serviceController.text = account.fields['Jogo / serviço'] ?? account.type;
    }

    const standard = {
      'Login',
      'Senha',
      'SteamID',
      'Perfil Steam',
      'Nome no perfil',
      'Prime',
      'Premier Rating',
      'FACEIT',
      'Jogo / serviço',
      'E-mail vinculado',
      'Senha do e-mail',
      'Telefone vinculado',
    };

    for (final field in account.fields.entries) {
      if (!standard.contains(field.key)) {
        customFields.add(
          CustomFieldController(
            name: field.key,
            value: field.value,
            showOnDashboard: account.dashboardFields.contains(field.key),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    accountNameController.dispose();
    serviceController.dispose();
    loginController.dispose();
    passwordController.dispose();
    steamIdController.dispose();
    profileNameController.dispose();
    premierController.dispose();
    faceitController.dispose();
    linkedEmailController.dispose();
    linkedEmailPasswordController.dispose();
    linkedPhoneController.dispose();

    for (final field in customFields) {
      field.dispose();
    }

    super.dispose();
  }

  void setDashboardField(String field, bool enabled) {
    setState(() {
      if (enabled) {
        dashboardFields.add(field);
      } else {
        dashboardFields.remove(field);
      }
    });
  }

  Widget dashboardToggle(String field) {
    return CheckboxListTile(
      value: dashboardFields.contains(field),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Mostrar no dashboard', style: TextStyle(fontSize: 13)),
      onChanged: (value) {
        setDashboardField(field, value == true);
      },
    );
  }

  void addCustomField() {
    setState(() {
      customFields.add(CustomFieldController());
    });
  }

  void removeCustomField(int index) {
    customFields[index].dispose();

    setState(() {
      customFields.removeAt(index);
    });
  }

  void save() {
    final accountName = accountNameController.text.trim();

    final login = loginController.text.trim();

    if (accountName.isEmpty && login.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos um nome ou login para a conta.'),
        ),
      );
      return;
    }

    final fields = <String, String>{
      'Login': login,
      'Senha': passwordController.text,
      'E-mail vinculado': linkedEmailController.text.trim(),
      'Senha do e-mail': linkedEmailPasswordController.text,
      'Telefone vinculado': linkedPhoneController.text.trim(),
    };

    if (accountType == 'Steam') {
      fields.addAll({
        'Premier Rating': formatPremierRating(premierController.text),
        'Prime': prime == null
            ? ''
            : prime!
            ? 'Sim'
            : 'Não',
        'Perfil Steam': steamIdController.text.trim(),
        'Nome no perfil': profileNameController.text.trim(),
        'FACEIT': faceitController.text.trim(),
      });
    } else {
      fields['Jogo / serviço'] = serviceController.text.trim();
    }

    final savedDashboardFields = <String>{...dashboardFields};

    for (final custom in customFields) {
      final name = custom.nameController.text.trim();
      final value = custom.valueController.text.trim();

      if (name.isNotEmpty) {
        fields[name] = value;

        if (custom.showOnDashboard) {
          savedDashboardFields.add(name);
        } else {
          savedDashboardFields.remove(name);
        }
      }
    }

    savedDashboardFields.removeWhere(
      (field) => field.toLowerCase().contains('senha'),
    );

    Navigator.pop(
      context,
      AccountEntry(
        name: accountName,
        type: accountType == 'Steam'
            ? 'Steam'
            : serviceController.text.trim().isEmpty
            ? 'Outro jogo / serviço'
            : serviceController.text.trim(),
        fields: fields,
        favorite: widget.account?.favorite ?? false,
        dashboardFields: savedDashboardFields,
        security: {
          'twoFactor': twoFactor,
          'recoveryCode': recoveryCode,
          'backupCodes': backupCodes,
          'emailVerified': emailVerified,
          'phoneVerified': phoneVerified,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar conta' : 'Adicionar conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tipo da conta',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Steam',
                      icon: Icon(Icons.sports_esports),
                      label: Text('Steam'),
                    ),
                    ButtonSegment(
                      value: 'Custom',
                      icon: Icon(Icons.extension_outlined),
                      label: Text('Outro jogo / serviço'),
                    ),
                  ],
                  selected: {accountType},
                  onSelectionChanged: (value) {
                    setState(() {
                      accountType = value.first;
                    });
                  },
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: accountNameController,
                  decoration: InputDecoration(
                    labelText: gl('Nome para identificar a conta (opcional)'),
                    hintText: gl('Ex.: Main, Smurf... ou deixe vazio'),
                  ),
                ),
                const SizedBox(height: 16),
                if (accountType == 'Custom') ...[
                  TextField(
                    controller: serviceController,
                    decoration: InputDecoration(
                      labelText: gl('Jogo / serviço'),
                      hintText: gl('Ex.: Valorant, Riot, Epic...'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: loginController,
                  decoration: InputDecoration(
                    labelText: gl('Login'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                dashboardToggle('Login'),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: gl('Senha'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                if (accountType == 'Steam') ...[
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 18),
                  const Text(
                    'Campos Steam',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Todos são opcionais. Cole o link do perfil Steam para abrir e carregar dados públicos quando disponíveis.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: steamIdController,
                    decoration: InputDecoration(
                      labelText: gl('Perfil Steam'),
                      hintText: gl(
                        'https://steamcommunity.com/profiles/... ou /id/...',
                      ),
                    ),
                  ),
                  dashboardToggle('Perfil Steam'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: profileNameController,
                    decoration: InputDecoration(
                      labelText: gl('Nome no perfil'),
                    ),
                  ),
                  dashboardToggle('Nome no perfil'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: premierController,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: InputDecoration(
                      labelText: gl('Premier Rating'),
                      hintText: gl('Ex.: 13K, 15K, 20K'),
                    ),
                  ),
                  dashboardToggle('Premier Rating'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<bool?>(
                    initialValue: prime,
                    decoration: InputDecoration(labelText: gl('Prime')),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Não informado'),
                      ),
                      DropdownMenuItem(value: true, child: Text('Sim')),
                      DropdownMenuItem(value: false, child: Text('Não')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        prime = value;
                      });
                    },
                  ),
                  dashboardToggle('Prime'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: faceitController,
                    decoration: InputDecoration(labelText: gl('FACEIT')),
                  ),
                  dashboardToggle('FACEIT'),
                ],
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 18),
                const Text(
                  'Segurança e recuperação',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'O score é um checklist de preparação e não garante que a conta não será comprometida.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: linkedEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: gl('E-mail vinculado'),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                dashboardToggle('E-mail vinculado'),
                const SizedBox(height: 8),
                TextField(
                  controller: linkedEmailPasswordController,
                  obscureText: !showEmailPassword,
                  decoration: InputDecoration(
                    labelText: gl('Senha do e-mail (opcional)'),
                    prefixIcon: const Icon(Icons.password_outlined),
                    suffixIcon: IconButton(
                      tooltip: gl(
                        showEmailPassword
                            ? 'Ocultar senha do e-mail'
                            : 'Mostrar senha do e-mail',
                      ),
                      onPressed: () {
                        setState(() {
                          showEmailPassword = !showEmailPassword;
                        });
                      },
                      icon: Icon(
                        showEmailPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: linkedPhoneController,
                  decoration: InputDecoration(
                    labelText: gl('Telefone vinculado'),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                dashboardToggle('Telefone vinculado'),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: twoFactor,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('2FA / autenticador ativo'),
                  onChanged: (value) {
                    setState(() {
                      twoFactor = value;
                    });
                  },
                ),
                SwitchListTile(
                  value: recoveryCode,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recovery Code salvo'),
                  onChanged: (value) {
                    setState(() {
                      recoveryCode = value;
                    });
                  },
                ),
                SwitchListTile(
                  value: backupCodes,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Backup Codes salvos'),
                  onChanged: (value) {
                    setState(() {
                      backupCodes = value;
                    });
                  },
                ),
                SwitchListTile(
                  value: emailVerified,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('E-mail verificado'),
                  onChanged: (value) {
                    setState(() {
                      emailVerified = value;
                    });
                  },
                ),
                SwitchListTile(
                  value: phoneVerified,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Telefone verificado'),
                  onChanged: (value) {
                    setState(() {
                      phoneVerified = value;
                    });
                  },
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Campos personalizados',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: addCustomField,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar campo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Você pode adicionar patente, mapa, e-mail, região, observação ou qualquer informação.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                ...List.generate(customFields.length, (index) {
                  final field = customFields[index];

                  return Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151821),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF292D38)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: field.nameController,
                                decoration: InputDecoration(
                                  labelText: gl('Nome do campo'),
                                  hintText: gl('Ex.: Patente Mirage'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: field.valueController,
                                decoration: InputDecoration(
                                  labelText: gl('Valor'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: gl('Remover campo'),
                              onPressed: () {
                                removeCustomField(index);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        CheckboxListTile(
                          value: field.showOnDashboard,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Mostrar este campo no dashboard',
                            style: TextStyle(fontSize: 13),
                          ),
                          onChanged: (value) {
                            setState(() {
                              field.showOnDashboard = value == true;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      editing ? 'Salvar alterações' : 'Adicionar conta',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BulkImportScreen extends StatefulWidget {
  final List<AccountEntry> existingAccounts;

  const BulkImportScreen({super.key, required this.existingAccounts});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final textController = TextEditingController();
  final serviceController = TextEditingController();

  String accountType = 'Steam';
  List<_ImportPreviewItem> preview = [];

  @override
  void dispose() {
    textController.dispose();
    serviceController.dispose();
    super.dispose();
  }

  int get availableSlots {
    if (PlanService.current.value.isPro) {
      return 1000000;
    }

    final remaining =
        PlanService.freeAccountLimit - widget.existingAccounts.length;

    return remaining < 0 ? 0 : remaining;
  }

  String get resolvedType {
    if (accountType == 'Steam') {
      return 'Steam';
    }

    final service = serviceController.text.trim();

    return service.isEmpty ? 'Outro jogo / servico' : service;
  }

  void analyze() {
    final parsed = _parseAccounts(textController.text);

    final existingLogins = widget.existingAccounts
        .map((account) => (account.fields['Login'] ?? '').trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet();

    final batchLogins = <String>{};
    var remaining = availableSlots;

    final result = <_ImportPreviewItem>[];

    for (final parsedAccount in parsed) {
      final login = parsedAccount.login.trim().toLowerCase();

      final duplicate =
          login.isEmpty ||
          existingLogins.contains(login) ||
          batchLogins.contains(login);

      if (login.isNotEmpty) {
        batchLogins.add(login);
      }

      final canSelect = !duplicate && remaining > 0;

      if (canSelect && !PlanService.current.value.isPro) {
        remaining--;
      }

      result.add(
        _ImportPreviewItem(
          name: parsedAccount.name,
          login: parsedAccount.login,
          password: parsedAccount.password,
          level: parsedAccount.level,
          accountAge: parsedAccount.accountAge,
          steamProfile: parsedAccount.steamProfile,
          duplicate: duplicate,
          selected: canSelect,
        ),
      );
    }

    setState(() {
      preview = result;
    });
  }

  bool _isLevelToken(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );

    return RegExp(
      r'^(?:LVL|LV|LEVEL|NIVEL|L)[_:#-]?\d+[A-Z0-9._-]*$',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  bool _isBareLevelNumber(String value) {
    final number = int.tryParse(value.trim());

    return number != null && number >= 0 && number <= 999;
  }

  String _normalizeLevel(String value) {
    return value.trim().toUpperCase();
  }

  bool _isAccountAgeToken(String value) {
    final normalized = value.trim().toLowerCase();

    return RegExp(
      r'^\d{1,3}\s*(?:anos?|ano|years?|yrs?|year|meses?|m[eê]s|months?)$',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  String _normalizeAccountAge(String value) {
    return value.trim();
  }

  bool _isSteamProfileToken(String value) {
    var raw = value.trim();

    if (!raw.contains('://') &&
        raw.toLowerCase().startsWith('steamcommunity.com/')) {
      raw = 'https://$raw';
    }

    final uri = Uri.tryParse(raw);

    if (uri == null || !uri.hasScheme) {
      return false;
    }

    final host = uri.host.toLowerCase();

    if (host != 'steamcommunity.com' && host != 'www.steamcommunity.com') {
      return false;
    }

    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();

    return segments.length >= 2 &&
        (segments.first.toLowerCase() == 'profiles' ||
            segments.first.toLowerCase() == 'id');
  }

  String _normalizeSteamProfile(String value) {
    var raw = value.trim();

    if (!raw.contains('://') &&
        raw.toLowerCase().startsWith('steamcommunity.com/')) {
      raw = 'https://$raw';
    }

    final uri = Uri.tryParse(raw);

    if (uri == null) {
      return value.trim();
    }

    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();

    if (segments.length < 2) {
      return value.trim();
    }

    final profileType = segments.first.toLowerCase();
    final profileValue = segments[1].replaceAll(RegExp(r'[,;]+$'), '');

    return Uri(
      scheme: 'https',
      host: 'steamcommunity.com',
      pathSegments: [profileType, profileValue],
    ).toString();
  }

  String _normalizeImportLabel(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[\s_-]+'), '');
  }

  String? _importFieldForLabel(String value) {
    switch (_normalizeImportLabel(value)) {
      case 'login':
      case 'user':
      case 'usuario':
      case 'conta':
      case 'username':
        return 'login';
      case 'senha':
      case 'password':
      case 'pass':
      case 'pwd':
        return 'password';
      case 'nome':
      case 'name':
      case 'apelido':
        return 'name';
      case 'nivel':
      case 'level':
      case 'lvl':
      case 'lv':
        return 'level';
      case 'idade':
      case 'age':
      case 'idadedaconta':
      case 'accountage':
        return 'age';
      case 'perfil':
      case 'profile':
      case 'perfilsteam':
      case 'steamprofile':
      case 'steamurl':
      case 'urlsteam':
      case 'steamid':
      case 'steamid64':
        return 'profile';
    }

    return null;
  }

  List<_ParsedCredentials> _parseAccounts(String rawText) {
    final lines = rawText.replaceAll('\r', '').split('\n');
    final result = <_ParsedCredentials>[];

    String pendingName = '';
    String pendingLogin = '';
    String pendingPassword = '';
    String pendingLevel = '';
    String pendingAge = '';
    String pendingSteamProfile = '';

    String? headerDelimiter;
    List<String?>? headerFields;

    void addCredential({
      String name = '',
      required String login,
      required String password,
      String level = '',
      String accountAge = '',
      String steamProfile = '',
    }) {
      final cleanLogin = login.trim();
      final cleanPassword = password.trim();

      if (cleanLogin.isEmpty || cleanPassword.isEmpty) {
        return;
      }

      result.add(
        _ParsedCredentials(
          name: name.trim(),
          login: cleanLogin,
          password: cleanPassword,
          level: level.trim().isEmpty ? '' : _normalizeLevel(level),
          accountAge: accountAge.trim().isEmpty
              ? ''
              : _normalizeAccountAge(accountAge),
          steamProfile: steamProfile.trim().isEmpty
              ? ''
              : _normalizeSteamProfile(steamProfile),
        ),
      );
    }

    void flushPending() {
      if (pendingLogin.trim().isNotEmpty && pendingPassword.trim().isNotEmpty) {
        addCredential(
          name: pendingName,
          login: pendingLogin,
          password: pendingPassword,
          level: pendingLevel,
          accountAge: pendingAge,
          steamProfile: pendingSteamProfile,
        );
      }

      pendingName = '';
      pendingLogin = '';
      pendingPassword = '';
      pendingLevel = '';
      pendingAge = '';
      pendingSteamProfile = '';
    }

    bool tryHeader(String line, String delimiter) {
      final rawParts = line
          .split(delimiter)
          .map((item) => item.trim())
          .toList();
      final nonEmpty = rawParts.where((item) => item.isNotEmpty).toList();

      if (nonEmpty.length < 2) {
        return false;
      }

      final mapped = rawParts
          .map((item) => item.isEmpty ? null : _importFieldForLabel(item))
          .toList();

      final recognized = mapped.whereType<String>().toSet();

      if (!recognized.contains('login') ||
          !recognized.contains('password') ||
          mapped.where((item) => item == null).length >
              rawParts.where((item) => item.isEmpty).length) {
        return false;
      }

      headerDelimiter = delimiter;
      headerFields = mapped;
      return true;
    }

    bool parseWithHeader(String line, String delimiter) {
      if (headerDelimiter != delimiter || headerFields == null) {
        return false;
      }

      final parts = line.split(delimiter).map((item) => item.trim()).toList();

      String name = '';
      String login = '';
      String password = '';
      String level = '';
      String age = '';
      String profile = '';

      for (var index = 0; index < headerFields!.length; index++) {
        if (index >= parts.length) {
          break;
        }

        final value = parts[index].trim();

        if (value.isEmpty) {
          continue;
        }

        switch (headerFields![index]) {
          case 'name':
            name = value;
            break;
          case 'login':
            login = value;
            break;
          case 'password':
            password = value;
            break;
          case 'level':
            level = value;
            break;
          case 'age':
            age = value;
            break;
          case 'profile':
            profile = value;
            break;
        }
      }

      if (login.isEmpty || password.isEmpty) {
        return false;
      }

      addCredential(
        name: name,
        login: login,
        password: password,
        level: level,
        accountAge: age,
        steamProfile: profile,
      );

      return true;
    }

    bool parseSeparated(String line, String delimiter) {
      if (tryHeader(line, delimiter)) {
        return true;
      }

      if (parseWithHeader(line, delimiter)) {
        return true;
      }

      final rawParts = line
          .split(delimiter)
          .map((item) => item.trim())
          .toList();
      final parts = rawParts.where((item) => item.isNotEmpty).toList();

      if (parts.length < 2) {
        return false;
      }

      String level = '';
      String age = '';
      String profile = '';
      final ordinary = <String>[];

      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];

        if (profile.isEmpty && _isSteamProfileToken(part)) {
          profile = part;
          continue;
        }

        if (age.isEmpty && _isAccountAgeToken(part)) {
          age = part;
          continue;
        }

        if (level.isEmpty && _isLevelToken(part)) {
          level = part;
          continue;
        }

        // Em listas TAB, um numero isolado na terceira coluna costuma ser LVL.
        if (delimiter == '\t' &&
            level.isEmpty &&
            index >= 2 &&
            _isBareLevelNumber(part)) {
          level = part;
          continue;
        }

        ordinary.add(part);
      }

      if (ordinary.length < 2) {
        return false;
      }

      if (delimiter == '\t') {
        if (ordinary.length == 2) {
          addCredential(
            login: ordinary[0],
            password: ordinary[1],
            level: level,
            accountAge: age,
            steamProfile: profile,
          );
          return true;
        }

        addCredential(
          name: ordinary[0],
          login: ordinary[1],
          password: ordinary.sublist(2).join(delimiter),
          level: level,
          accountAge: age,
          steamProfile: profile,
        );
        return true;
      }

      if (level.isNotEmpty || age.isNotEmpty || profile.isNotEmpty) {
        if (ordinary.length == 2) {
          addCredential(
            login: ordinary[0],
            password: ordinary[1],
            level: level,
            accountAge: age,
            steamProfile: profile,
          );
          return true;
        }

        addCredential(
          name: ordinary[0],
          login: ordinary[1],
          password: ordinary.sublist(2).join(delimiter),
          level: level,
          accountAge: age,
          steamProfile: profile,
        );
        return true;
      }

      if (parts.length == 2) {
        addCredential(login: parts[0], password: parts[1]);
        return true;
      }

      addCredential(
        name: parts[0],
        login: parts[1],
        password: parts.sublist(2).join(delimiter),
      );

      return true;
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        flushPending();
        continue;
      }

      final inlineLabelPattern = RegExp(
        r'(login|user|usuario|conta|username|senha|password|pass|pwd|nome|name|apelido|nivel|level|lvl|lv|idade\s+da\s+conta|account\s+age|idade|age|perfil\s+steam|steam\s+profile|steamurl|urlsteam|steamid64|steamid|perfil|profile)\s*[:=]\s*(.*?)(?=\s+(?:login|user|usuario|conta|username|senha|password|pass|pwd|nome|name|apelido|nivel|level|lvl|lv|idade\s+da\s+conta|account\s+age|idade|age|perfil\s+steam|steam\s+profile|steamurl|urlsteam|steamid64|steamid|perfil|profile)\s*[:=]|$)',
        caseSensitive: false,
      );

      final inlineMatches = inlineLabelPattern.allMatches(line).toList();

      if (inlineMatches.length >= 2) {
        String name = '';
        String login = '';
        String password = '';
        String level = '';
        String age = '';
        String profile = '';

        for (final match in inlineMatches) {
          final field = _importFieldForLabel(match.group(1) ?? '');
          final value = match.group(2)!.trim();

          switch (field) {
            case 'password':
              password = value;
              break;
            case 'name':
              name = value;
              break;
            case 'level':
              level = value;
              break;
            case 'age':
              age = value;
              break;
            case 'profile':
              profile = value;
              break;
            case 'login':
              login = value;
              break;
          }
        }

        if (login.isNotEmpty && password.isNotEmpty) {
          addCredential(
            name: name,
            login: login,
            password: password,
            level: level,
            accountAge: age,
            steamProfile: profile,
          );
          continue;
        }
      }

      final labelMatch = RegExp(
        r'^(login|user|usuario|conta|username|senha|password|pass|pwd|nome|name|apelido|nivel|level|lvl|lv|idade\s+da\s+conta|account\s+age|idade|age|perfil\s+steam|steam\s+profile|steamurl|urlsteam|steamid64|steamid|perfil|profile)\s*[:=]\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);

      if (labelMatch != null) {
        final field = _importFieldForLabel(labelMatch.group(1) ?? '');
        final value = labelMatch.group(2)!.trim();

        if (field == 'login' &&
            pendingLogin.isNotEmpty &&
            pendingPassword.isNotEmpty) {
          flushPending();
        }

        switch (field) {
          case 'password':
            pendingPassword = value;
            break;
          case 'name':
            pendingName = value;
            break;
          case 'level':
            pendingLevel = value;
            break;
          case 'age':
            pendingAge = value;
            break;
          case 'profile':
            pendingSteamProfile = value;
            break;
          case 'login':
            pendingLogin = value;
            break;
        }

        continue;
      }

      var parsed = false;

      for (final delimiter in ['\t', '|', ';', ',']) {
        if (line.contains(delimiter)) {
          parsed = parseSeparated(line, delimiter);

          if (parsed) {
            break;
          }
        }
      }

      if (parsed) {
        continue;
      }

      final lowerLine = line.toLowerCase();

      if (!lowerLine.startsWith('http://') &&
          !lowerLine.startsWith('https://') &&
          !line.contains('://') &&
          line.contains(':')) {
        final colonParts = line.split(':').map((item) => item.trim()).toList();

        if (colonParts.length >= 3 && _isLevelToken(colonParts.last)) {
          if (colonParts.length == 3) {
            addCredential(
              login: colonParts[0],
              password: colonParts[1],
              level: colonParts[2],
            );
          } else {
            addCredential(
              name: colonParts[0],
              login: colonParts[1],
              password: colonParts.sublist(2, colonParts.length - 1).join(':'),
              level: colonParts.last,
            );
          }

          continue;
        }

        final colon = line.indexOf(':');

        if (colon > 0) {
          addCredential(
            login: line.substring(0, colon).trim(),
            password: line.substring(colon + 1).trim(),
          );

          continue;
        }
      }

      if (line.contains('-') && !line.contains('://')) {
        final hyphenParts = line
            .split('-')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();

        if (hyphenParts.length >= 3 && _isLevelToken(hyphenParts.last)) {
          addCredential(
            login: hyphenParts.first,
            password: hyphenParts.sublist(1, hyphenParts.length - 1).join('-'),
            level: hyphenParts.last,
          );

          continue;
        }

        if (hyphenParts.length == 2) {
          addCredential(login: hyphenParts[0], password: hyphenParts[1]);

          continue;
        }
      }

      var workingLine = line;
      String profile = '';
      String age = '';
      String level = '';

      final profileMatch = RegExp(
        r'(?:https?://)?(?:www\.)?steamcommunity\.com/(?:profiles|id)/[^\s]+',
        caseSensitive: false,
      ).firstMatch(workingLine);

      if (profileMatch != null) {
        profile = profileMatch.group(0) ?? '';
        workingLine = workingLine.replaceRange(
          profileMatch.start,
          profileMatch.end,
          ' ',
        );
      }

      final ageMatch = RegExp(
        r'\b\d{1,3}\s*(?:anos?|years?|yrs?|meses?|months?)\b',
        caseSensitive: false,
      ).firstMatch(workingLine);

      if (ageMatch != null) {
        age = ageMatch.group(0) ?? '';
        workingLine = workingLine.replaceRange(
          ageMatch.start,
          ageMatch.end,
          ' ',
        );
      }

      final levelMatch = RegExp(
        r'\b(?:LVL|LV|LEVEL|NIVEL|L)\s*[_:#-]?\s*\d+[A-Z0-9._-]*\b',
        caseSensitive: false,
      ).firstMatch(workingLine);

      if (levelMatch != null) {
        level = levelMatch.group(0) ?? '';
        workingLine = workingLine.replaceRange(
          levelMatch.start,
          levelMatch.end,
          ' ',
        );
      }

      final whitespaceParts = workingLine
          .split(RegExp(r'\s+'))
          .where((item) => item.isNotEmpty)
          .toList();

      if (whitespaceParts.length >= 2) {
        addCredential(
          login: whitespaceParts.first,
          password: whitespaceParts.sublist(1).join(' '),
          level: level,
          accountAge: age,
          steamProfile: profile,
        );
      }
    }

    flushPending();

    return result;
  }

  void toggleSelection(int index, bool selected) {
    if (!selected) {
      setState(() {
        preview[index].selected = false;
      });

      return;
    }

    if (preview[index].duplicate) {
      return;
    }

    final selectedCount = preview.where((item) => item.selected).length;

    if (!PlanService.current.value.isPro && selectedCount >= availableSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            availableSlots == 0
                ? 'Seu plano FREE nao possui vagas disponiveis.'
                : 'Seu plano FREE permite importar no maximo $availableSlots conta${availableSlots == 1 ? '' : 's'} agora.',
          ),
        ),
      );

      return;
    }

    setState(() {
      preview[index].selected = true;
    });
  }

  void importSelected() {
    final selected = preview.where((item) => item.selected).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma conta selecionada para importar.'),
        ),
      );

      return;
    }

    final accounts = selected.map((item) {
      final fields = <String, String>{
        'Login': item.login,
        'Senha': item.password,
      };

      if (item.level.trim().isNotEmpty) {
        fields['N\u00EDvel'] = item.level.trim();
      }

      if (item.accountAge.trim().isNotEmpty) {
        fields['Idade da conta'] = item.accountAge.trim();
      }

      if (accountType == 'Steam') {
        fields.addAll({
          'Premier Rating': '',
          'Prime': '',
          'Perfil Steam': item.steamProfile.trim(),
          'Nome no perfil': '',
          'FACEIT': '',
          'E-mail vinculado': '',
          'Telefone vinculado': '',
        });
      } else {
        fields.addAll({
          'Jogo / servico': serviceController.text.trim(),
          'E-mail vinculado': '',
          'Telefone vinculado': '',
        });
      }

      final dashboardFields = <String>{'Login'};

      if (item.level.trim().isNotEmpty) {
        dashboardFields.add('N\u00EDvel');
      }

      if (item.accountAge.trim().isNotEmpty) {
        dashboardFields.add('Idade da conta');
      }

      return AccountEntry(
        name: item.name.trim(),
        type: resolvedType,
        fields: fields,
        dashboardFields: dashboardFields,
      );
    }).toList();

    Navigator.pop(context, accounts);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = preview.where((item) => item.selected).length;

    final duplicates = preview.where((item) => item.duplicate).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar contas em massa')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1350),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Importador inteligente local',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'O GamerLocker reconhece TAB, |, ;, virgula, rotulos, nivel, idade da conta e links de perfil Steam. Revise a previa antes de importar. Login e senha permanecem neste computador.',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Steam',
                            icon: Icon(Icons.sports_esports),
                            label: Text('Steam'),
                          ),
                          ButtonSegment(
                            value: 'Custom',
                            icon: Icon(Icons.extension_outlined),
                            label: Text('Outro'),
                          ),
                        ],
                        selected: {accountType},
                        onSelectionChanged: (value) {
                          setState(() {
                            accountType = value.first;
                          });
                        },
                      ),
                    ),
                    if (accountType == 'Custom') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: serviceController,
                          decoration: InputDecoration(
                            labelText: gl('Jogo / servico'),
                            hintText: gl('Ex.: Epic, Riot, Valorant...'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: textController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: gl('Cole suas contas'),
                      alignLabelWithHint: true,
                      hintText: gl(
                        'login-senha-LV2\nlogin|senha|LV1\nlogin:senha\nlogin<TAB>senha<TAB>6 anos<TAB>https://steamcommunity.com/profiles/...\n\nou\nLogin: conta01\nSenha: senha123\nNivel: LV2\nPerfil Steam: https://steamcommunity.com/id/...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: analyze,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Analisar'),
                    ),
                    const SizedBox(width: 12),
                    if (!PlanService.current.value.isPro)
                      Text(
                        'FREE: ${widget.existingAccounts.length}/${PlanService.freeAccountLimit} contas',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    const Spacer(),
                    if (preview.isNotEmpty)
                      Text(
                        '${preview.length} detectadas • $duplicates duplicadas',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (preview.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Nome opcional',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Senha',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Nivel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Idade da conta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Perfil Steam',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 115,
                          child: Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Expanded(
                  flex: 3,
                  child: preview.isEmpty
                      ? Center(
                          child: Text(
                            'Cole o texto e clique em Analisar.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.separated(
                          itemCount: preview.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = preview[index];

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF151821),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: item.duplicate
                                      ? Colors.redAccent.withValues(alpha: 0.4)
                                      : const Color(0xFF292D38),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: item.selected,
                                    onChanged: item.duplicate
                                        ? null
                                        : (value) {
                                            toggleSelection(
                                              index,
                                              value == true,
                                            );
                                          },
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.name,
                                      onChanged: (value) {
                                        item.name = value;
                                      },
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: gl('Nome (opcional)'),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.login,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      List<String>.filled(
                                        item.password.length
                                            .clamp(4, 14)
                                            .toInt(),
                                        '•',
                                      ).join(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.level,
                                      onChanged: (value) {
                                        item.level = value;
                                      },
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: gl('LV2'),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.accountAge,
                                      onChanged: (value) {
                                        item.accountAge = value;
                                      },
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: gl('6 anos'),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.steamProfile,
                                      onChanged: (value) {
                                        item.steamProfile = value;
                                      },
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: gl('Perfil Steam'),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 115,
                                    child: Text(
                                      item.duplicate
                                          ? 'Duplicada'
                                          : item.selected
                                          ? 'Selecionada'
                                          : 'Detectada',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: item.duplicate
                                            ? Colors.redAccent
                                            : item.selected
                                            ? Colors.greenAccent
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: selectedCount == 0 ? null : importSelected,
                    icon: const Icon(Icons.download_done),
                    label: Text(
                      'Importar $selectedCount conta${selectedCount == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParsedCredentials {
  final String name;
  final String login;
  final String password;
  final String level;
  final String accountAge;
  final String steamProfile;

  const _ParsedCredentials({
    required this.name,
    required this.login,
    required this.password,
    required this.level,
    required this.accountAge,
    required this.steamProfile,
  });
}

class _ImportPreviewItem {
  String name;
  final String login;
  final String password;
  String level;
  String accountAge;
  String steamProfile;
  final bool duplicate;
  bool selected;

  _ImportPreviewItem({
    required this.name,
    required this.login,
    required this.password,
    required this.level,
    required this.accountAge,
    required this.steamProfile,
    required this.duplicate,
    required this.selected,
  });
}

class RestoreVaultScreen extends StatefulWidget {
  const RestoreVaultScreen({super.key});

  @override
  State<RestoreVaultScreen> createState() => _RestoreVaultScreenState();
}

class _RestoreVaultScreenState extends State<RestoreVaultScreen> {
  bool loading = false;

  Future<void> restore() async {
    setState(() {
      loading = true;
    });

    try {
      final fileName = await BackupService.restoreFromPicker();

      if (fileName == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup "$fileName" restaurado.')));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnlockScreen()),
        (_) => false,
      );
    } on BackupException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurar cofre')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                const Icon(
                  Icons.restore_rounded,
                  size: 72,
                  color: Color(0xFF9A87FF),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Restaurar meu cofre',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Selecione um arquivo .sv exportado anteriormente pelo GamerLocker.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF292D38)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFF9A87FF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'O arquivo continua criptografado. Depois da restauracao voce precisara da senha do cofre ou da Recovery Key.',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : restore,
                    icon: const Icon(Icons.folder_open),
                    label: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Selecionar backup .sv'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool loading = false;

  Future<void> exportBackup() async {
    setState(() {
      loading = true;
    });

    try {
      final path = await BackupService.exportBackup();

      if (path == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Backup salvo em: $path')));

      setState(() {});
    } on BackupException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> restoreExternal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restaurar outro backup?'),
          content: const Text(
            'O cofre atual sera preservado em uma copia de seguranca antes da restauracao. Depois sera necessario desbloquear o backup restaurado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await BackupService.restoreFromPicker();

      if (result == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnlockScreen()),
        (_) => false,
      );
    } on BackupException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> restoreAutomatic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restaurar backup automatico?'),
          content: const Text(
            'Isso restaura a versao criptografada anterior do seu cofre.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await BackupService.restoreAutomaticBackup();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnlockScreen()),
        (_) => false,
      );
    } on BackupException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup do cofre',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Os backups contem o cofre criptografado. Login, senha e demais dados nao sao exportados em texto puro.',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 26),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF292D38)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.save_alt, color: Color(0xFF9A87FF)),
                          SizedBox(width: 10),
                          Text(
                            'Backup manual',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Gera um arquivo .sv que pode ser guardado em pendrive, Google Drive, OneDrive ou outro computador.',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: loading ? null : exportBackup,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Exportar backup .sv'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                FutureBuilder<bool>(
                  future: BackupService.automaticBackupExists(),
                  builder: (context, snapshot) {
                    final exists = snapshot.data == true;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151821),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF292D38)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                exists ? Icons.check_circle : Icons.history,
                                color: exists
                                    ? Colors.greenAccent
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Backup local automatico',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            exists
                                ? 'Existe uma copia criptografada da versao anterior do cofre.'
                                : 'A copia automatica sera criada quando houver uma nova gravacao do cofre.',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: exists && !loading
                                  ? restoreAutomatic
                                  : null,
                              icon: const Icon(Icons.history),
                              label: const Text('Restaurar backup automatico'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF292D38)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.restore, color: Color(0xFF9A87FF)),
                          SizedBox(width: 10),
                          Text(
                            'Restaurar arquivo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Substitui o cofre atual por outro arquivo .sv. Antes disso, o GamerLocker cria uma copia de seguranca do cofre atual.',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : restoreExternal,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Restaurar outro .sv'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                FutureBuilder<String>(
                  future: BackupService.localVaultPath(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101217),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arquivo local do cofre',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            snapshot.data!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlanBadge extends StatelessWidget {
  final int accountCount;

  const PlanBadge({super.key, required this.accountCount});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlanInfo>(
      valueListenable: PlanService.current,
      builder: (context, plan, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanScreen(accountCount: accountCount),
                ),
              );
            },
            icon: Icon(
              plan.isPro ? Icons.workspace_premium : Icons.lock_open_rounded,
              size: 17,
            ),
            label: Text(
              plan.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}

class PlanScreen extends StatelessWidget {
  final int accountCount;

  const PlanScreen({super.key, required this.accountCount});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlanInfo>(
      valueListenable: PlanService.current,
      builder: (context, plan, child) {
        final limit = plan.accountLimit;

        final double progress;

        if (limit == null) {
          progress = 1;
        } else if (accountCount >= limit) {
          progress = 1;
        } else {
          progress = accountCount / limit;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Plano')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seu plano',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151821),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF292D38)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: plan.isPro
                                      ? const Color(0xFF48389A)
                                      : const Color(0xFF292D38),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  plan.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (plan.isPro)
                                Text(
                                  'Ativo',
                                  style: TextStyle(
                                    color: Colors.greenAccent.shade100,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (!plan.isPro) ...[
                            Text(
                              '$accountCount / ${PlanService.freeAccountLimit} contas utilizadas',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              PlanService.remainingAccounts(accountCount) == 0
                                  ? 'Limite FREE atingido.'
                                  : '${PlanService.remainingAccounts(accountCount)} contas restantes no plano FREE.',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ] else ...[
                            const Text(
                              'Contas ilimitadas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          PlanValidity(plan: plan),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (gamerLockerMicrosoftStoreBuild)
                      _StoreEditionCard()
                    else
                      _RegularProCard(plan: plan),
                    if (!gamerLockerMicrosoftStoreBuild) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151821),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF292D38)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Possui uma chave?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use chaves promocionais, de beta ou cortesia para ativar um período do PRO.',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ActivateKeyScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.vpn_key_outlined),
                                label: const Text('Ativar chave do produto'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Mesmo sem PRO, seus dados locais continuam acessíveis e podem ser exportados normalmente.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoreEditionCard extends StatelessWidget {
  const _StoreEditionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF231D42), Color(0xFF171A21)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4E4385)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront_rounded,
                color: Color(0xFFAA9BFF),
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GamerLocker Store Edition',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Full Access local',
                      style: TextStyle(color: Color(0xFFB9AFFF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text('Compra única pela Microsoft Store'),
          SizedBox(height: 22),
          _ProFeature(icon: Icons.all_inclusive, title: 'Contas ilimitadas'),
          _ProFeature(
            icon: Icons.lock_outline_rounded,
            title: 'Cofre local criptografado',
          ),
          _ProFeature(
            icon: Icons.backup_outlined,
            title: 'Backup local criptografado',
          ),
          _ProFeature(
            icon: Icons.playlist_add_rounded,
            title: 'Importação em massa',
          ),
          _ProFeature(
            icon: Icons.workspace_premium_outlined,
            title: 'Recursos premium locais',
          ),
          SizedBox(height: 12),
          Text(
            'Esta edição libera permanentemente os recursos locais do GamerLocker neste produto da Microsoft Store.',
          ),
          SizedBox(height: 10),
          Text(
            'Cloud e sincronização não estão incluídos automaticamente e poderão ser oferecidos separadamente no futuro.',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _RegularProCard extends StatelessWidget {
  final PlanInfo plan;

  const _RegularProCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF231D42), Color(0xFF171A21)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4E4385)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium, color: Color(0xFFAA9BFF), size: 34),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GamerLocker PRO',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'R\$ 29,90 / mês',
                      style: TextStyle(color: Color(0xFFB9AFFF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _ProFeature(
            icon: Icons.all_inclusive,
            title: 'Contas ilimitadas',
          ),
          const _ProFeature(
            icon: Icons.cloud_outlined,
            title: 'Cloud em breve',
          ),
          const _ProFeature(
            icon: Icons.sync_rounded,
            title: 'Sincronizacao em breve',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: plan.isPro
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PurchaseProScreen(),
                        ),
                      );
                    },
              child: Text(plan.isPro ? 'PRO ativo' : 'Assinar PRO'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProFeature({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 19,
            color: Colors.greenAccent.shade100,
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 19, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }
}

class ActivateKeyScreen extends StatefulWidget {
  const ActivateKeyScreen({super.key});

  @override
  State<ActivateKeyScreen> createState() => _ActivateKeyScreenState();
}

class _ActivateKeyScreenState extends State<ActivateKeyScreen> {
  final controller = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String normalizeKey(String input) {
    return input.trim().toUpperCase().replaceAll(' ', '');
  }

  bool validFormat(String value) {
    //
    // Formato:
    //
    // SVP-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
    //
    // 25 caracteres aleatorios usando
    // alfabeto sem 0/O e 1/I.
    //
    final pattern = RegExp(
      r'^SVP-[A-HJ-NP-Z2-9]{5}'
      r'(?:-[A-HJ-NP-Z2-9]{5}){4}$',
    );

    return pattern.hasMatch(value);
  }

  Future<void> activateKey() async {
    final key = normalizeKey(controller.text);

    if (!validFormat(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de chave invalido.')),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await ProductKeyService.redeem(key);

      if (!mounted) {
        return;
      }

      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'Nao foi possivel ativar esta chave.'
                  : result.message,
            ),
          ),
        );
        return;
      }

      final expires = result.newProUntil?.toLocal();

      final expiresText = expires == null
          ? ''
          : '${expires.day.toString().padLeft(2, '0')}/'
                '${expires.month.toString().padLeft(2, '0')}/'
                '${expires.year} '
                '${expires.hour.toString().padLeft(2, '0')}:'
                '${expires.minute.toString().padLeft(2, '0')}';

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.workspace_premium),
            title: const Text('GamerLocker PRO ativado'),
            content: Text(
              result.isLifetime
                  ? 'PRO vitalício — sem vencimento'
                  : '${result.daysAdded} dias adicionados.'
                    '${expiresText.isEmpty ? '' : '\n\nValido ate: $expiresText'}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      controller.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao ativar chave: $e')));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ativar chave')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              children: [
                const Icon(
                  Icons.vpn_key_outlined,
                  size: 68,
                  color: Color(0xFF9A87FF),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ativar GamerLocker PRO',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Insira sua chave promocional ou de cortesia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 28),
                ValueListenableBuilder<PlanInfo>(
                  valueListenable: PlanService.current,
                  builder: (context, plan, _) => PlanValidity(plan: plan),
                ),
                const SizedBox(height: 12),
                const Text('Ative uma chave por vez. Os períodos são somados à validade atual.'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  inputFormatters: [UpperCaseTextFormatter()],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, letterSpacing: 1),
                  decoration: InputDecoration(
                    labelText: gl('Chave do produto'),
                    hintText: gl('SVP-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : activateKey,
                    icon: const Icon(Icons.verified_outlined),
                    label: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Validar chave'),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF9A87FF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A chave n\u00E3o ser\u00E1 validada apenas pelo aplicativo. A ativa\u00E7\u00E3o definitiva exigir\u00E1 confirma\u00E7\u00E3o do servidor GamerLocker.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
