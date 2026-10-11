// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:path_provider/path_provider.dart';

class GamerLockerLocale {
  GamerLockerLocale._();

  static final ValueNotifier<material.Locale?> current =
      ValueNotifier<material.Locale?>(null);

  static const supportedLocales = <material.Locale>[
    material.Locale('pt', 'BR'),
    material.Locale('en', 'US'),
  ];

  static String get languageCode {
    final selected = current.value;

    if (selected != null) {
      return selected.languageCode;
    }

    return PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'pt'
        ? 'pt'
        : 'en';
  }

  static bool get isEnglish => languageCode == 'en';

  static Future<File> _settingsFile() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}GamerLocker');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File('${dir.path}${Platform.pathSeparator}settings.json');
  }

  static Future<void> load() async {
    try {
      final file = await _settingsFile();

      if (!await file.exists()) {
        return;
      }

      final decoded = jsonDecode(await file.readAsString());

      if (decoded is! Map) {
        return;
      }

      final language = decoded['language']?.toString();

      if (language == 'pt') {
        current.value = const material.Locale('pt', 'BR');
      } else if (language == 'en') {
        current.value = const material.Locale('en', 'US');
      } else {
        current.value = null;
      }
    } catch (_) {
      current.value = null;
    }
  }

  static Future<void> setLanguage(String language) async {
    switch (language) {
      case 'pt':
        current.value = const material.Locale('pt', 'BR');
        break;
      case 'en':
        current.value = const material.Locale('en', 'US');
        break;
      default:
        current.value = null;
        language = 'system';
    }

    try {
      final file = await _settingsFile();
      await file.writeAsString(
        jsonEncode(<String, String>{'language': language}),
        flush: true,
      );
    } catch (_) {
      // The language still changes for the current session even if
      // persistence is unavailable.
    }
  }
}

