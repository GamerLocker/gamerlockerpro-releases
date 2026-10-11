import 'package:flutter/material.dart';

import 'main.dart'
    show AccountEntry, SteamCooldownSummary, SteamSecuritySummary;
import 'steam_account_avatar.dart';
import 'steam_cooldown_service.dart';
import 'app_localizations.dart' show gl;

typedef AccountCheck = Future<SteamCooldownResult> Function(
  AccountEntry account,
  String? code,
  bool mobile,
);

Future<({int done, int failed})> verifyAccountBatch(
  List<AccountEntry> accounts, {
  required bool Function() stopped,
  required void Function(int done, int total, String name) progress,
  required Future<String?> Function(AccountEntry account, bool mobile) guard,
  required AccountCheck check,
  required void Function(AccountEntry account, SteamCooldownResult result)
  finished,
}) async {
  var done = 0, failed = 0;
  Future<SteamCooldownResult> read(
    AccountEntry account,
    String? code,
    bool mobile,
  ) async {
    try {
      return await check(account, code, mobile);
    } catch (_) {
      return const SteamCooldownResult(
        status: 'error',
        message: 'Falha ao consultar a conta.',
      );
    }
  }

  for (final account in accounts) {
    if (stopped()) break;
    progress(done, accounts.length, account.displayName);
    var result = await read(account, null, false);
    if (result.needsSteamGuard && !stopped()) {
      final mobile =
          result.guardType == 'mobile' ||
          result.status == 'two_factor_required';
      final code = await guard(account, mobile);
      if (stopped() || code == null || code.isEmpty) break;
      result = await read(account, code, mobile);
    }
    finished(account, result);
    done++;
    if (result.status != 'ok') failed++;
    progress(done, accounts.length, account.displayName);
  }
  return (done: done, failed: failed);
}

class AccountListOverview extends StatelessWidget {
  final List<AccountEntry> accounts;
  final bool verifying;
  final void Function(AccountEntry) onOpen;
  final SteamCooldownResult? Function(AccountEntry) resultFor;
  const AccountListOverview({
    super.key,
    required this.accounts,
    required this.verifying,
    required this.onOpen,
    required this.resultFor,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 1050 ? 1050 : constraints.maxWidth,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(gl('Conta'))),
                    Expanded(child: Text(gl('Prime'))),
                    Expanded(child: Text(gl('Horas CS2'))),
                    Expanded(flex: 4, child: Text(gl('Penalidade'))),
                    Expanded(flex: 2, child: Text(gl('Segurança'))),
                  ],
                ),
              ),
              ...accounts.map((account) {
                final result = resultFor(account);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: const Color(0xFF151821),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onOpen(account),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  SteamAccountAvatar(
                                    reference: account.steamProfileReference,
                                    login: account.fields['Login'] ?? '',
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          account.fields['Login'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                gl(
                                  result?.prime == null
                                      ? 'Não informado'
                                      : result!.prime!
                                      ? 'Sim'
                                      : 'Não',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                account.steamCs2Minutes == null
                                    ? gl('Não informado')
                                    : '${(account.steamCs2Minutes! / 60).toStringAsFixed(1)} h',
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: account.type == 'Steam'
                                  ? SteamCooldownSummary(
                                      account: account,
                                      compact: true,
                                      verificationBusy: verifying,
                                    )
                                  : Text(gl('Não se aplica')),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: account.type == 'Steam'
                                  ? SteamSecuritySummary(
                                      account: account,
                                      compact: true,
                                    )
                                  : Text(
                                      '${gl('Segurança')} ${account.securityScore}%',
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
