import 'package:flutter/material.dart';

import 'steam_cooldown_service.dart';

class SteamAccountScreen extends StatefulWidget {
  final String username;
  final String password;
  final Future<SteamCooldownResult> Function(int)? loadDetails;
  const SteamAccountScreen({
    super.key,
    required this.username,
    required this.password,
    this.loadDetails,
  });
  @override
  State<SteamAccountScreen> createState() => _SteamAccountScreenState();
}

class _SteamAccountScreenState extends State<SteamAccountScreen> {
  SteamCooldownResult? result;
  bool loading = false;
  String? error;
  String search = '';
  int inventoryApp = 730;
  @override
  void initState() {
    super.initState();
    result = SteamCooldownService.cachedDetails(widget.username);
    inventoryApp =
        (result?.accountDetails?['inventoryAppId'] as num?)?.toInt() ?? 730;
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    if (loading || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      var next =
          await (widget.loadDetails?.call(inventoryApp) ??
              SteamCooldownService.check(
                username: widget.username,
                password: widget.password,
                detailsOnly: true,
                inventoryAppId: inventoryApp,
              ));
      if (!mounted) return;
      if (next.needsSteamGuard) {
        final controller = TextEditingController();
        final code = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Steam Guard'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: next.guardType == 'mobile'
                    ? 'Código do autenticador'
                    : 'Código recebido por e-mail',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (code != null && code.isNotEmpty) {
          final mobile =
              next.guardType == 'mobile' ||
              next.status == 'two_factor_required';
          next = await SteamCooldownService.check(
            username: widget.username,
            password: widget.password,
            detailsOnly: true,
            inventoryAppId: inventoryApp,
            authCode: mobile ? null : code,
            twoFactorCode: mobile ? code : null,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        if (next.accountDetails != null) {
          result = next;
        } else {
          error =
              next.message ??
              'Não foi possível carregar os dados da Steam. Tente novamente.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Não foi possível consultar a Steam. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> rows(String key) =>
      (result?.accountDetails?[key] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  String hours(Object? minutes) =>
      '${((minutes as num? ?? 0) / 60).toStringAsFixed(1)} h';
  Widget message(String text) =>
      Padding(padding: const EdgeInsets.all(24), child: Text(text));
  Widget picture(String url) => url.isEmpty
      ? const Icon(Icons.inventory_2_outlined)
      : Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.image_not_supported_outlined),
        );

  @override
  Widget build(BuildContext context) {
    final data = result?.accountDetails;
    final games = rows('games');
    games.sort((a, b) => (b['minutes'] as num).compareTo(a['minutes'] as num));
    final cs = games.where((g) => g['appId'] == 730).firstOrNull;
    final inventory = rows('inventory');
    final medals = inventory.where((i) => i['isMedal'] == true).toList();
    final filtered = games
        .where(
          (g) => '${g['name']}'.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(result?.personaName ?? 'Conta Steam'),
          actions: [
            IconButton(
              onPressed: loading ? null : refresh,
              tooltip: 'Atualizar dados',
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Resumo'),
              Tab(text: 'Jogos'),
              Tab(text: 'Insígnias e medalhas'),
              Tab(text: 'Inventário'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) message(error!),
            Expanded(
              child: data == null
                  ? Center(
                      child: Text(
                        loading
                            ? 'Consultando a conta Steam...'
                            : 'Atualize para carregar a conta.',
                      ),
                    )
                  : TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            ListTile(
                              leading: picture(result?.avatarUrl ?? ''),
                              title: Text(
                                result?.personaName ?? widget.username,
                              ),
                              subtitle: SelectableText(
                                'SteamID: ${data['steamId64']}',
                              ),
                            ),
                            ListTile(
                              title: const Text('Nível Steam'),
                              trailing: Text(
                                '${data['steamLevel'] ?? 'Não disponível'}',
                              ),
                            ),
                            if (data['createdAt'] != null)
                              ListTile(
                                title: const Text('Conta criada em'),
                                trailing: Text(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    (data['createdAt'] as num).toInt() * 1000,
                                  ).toLocal().toString().split(' ').first,
                                ),
                              ),
                            ListTile(
                              title: const Text('Jogos na biblioteca'),
                              trailing: Text(
                                data['gamesStatus'] == 'ok'
                                    ? '${games.length}'
                                    : 'Não disponível',
                              ),
                            ),
                            ListTile(
                              title: const Text('Horas de CS2 / CS:GO'),
                              trailing: Text(
                                cs == null
                                    ? 'Não disponível'
                                    : hours(cs['minutes']),
                              ),
                            ),
                            ListTile(
                              title: const Text('CS nas últimas 2 semanas'),
                              trailing: Text(
                                cs == null
                                    ? 'Não disponível'
                                    : hours(cs['recentMinutes']),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Os dados refletem o que a Steam disponibiliza nesta consulta. Informações privadas ou limitadas podem não ser retornadas.',
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                onChanged: (value) =>
                                    setState(() => search = value),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  labelText: 'Buscar jogo',
                                ),
                              ),
                            ),
                            Expanded(
                              child: data['gamesStatus'] != 'ok'
                                  ? message(
                                      'Biblioteca indisponível nesta consulta.',
                                    )
                                  : filtered.isEmpty
                                  ? message(
                                      games.isEmpty
                                          ? 'Nenhum jogo retornado pela Steam.'
                                          : 'Nenhum jogo encontrado.',
                                    )
                                  : ListView.builder(
                                      itemCount: filtered.length,
                                      itemBuilder: (_, index) {
                                        final game = filtered[index];
                                        return ListTile(
                                          leading: picture(
                                            'https://cdn.akamai.steamstatic.com/steam/apps/${game['appId']}/header.jpg',
                                          ),
                                          title: Text('${game['name']}'),
                                          subtitle: Text(
                                            'AppID ${game['appId']} • Últimas 2 semanas: ${hours(game['recentMinutes'])}',
                                          ),
                                          trailing: Text(
                                            hours(game['minutes']),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(
                              'Insígnias Steam',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (data['badgesStatus'] != 'ok')
                              message('Insígnias indisponíveis nesta consulta.')
                            else if ((data['badges'] as List).isEmpty)
                              message('Nenhuma insígnia retornada.')
                            else
                              ...(data['badges'] as List).map(
                                (badge) => ListTile(
                                  leading: const Icon(Icons.workspace_premium),
                                  title: Text('$badge'),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Text(
                              'Medalhas e moedas do CS2',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (data['inventoryAppId'] != 730)
                              message(
                                'Selecione CS2 na aba Inventário para consultar as medalhas.',
                              )
                            else if (data['inventoryStatus'] != 'ok')
                              message(
                                'Inventário CS2 indisponível; não foi possível consultar as medalhas.',
                              )
                            else if (medals.isEmpty)
                              message(
                                'Nenhuma medalha ou moeda retornada no inventário CS2.',
                              )
                            else
                              ...medals.map(
                                (item) => ListTile(
                                  leading: picture('${item['iconUrl']}'),
                                  title: Text('${item['name']}'),
                                ),
                              ),
                            if (data['inventoryAppId'] == 730 &&
                                data['inventoryComplete'] != true)
                              message(
                                'A consulta do inventário está incompleta.',
                              ),
                          ],
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: DropdownButtonFormField<int>(
                                initialValue: inventoryApp,
                                decoration: const InputDecoration(
                                  labelText: 'Inventário do jogo',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 730,
                                    child: Text('Counter-Strike 2'),
                                  ),
                                  DropdownMenuItem(
                                    value: 570,
                                    child: Text('Dota 2'),
                                  ),
                                  DropdownMenuItem(
                                    value: 440,
                                    child: Text('Team Fortress 2'),
                                  ),
                                  DropdownMenuItem(
                                    value: 753,
                                    child: Text('Comunidade Steam'),
                                  ),
                                ],
                                onChanged: loading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => inventoryApp = value);
                                          refresh();
                                        }
                                      },
                              ),
                            ),
                            if (data['inventoryAppId'] != inventoryApp)
                              message('Carregando o inventário selecionado...')
                            else if (data['inventoryStatus'] == 'ok')
                              message(
                                '${inventory.length} itens${data['inventoryComplete'] == true ? '' : ' • consulta incompleta'}',
                              ),
                            Expanded(
                              child: data['inventoryAppId'] != inventoryApp
                                  ? const SizedBox.shrink()
                                  : data['inventoryStatus'] != 'ok'
                                  ? message(
                                      'Inventário indisponível nesta consulta. Pode estar privado ou temporariamente limitado pela Steam.',
                                    )
                                  : inventory.isEmpty
                                  ? message('Inventário vazio.')
                                  : ListView.builder(
                                      itemCount: inventory.length,
                                      itemBuilder: (_, index) {
                                        final item = inventory[index];
                                        return ListTile(
                                          leading: picture(
                                            '${item['iconUrl']}',
                                          ),
                                          title: Text('${item['name']}'),
                                          subtitle: Text(
                                            '${item['type']} • Quantidade: ${item['amount']}\n${item['tradable'] == true ? 'Negociável' : 'Não negociável'} • ${item['marketable'] == true ? 'Vendável no Mercado' : 'Não vendável no Mercado'}',
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