final Map<String, String> _english = <String, String>{
  'Conta': 'Account',
  'E-mail vinculado': 'Linked email',
  'Telefone vinculado': 'Linked phone',
  'Midnight': 'Midnight',
  'Escuro e discreto': 'Dark and subtle',
  'RGB Neon': 'RGB Neon',
  'Roxo, azul e verde em estilo gamer': 'Purple, blue and green gamer style',
  'Violet': 'Violet',
  'Roxo profundo': 'Deep purple',
  'Cyber Blue': 'Cyber Blue',
  'Azul e ciano': 'Blue and cyan',
  'Crimson': 'Crimson',
  'Vermelho escuro': 'Dark red',
  'Emerald': 'Emerald',
  'Verde profundo': 'Deep green',
  'Seu cofre pessoal para contas de jogos.':
      'Your personal vault for gaming accounts.',
  'Nenhum cofre local foi encontrado neste dispositivo.':
      'No local vault was found on this device.',
  'Criar novo cofre': 'Create new vault',
  'Restaurar meu cofre': 'Restore my vault',
  'O backup permanece criptografado.': 'The backup remains encrypted.',
  'Informe seu nome.': 'Enter your name.',
  'Informe um e-mail válido.': 'Enter a valid email address.',
  'Use uma senha com pelo menos 8 caracteres.':
      'Use a password with at least 8 characters.',
  'As senhas não são iguais.': 'The passwords do not match.',
  'Criar cofre': 'Create vault',
  'Crie seu cofre': 'Create your vault',
  'Nome': 'Name',
  'E-mail': 'Email',
  'Senha do cofre': 'Vault password',
  'Confirmar senha': 'Confirm password',
  'Sua Recovery Key': 'Your Recovery Key',
  'Ela pode desbloquear seu cofre caso você esqueça a senha.':
      'It can unlock your vault if you forget the password.',
  'Recovery Key copiada. O clipboard será limpo em 30 segundos.':
      'Recovery Key copied. The clipboard will be cleared in 30 seconds.',
  'Copiar': 'Copy',
  'O GamerLocker não armazena esta chave em texto legível. Guarde-a fora deste computador também.': 'GamerLocker does not store this key in readable text. Keep a copy outside this computer too.',
  'Salvei minha Recovery Key em um local seguro.':
      'I saved my Recovery Key in a safe place.',
  'Entrar no cofre': 'Enter vault',
  'Desbloqueie seu cofre': 'Unlock your vault',
  'Desbloquear': 'Unlock',
  'Usar Recovery Key': 'Use Recovery Key',
  'Recovery Key': 'Recovery Key',
  'Recuperar cofre': 'Recover vault',
  'Excluir conta?': 'Delete account?',
  'Cancelar': 'Cancel',
  'Excluir': 'Delete',
  'Nao foi possivel abrir o perfil. Confira o SteamID informado.':
      'Could not open the profile. Check the SteamID.',
  'Nao foi possivel abrir o perfil. Confira o Perfil Steam informado.':
      'Could not open the profile. Check the Steam profile.',
  'Nao foi possivel abrir o perfil Steam.': 'Could not open the Steam profile.',
  'Escolher fundo do dashboard': 'Choose dashboard background',
  'Escolher fundo': 'Choose background',
  'Backup': 'Backup',
  'Bloquear cofre': 'Lock vault',
  'Pesquisar nome, login, SteamID, patente...':
      'Search name, login, SteamID, rank...',
  'Pesquisar nome, login, perfil Steam, patente...':
      'Search name, login, Steam profile, rank...',
  'Limpar pesquisa': 'Clear search',
  'Importar contas': 'Import accounts',
  'Nova conta': 'New account',
  'Seu cofre ainda esta vazio.': 'Your vault is still empty.',
  'Adicionar primeira conta': 'Add first account',
  'Importar varias contas': 'Import multiple accounts',
  'Resultados': 'Results',
  '★ Favoritas': '★ Favorites',
  'Todas as contas': 'All accounts',
  'Contas': 'Accounts',
  'Favoritas': 'Favorites',
  'Protegidas': 'Protected',
  'Atenção': 'Attention',
  'Organizar contas': 'Organize accounts',
  'Salvar': 'Save',
  'Arraste as contas para a ordem que quiser. Favoritas continuam aparecendo na secao de favoritas, respeitando esta ordem.': 'Drag accounts into any order you want. Favorites will still appear in the favorites section, following this order.',
  'Senha': 'Password',
  'Remover dos favoritos': 'Remove from favorites',
  'Adicionar aos favoritos': 'Add to favorites',
  'Minimizar conta': 'Collapse account',
  'Expandir conta': 'Expand account',
  'Arrastar para reorganizar': 'Drag to reorder',
  'Abrir conta': 'Open account',
  'Editar': 'Edit',
  'Abrir perfil Steam': 'Open Steam profile',
  'Boa': 'Good',
  'Baixa': 'Low',
  'Login copiado. Clipboard sera limpo em 30 segundos.':
      'Login copied. The clipboard will be cleared in 30 seconds.',
  'Senha copiada. Clipboard sera limpo em 30 segundos.':
      'Password copied. The clipboard will be cleared in 30 seconds.',
  'Perfil Steam': 'Steam profile',
  'Carregando perfil Steam...': 'Loading Steam profile...',
  'SteamID vinculado': 'Linked SteamID',
  'Perfil Steam vinculado': 'Linked Steam profile',
  'Ocultar senhas': 'Hide passwords',
  'Mostrar senhas': 'Show passwords',
  '2FA / autenticador ativo': '2FA / authenticator enabled',
  'Recovery Code salvo': 'Recovery Code saved',
  'Backup Codes salvos': 'Backup Codes saved',
  'E-mail verificado': 'Email verified',
  'Telefone verificado': 'Phone verified',
  'Não informado': 'Not provided',
  'Senha do e-mail': 'Email password',
  'Nome no perfil': 'Profile name',
  'Sim': 'Yes',
  'Não': 'No',
  'Jogo / serviço': 'Game / service',
  'Jogo / servico': 'Game / service',
  'Mostrar no dashboard': 'Show on dashboard',
  'Informe pelo menos um nome ou login para a conta.':
      'Enter at least a name or login for the account.',
  'Outro jogo / serviço': 'Other game / service',
  'Outro jogo / servico': 'Other game / service',
  'Editar conta': 'Edit account',
  'Adicionar conta': 'Add account',
  'Tipo da conta': 'Account type',
  'Nome para identificar a conta (opcional)':
      'Name to identify the account (optional)',
  'Ex.: Main, Smurf... ou deixe vazio': 'E.g. Main, Smurf... or leave blank',
  'Ex.: Valorant, Riot, Epic...': 'E.g. Valorant, Riot, Epic...',
  'Campos Steam': 'Steam fields',
  'Todos são opcionais. O SteamID permite abrir e carregar dados públicos do perfil.': 'All fields are optional. SteamID lets you open and load public profile data.',
  'Todos são opcionais. Cole o link do perfil Steam para abrir e carregar dados públicos quando disponíveis.': 'All fields are optional. Paste the Steam profile link to open and load public data when available.',
  'SteamID64, STEAM_0:... ou vanity ID': 'SteamID64, STEAM_0:... or vanity ID',
  'https://steamcommunity.com/profiles/... ou /id/...':
      'https://steamcommunity.com/profiles/... or /id/...',
  'Ex.: 13K, 15K, 20K': 'E.g. 13K, 15K, 20K',
  'Segurança e recuperação': 'Security and recovery',
  'O score é um checklist de preparação e não garante que a conta não será comprometida.': 'The score is a preparedness checklist and does not guarantee that the account cannot be compromised.',
  'Senha do e-mail (opcional)': 'Email password (optional)',
  'Ocultar senha do e-mail': 'Hide email password',
  'Mostrar senha do e-mail': 'Show email password',
  'Campos personalizados': 'Custom fields',
  'Adicionar campo': 'Add field',
  'Você pode adicionar patente, mapa, e-mail, região, observação ou qualquer informação.':
      'You can add rank, map, email, region, notes, or any other information.',
  'Nome do campo': 'Field name',
  'Ex.: Patente Mirage': 'E.g. Mirage rank',
  'Valor': 'Value',
  'Remover campo': 'Remove field',
  'Mostrar este campo no dashboard': 'Show this field on dashboard',
  'Salvar alterações': 'Save changes',
  'Seu plano FREE nao possui vagas disponiveis.':
      'Your FREE plan has no available slots.',
  'Nenhuma conta selecionada para importar.':
      'No accounts selected for import.',
  'Nível': 'Level',
  'Nivel': 'Level',
  'Importar contas em massa': 'Bulk import accounts',
  'Importador inteligente local': 'Smart local importer',
  'O GamerLocker tenta reconhecer varios formatos. Revise a previa antes de importar. Login e senha permanecem neste computador.': 'GamerLocker tries to recognize multiple formats. Review the preview before importing. Login and password stay on this computer.',
  'O GamerLocker reconhece TAB, |, ;, virgula, rotulos, nivel, idade da conta e links de perfil Steam. Revise a previa antes de importar. Login e senha permanecem neste computador.': 'GamerLocker recognizes TAB, |, ;, commas, labels, level, account age, and Steam profile links. Review the preview before importing. Login and password stay on this computer.',
  'Outro': 'Other',
  'Ex.: Epic, Riot, Valorant...': 'E.g. Epic, Riot, Valorant...',
  'Cole suas contas': 'Paste your accounts',
  'login-senha-LV2\\nlogin|senha|LV1\\nlogin:senha\\nnome|login|senha|LV3\\n\\nou\\nLogin: conta01\\nSenha: senha123\\nNivel: LV2': 'login-password-LV2\\nlogin|password|LV1\\nlogin:password\\nname|login|password|LV3\\n\\nor\\nLogin: account01\\nPassword: password123\\nLevel: LV2',
  'login-senha-LV2\\nlogin|senha|LV1\\nlogin:senha\\nlogin<TAB>senha<TAB>6 anos<TAB>https://steamcommunity.com/profiles/...\\n\\nou\\nLogin: conta01\\nSenha: senha123\\nNivel: LV2\\nPerfil Steam: https://steamcommunity.com/id/...': 'login-password-LV2\\nlogin|password|LV1\\nlogin:password\\nlogin<TAB>password<TAB>6 years<TAB>https://steamcommunity.com/profiles/...\\n\\nor\\nLogin: account01\\nPassword: password123\\nLevel: LV2\\nSteam profile: https://steamcommunity.com/id/...',
  'Analisar': 'Analyze',
  'Nome opcional': 'Optional name',
  'Status': 'Status',
  'Cole o texto e clique em Analisar.': 'Paste the text and click Analyze.',
  'Nome (opcional)': 'Name (optional)',
  'Duplicada': 'Duplicate',
  'Selecionada': 'Selected',
  'Detectada': 'Detected',
  'Idade da conta': 'Account age',
  '6 anos': '6 years',
  'Exibir modo compacto': 'Show compact view',
  'Exibir em cards': 'Show card view',
  'Restaurar cofre': 'Restore vault',
  'Selecione um arquivo .sv exportado anteriormente pelo GamerLocker.':
      'Select a .sv file previously exported by GamerLocker.',
  'O arquivo continua criptografado. Depois da restauracao voce precisara da senha do cofre ou da Recovery Key.': 'The file remains encrypted. After restoration you will need the vault password or Recovery Key.',
  'Selecionar backup .sv': 'Select .sv backup',
  'Restaurar outro backup?': 'Restore another backup?',
  'O cofre atual sera preservado em uma copia de seguranca antes da restauracao. Depois sera necessario desbloquear o backup restaurado.': 'The current vault will be preserved in a safety copy before restoration. You will then need to unlock the restored backup.',
  'Continuar': 'Continue',
  'Restaurar backup automatico?': 'Restore automatic backup?',
  'Isso restaura a versao criptografada anterior do seu cofre.':
      'This restores the previous encrypted version of your vault.',
  'Restaurar': 'Restore',
  'Backup do cofre': 'Vault backup',
  'Os backups contem o cofre criptografado. Login, senha e demais dados nao sao exportados em texto puro.': 'Backups contain the encrypted vault. Login, password, and other data are not exported as plain text.',
  'Backup manual': 'Manual backup',
  'Gera um arquivo .sv que pode ser guardado em pendrive, Google Drive, OneDrive ou outro computador.': 'Creates a .sv file that can be stored on a USB drive, Google Drive, OneDrive, or another computer.',
  'Exportar backup .sv': 'Export .sv backup',
  'Backup local automatico': 'Automatic local backup',
  'Existe uma copia criptografada da versao anterior do cofre.':
      'An encrypted copy of the previous vault version exists.',
  'A copia automatica sera criada quando houver uma nova gravacao do cofre.':
      'The automatic copy will be created when the vault is saved again.',
  'Restaurar backup automatico': 'Restore automatic backup',
  'Restaurar arquivo': 'Restore file',
  'Substitui o cofre atual por outro arquivo .sv. Antes disso, o GamerLocker cria uma copia de seguranca do cofre atual.': 'Replaces the current vault with another .sv file. GamerLocker creates a safety copy of the current vault first.',
  'Restaurar outro .sv': 'Restore another .sv',
  'Arquivo local do cofre': 'Local vault file',
  'Plano': 'Plan',
  'Seu plano': 'Your plan',
  'Ativo': 'Active',
  'Limite FREE atingido.': 'FREE limit reached.',
  'Contas ilimitadas': 'Unlimited accounts',
  'GamerLocker PRO': 'GamerLocker PRO',
  'R\$ 29,90 / mês': 'R\$ 29.90 / month',
  'R\$ 29,90 / mes': 'R\$ 29.90 / month',
  'Backup criptografado na nuvem': 'Encrypted cloud backup',
  'Sincronização entre dispositivos': 'Sync across devices',
  'PC + celular + múltiplos dispositivos': 'PC + mobile + multiple devices',
  'Histórico de backups': 'Backup history',
  'PRO ativo': 'PRO active',
  'Assinar PRO': 'Get PRO',
  'Possui uma chave?': 'Have a key?',
  'Use chaves promocionais, de beta ou cortesia para ativar um período do PRO.':
      'Use promotional, beta, or courtesy keys to activate a PRO period.',
  'Ativar chave do produto': 'Activate product key',
  'Mesmo sem PRO, seus dados locais continuam acessíveis e podem ser exportados normalmente.': 'Even without PRO, your local data remains accessible and can be exported normally.',
  'Formato de chave invalido.': 'Invalid key format.',
  'Nao foi possivel ativar esta chave.': 'Could not activate this key.',
  'GamerLocker PRO ativado': 'GamerLocker PRO activated',
  'Ativar chave': 'Activate key',
  'Ativar GamerLocker PRO': 'Activate GamerLocker PRO',
  'Insira sua chave promocional ou de cortesia.':
      'Enter your promotional or courtesy key.',
  'Chave do produto': 'Product key',
  'Validar chave': 'Validate key',
  'A chave não será validada apenas pelo aplicativo. A ativação definitiva exigirá confirmação do servidor GamerLocker.': 'The key is not validated by the app alone. Final activation requires confirmation from the GamerLocker server.',
  'Informe e-mail e senha.': 'Enter email and password.',
  'Nao foi possivel entrar.': 'Could not sign in.',
  'Entre na sua conta GamerLocker': 'Sign in to your GamerLocker account',
  'Senha da conta': 'Account password',
  'Entrar': 'Sign in',
  'Criar conta': 'Create account',
  'A senha desta conta e separada da senha do seu cofre.':
      'This account password is separate from your vault password.',
  'Preencha todos os campos.': 'Fill in all fields.',
  'Use pelo menos 10 caracteres na senha.':
      'Use at least 10 characters in the password.',
  'As senhas nao coincidem.': 'The passwords do not match.',
  'Confirme seu e-mail': 'Confirm your email',
  'Nao foi possivel criar a conta.': 'Could not create the account.',
  'Criar conta GamerLocker': 'Create GamerLocker account',
  'Discord do Dippo copiado.': 'Dippo\'s Discord copied.',
  'No Android, a assinatura sera integrada ao Google Play antes da publicacao. Se sua conta ja possui PRO ativo, os beneficios continuam sendo reconhecidos normalmente.': 'On Android, subscriptions will be integrated with Google Play before release. If your account already has active PRO, the benefits continue to be recognized normally.',
  'Recursos premium': 'Premium features',
  'Cloud em breve': 'Cloud coming soon',
  'Sincronizacao em breve': 'Sync coming soon',
  'Adquirir o PRO no Windows': 'Get PRO on Windows',
  'Para adquirir o GamerLocker PRO, chame o Dippo diretamente no Discord. Confira o perfil oficial abaixo.': 'To get GamerLocker PRO, contact Dippo directly on Discord. Check the official profile below.',
  'Nao foi possivel carregar a imagem do contato do Discord.':
      'Could not load the Discord contact image.',
  'Copiar Discord do Dippo': 'Copy Dippo\'s Discord',
  'Como funciona a ativacao': 'How activation works',
  'Chame o Dippo no Discord.': 'Contact Dippo on Discord.',
  'Combine o pagamento e envie o comprovante diretamente por la.':
      'Arrange payment and send the receipt directly there.',
  'Depois da confirmacao, voce recebera sua Product Key PRO.':
      'After confirmation, you will receive your PRO Product Key.',
  'No GamerLocker, abra Plano > Ativar chave do produto e informe a key recebida.': 'In GamerLocker, open Plan > Activate product key and enter the key you received.',
  'Nunca envie senha do cofre, Recovery Key, senha de e-mail ou senha de alguma conta de jogo pelo Discord. Para ativar o PRO, voce so precisa tratar o pagamento e receber a Product Key.': 'Never send your vault password, Recovery Key, email password, or any game account password over Discord. To activate PRO, you only need to arrange payment and receive the Product Key.',
  'Nova versão disponível': 'New version available',
  'Uma atualização do GamerLocker está pronta para instalar.':
      'A GamerLocker update is ready to install.',
  'Seu cofre permanece no mesmo local durante a atualização.':
      'Your vault stays in the same location during the update.',
  'Agora não': 'Not now',
  'Atualizar': 'Update',
  'Atualizando GamerLocker': 'Updating GamerLocker',
  'Baixando...': 'Downloading...',
  'O GamerLocker será fechado, atualizado e aberto novamente.':
      'GamerLocker will be closed, updated, and reopened.',
  'Preparando instalação...': 'Preparing installation...',
  'Iniciando instalador...': 'Starting installer...',
  'Instalando atualização...': 'Installing update...',
  'Não foi possível atualizar': 'Could not update',
  'O GamerLocker continua funcionando normalmente.':
      'GamerLocker continues to work normally.',
  'Idioma': 'Language',
  'Idioma do GamerLocker': 'GamerLocker language',
  'Automático (sistema)': 'Automatic (system)',
  'Português (Brasil)': 'Português (Brasil)',
  'English (United States)': 'English (United States)',
  'Usar idioma do Windows': 'Use Windows language',
  'GamerLocker Store Edition': 'GamerLocker Store Edition',
  'Full Access local': 'Local Full Access',
  'Compra única pela Microsoft Store':
      'One-time purchase through Microsoft Store',
  'Esta edição libera permanentemente os recursos locais do GamerLocker neste produto da Microsoft Store.': 'This edition permanently unlocks GamerLocker\'s local features in this Microsoft Store product.',
  'Cofre local criptografado': 'Encrypted local vault',
  'Backup local criptografado': 'Encrypted local backup',
  'Importação em massa': 'Bulk import',
  'Recursos premium locais': 'Local premium features',
  'Cloud e sincronização não estão incluídos automaticamente e poderão ser oferecidos separadamente no futuro.': 'Cloud and sync are not automatically included and may be offered separately in the future.',
};

