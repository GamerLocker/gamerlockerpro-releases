import 'dart:io';

import 'package:flutter/material.dart' hide Text, SelectableText;
import 'package:flutter/services.dart';

import 'app_localizations.dart';
import 'purchase_config.dart';

class PurchaseProScreen extends StatelessWidget {
  const PurchaseProScreen({super.key});

  static const String _discordAsset = 'assets/images/dippo_discord_card.jpg';

  Future<void> _copyDiscord(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: PurchaseConfig.discordContact),
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Discord do Dippo copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('GamerLocker PRO')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 72,
                    color: Color(0xFFAA9BFF),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'GamerLocker PRO',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    PurchaseConfig.proPrice,
                    style: const TextStyle(
                      color: Color(0xFFC3B9FF),
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Android, a assinatura sera integrada ao Google Play '
                    'antes da publicacao. Se sua conta ja possui PRO ativo, '
                    'os beneficios continuam sendo reconhecidos normalmente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hasDiscord =
        PurchaseConfig.discordContact.trim().isNotEmpty &&
        PurchaseConfig.discordContact != 'SEU_DISCORD_AQUI';

    return Scaffold(
      appBar: AppBar(title: const Text('GamerLocker PRO')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF241B48),
                        Color(0xFF171A24),
                        Color(0xFF11131A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF5E4FA2)),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 30,
                        spreadRadius: 1,
                        color: Color(0x332C1D72),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF8A6BFF), Color(0xFF4C36B8)],
                          ),
                          boxShadow: [
                            BoxShadow(blurRadius: 24, color: Color(0x665D43E8)),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'GamerLocker PRO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        PurchaseConfig.proPrice,
                        style: const TextStyle(
                          color: Color(0xFFC3B9FF),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _ProChip(text: 'Contas ilimitadas'),
                          _ProChip(text: 'Recursos premium'),
                          _ProChip(text: 'Cloud em breve'),
                          _ProChip(text: 'Sincronizacao em breve'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2B2F3B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.forum_outlined, color: Color(0xFFB6A9FF)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Adquirir o PRO no Windows',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Para adquirir o GamerLocker PRO, chame o Dippo '
                        'diretamente no Discord. Confira o perfil oficial abaixo.',
                        style: TextStyle(
                          height: 1.45,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1672 / 941,
                          child: Image.asset(
                            _discordAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                alignment: Alignment.center,
                                color: const Color(0xFF101218),
                                child: const Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                    'Nao foi possivel carregar a imagem '
                                    'do contato do Discord.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101218),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF343044)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.alternate_email_rounded,
                              color: Color(0xFFB6A9FF),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(
                                PurchaseConfig.discordContact,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: hasDiscord
                              ? () => _copyDiscord(context)
                              : null,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copiar Discord do Dippo'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12151D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF292E39)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Como funciona a ativacao',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 16),
                      _StepRow(number: '1', text: 'Chame o Dippo no Discord.'),
                      _StepRow(
                        number: '2',
                        text:
                            'Combine o pagamento e envie o comprovante '
                            'diretamente por la.',
                      ),
                      _StepRow(
                        number: '3',
                        text:
                            'Depois da confirmacao, voce recebera sua '
                            'Product Key PRO.',
                      ),
                      _StepRow(
                        number: '4',
                        text:
                            'No GamerLocker, abra Plano > Ativar chave '
                            'do produto e informe a key recebida.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101217),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: Color(0xFF9A87FF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nunca envie senha do cofre, Recovery Key, senha '
                          'de e-mail ou senha de alguma conta de jogo pelo '
                          'Discord. Para ativar o PRO, voce so precisa tratar '
                          'o pagamento e receber a Product Key.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Colors.grey.shade400,
                          ),
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

class _StepRow extends StatelessWidget {
  final String number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF473A83),
            ),
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(text, style: const TextStyle(height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  final String text;

  const _ProChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x222B1F66),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x555E4FA2)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFFD5CEFF)),
      ),
    );
  }
}
