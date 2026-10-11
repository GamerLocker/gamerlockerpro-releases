import 'package:flutter/material.dart' hide Text, SelectableText;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_localizations.dart';
import 'account_service.dart';
import 'app_backend.dart';

class AccountAuthGate extends StatefulWidget {
  final WidgetBuilder nextBuilder;

  const AccountAuthGate({super.key, required this.nextBuilder});

  @override
  State<AccountAuthGate> createState() => _AccountAuthGateState();
}

class _AccountAuthGateState extends State<AccountAuthGate> {
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    if (!AppBackend.configured) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      return;
    }

    if (AccountService.isLoggedIn) {
      try {
        await AccountService.refreshPlan();
      } catch (_) {}

      loggedIn = true;
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!AppBackend.configured || loggedIn) {
      return widget.nextBuilder(context);
    }

    return GamerLockerLoginScreen(nextBuilder: widget.nextBuilder);
  }
}

class GamerLockerLoginScreen extends StatefulWidget {
  final WidgetBuilder nextBuilder;

  const GamerLockerLoginScreen({super.key, required this.nextBuilder});

  @override
  State<GamerLockerLoginScreen> createState() => _GamerLockerLoginScreenState();
}

class _GamerLockerLoginScreenState extends State<GamerLockerLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe e-mail e senha.')));

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await AccountService.signIn(email: email, password: password);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: widget.nextBuilder),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nao foi possivel entrar.')));
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
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: gl('Idioma'),
            onPressed: () {
              showGamerLockerLanguageDialog(context);
            },
            icon: const Icon(Icons.language_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GamerLocker',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre na sua conta GamerLocker',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: gl('E-mail'),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  onSubmitted: (_) => login(),
                  decoration: InputDecoration(
                    labelText: gl('Senha da conta'),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GamerLockerRegisterScreen(
                                  nextBuilder: widget.nextBuilder,
                                ),
                              ),
                            );
                          },
                    child: const Text('Criar conta'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'A senha desta conta e separada da senha do seu cofre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GamerLockerRegisterScreen extends StatefulWidget {
  final WidgetBuilder nextBuilder;

  const GamerLockerRegisterScreen({super.key, required this.nextBuilder});

  @override
  State<GamerLockerRegisterScreen> createState() =>
      _GamerLockerRegisterScreenState();
}

class _GamerLockerRegisterScreenState extends State<GamerLockerRegisterScreen> {
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

  Future<void> register() async {
    final name = nameController.text.trim();

    final email = emailController.text.trim();

    final password = passwordController.text;

    final confirmation = confirmController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')),
      );

      return;
    }

    if (password.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use pelo menos 10 caracteres na senha.')),
      );

      return;
    }

    if (password != confirmation) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('As senhas nao coincidem.')));

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await AccountService.signUp(
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.session != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: widget.nextBuilder),
          (_) => false,
        );

        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Confirme seu e-mail'),
            content: Text(
              'Enviamos uma confirmacao para $email. Confirme o endereco e depois entre no GamerLocker.',
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

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel criar a conta.')),
      );
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
      appBar: AppBar(
        title: const Text('Criar conta'),
        actions: [
          IconButton(
            tooltip: gl('Idioma'),
            onPressed: () {
              showGamerLockerLanguageDialog(context);
            },
            icon: const Icon(Icons.language_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const Text(
                  'Criar conta GamerLocker',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: gl('Nome'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: gl('E-mail'),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: gl('Senha da conta'),
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
                const SizedBox(height: 14),
                TextField(
                  controller: confirmController,
                  obscureText: !showPassword,
                  onSubmitted: (_) => register(),
                  decoration: InputDecoration(
                    labelText: gl('Confirmar senha'),
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : register,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar conta'),
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