String gl(String text) {
  if (!GamerLockerLocale.isEnglish) {
    return text;
  }

  final exact = _english[text];

  if (exact != null) {
    return exact;
  }

  Match? match;

  match = RegExp(r'^Olá, (.+)$').firstMatch(text);
  if (match != null) {
    return 'Hello, ${match.group(1)}';
  }

  match = RegExp(r'^(\d+) conta(?:s)? no seu GamerLocker\.$').firstMatch(text);
  if (match != null) {
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    return '$count ${count == 1 ? 'account' : 'accounts'} in your GamerLocker.';
  }

  match = RegExp(r'^(\d+) conta(?:s)? importada(?:s)?\.$').firstMatch(text);
  if (match != null) {
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    return '$count ${count == 1 ? 'account imported' : 'accounts imported'}.';
  }

  match = RegExp(r'^Deseja excluir "(.+)"\?$').firstMatch(text);
  if (match != null) {
    return 'Delete "${match.group(1)}" ?'.replaceFirst('" ?', '"?');
  }

  match = RegExp(r'^Nenhuma conta encontrada para "(.+)"\.$').firstMatch(text);
  if (match != null) {
    return 'No accounts found for "${match.group(1)}".';
  }

  match = RegExp(r'^Resultados \((\d+)\)$').firstMatch(text);
  if (match != null) {
    return 'Results (${match.group(1)})';
  }

  match = RegExp(r'^Segurança (\d+)%$').firstMatch(text);
  if (match != null) {
    return 'Security ${match.group(1)}%';
  }

  match = RegExp(r'^(.+) copiado\. Clipboard será limpo em 30 segundos\.$')
      .firstMatch(text);
  if (match != null) {
    return '${gl(match.group(1) ?? '')} copied. The clipboard will be cleared in 30 seconds.';
  }

  match = RegExp(
    r'^Seu plano FREE permite importar no maximo (\d+) conta(?:s)? agora\.$',
  ).firstMatch(text);
  if (match != null) {
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    return 'Your FREE plan allows importing up to $count ${count == 1 ? 'account' : 'accounts'} now.';
  }

  match = RegExp(r'^FREE: (\d+)/(\d+) contas$').firstMatch(text);
  if (match != null) {
    return 'FREE: ${match.group(1)}/${match.group(2)} accounts';
  }

  match = RegExp(r'^(\d+) detectadas • (\d+) duplicadas$').firstMatch(text);
  if (match != null) {
    return '${match.group(1)} detected • ${match.group(2)} duplicates';
  }

  match = RegExp(r'^Importar (\d+) conta(?:s)?$').firstMatch(text);
  if (match != null) {
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    return 'Import $count ${count == 1 ? 'account' : 'accounts'}';
  }

  match = RegExp(r'^Backup "(.+)" restaurado\.$').firstMatch(text);
  if (match != null) {
    return 'Backup "${match.group(1)}" restored.';
  }

  match = RegExp(r'^Backup salvo em: (.+)$').firstMatch(text);
  if (match != null) {
    return 'Backup saved to: ${match.group(1)}';
  }

  match = RegExp(r'^(\d+) / (\d+) contas utilizadas$').firstMatch(text);
  if (match != null) {
    return '${match.group(1)} / ${match.group(2)} accounts used';
  }

  match = RegExp(r'^(\d+) contas restantes no plano FREE\.$').firstMatch(text);
  if (match != null) {
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    return '$count ${count == 1 ? 'account remaining' : 'accounts remaining'} on the FREE plan.';
  }

  match = RegExp(
    r'^(\d+) dias adicionados\.(.*)$',
    dotAll: true,
  ).firstMatch(text);
  if (match != null) {
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    var suffix = match.group(2) ?? '';
    suffix = suffix.replaceFirst('Valido ate:', 'Valid until:');
    return '$count ${count == 1 ? 'day added' : 'days added'}.$suffix';
  }

  match = RegExp(
    r'^Falha ao ativar chave: (.+)$',
    dotAll: true,
  ).firstMatch(text);
  if (match != null) {
    return 'Failed to activate key: ${match.group(1)}';
  }

  match = RegExp(
    r'^Enviamos uma confirmacao para (.+)\. Confirme o endereco e depois entre no GamerLocker\.$',
  ).firstMatch(text);
  if (match != null) {
    return 'We sent a confirmation to ${match.group(1)}. Confirm the address and then sign in to GamerLocker.';
  }

  match = RegExp(r'^Baixando GamerLocker (.+)\.\.\.$').firstMatch(text);
  if (match != null) {
    return 'Downloading GamerLocker ${match.group(1)}...';
  }

  match = RegExp(
    r'^O GamerLocker continua funcionando normalmente\.\n\nDetalhe: (.+)$',
    dotAll: true,
  ).firstMatch(text);
  if (match != null) {
    return 'GamerLocker continues to work normally.\n\nDetails: ${match.group(1)}';
  }

  return text;
}

class Text extends material.StatelessWidget {
  final String data;
  final material.TextStyle? style;
  final material.TextAlign? textAlign;
  final material.TextOverflow? overflow;
  final int? maxLines;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  @override
  material.Widget build(material.BuildContext context) {
    return material.Text(
      gl(data),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

class SelectableText extends material.StatelessWidget {
  final String data;
  final material.TextStyle? style;
  final material.TextAlign? textAlign;

  const SelectableText(this.data, {super.key, this.style, this.textAlign});

  @override
  material.Widget build(material.BuildContext context) {
    return material.SelectableText(
      gl(data),
      style: style,
      textAlign: textAlign,
    );
  }
}

Future<void> showGamerLockerLanguageDialog(
  material.BuildContext context,
) async {
  final selected = GamerLockerLocale.current.value;

  final value = await material.showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return material.AlertDialog(
        title: material.Text(gl('Idioma do GamerLocker')),
        content: material.Column(
          mainAxisSize: material.MainAxisSize.min,
          children: [
            material.RadioListTile<String>(
              value: 'system',
              groupValue: selected == null ? 'system' : selected.languageCode,
              title: material.Text(gl('Automático (sistema)')),
              subtitle: material.Text(gl('Usar idioma do Windows')),
              onChanged: (value) {
                material.Navigator.of(dialogContext).pop(value);
              },
            ),
            material.RadioListTile<String>(
              value: 'pt',
              groupValue: selected == null ? 'system' : selected.languageCode,
              title: const material.Text('Português (Brasil)'),
              onChanged: (value) {
                material.Navigator.of(dialogContext).pop(value);
              },
            ),
            material.RadioListTile<String>(
              value: 'en',
              groupValue: selected == null ? 'system' : selected.languageCode,
              title: const material.Text('English (United States)'),
              onChanged: (value) {
                material.Navigator.of(dialogContext).pop(value);
              },
            ),
          ],
        ),
        actions: [
          material.TextButton(
            onPressed: () {
              material.Navigator.of(dialogContext).pop();
            },
            child: material.Text(gl('Cancelar')),
          ),
        ],
      );
    },
  );

  if (value != null) {
    await GamerLockerLocale.setLanguage(value);
  }
}
