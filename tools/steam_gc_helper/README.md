# GamerLocker Steam GC Helper

Componente local do Windows usado para consultar o cooldown temporario do CS2 sem abrir a interface do jogo.

## Build

No PowerShell, na raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\steam_gc_helper\build.ps1
```

O script publica um executavel self-contained e copia o resultado para `windows/steam_gc_helper`.
Depois, gere o GamerLocker normalmente (`flutter build windows` / MSIX).

As credenciais sao recebidas via stdin do processo local e nao sao gravadas pelo helper.

A consulta usa ClientHello 2000244 com launcher 0, como o ZIP fornecido.
O status da conta autenticada e lido primeiro de `game_data2` (campo 6)
da resposta ClientWelcome 4004, usando o formato de MatchmakingGC2ClientHello.
O account_id deve corresponder a conta autenticada. Isto foi validado no GC
real com duas contas, ambas retornando cooldown de varios dias sem mensagem 9110.
Dados ausentes, invalidos ou de outra conta mantem o fallback por retries de
matchmaking, resposta 9110 e notificacao 9118. Nao usa o perfil publico 9128
para deduzir ausencia de cooldown.

A autenticacao cria uma sessao persistente e salva refresh token e GuardData
por conta em `%LOCALAPPDATA%/GamerLocker/steam_sessions`. Os arquivos .bin sao
protegidos por Windows DPAPI para o usuario Windows atual, com nomes derivados
do hash do login. Senha e codigos Steam Guard nao sao gravados pelo helper.
As consultas seguintes usam o token salvo diretamente, inclusive apos reiniciar
o app. A sessao e salva quando o login Steam e aceito, mesmo se o GC falhar depois.

Tokens recusados/expirados/revogados acionam nova autenticacao, reutilizando
GuardData quando disponivel. A Steam ainda pode exigir um novo codigo nesses
casos. Falhas de rede, rate limit e timeout do GC nao invalidam a sessao.
TryAnotherCM solicita ate duas reconexoes sem descartar o token salvo.
O helper usa um LoginID aleatorio proprio por processo para nao colidir com
a sessao do cliente Steam aberto na mesma maquina.
Falha ao salvar a sessao gera um aviso na interface. Excluir os arquivos desta
pasta esquece as sessoes locais (nao revoga os tokens na Steam).

Testes de protobuf, persistencia DPAPI e politica de autenticacao (Windows,
sem login ou acesso ao GC, com tokens ficticios):

```powershell
dotnet run --project tools/steam_gc_helper_protocol_tests/ProtocolTests.csproj -c Release
```

Para validar no GC real somente as sessoes .bin ja salvas (sem senha, nova
autenticacao ou alteracao dos tokens), depois de compilar o helper:

```powershell
powershell -ExecutionPolicy Bypass -File tools/steam_gc_helper/probe-saved-sessions.ps1
```

O botao Verificar envia `joinGamerLockerGroup: true`: depois do login, o helper
usa a conexao CM autenticada para obter cookies temporarios e entra no grupo
GamerLocker (account ID 46564927, SteamID64 103582791476086335). Uma pagina
com o botao de sair confirma a participacao; contas ja participantes nao
enviam nova solicitacao de entrada. O resultado do grupo aparece separado
do cooldown, e uma falha no grupo nao transforma um cooldown valido em erro.
A sessao CM fica aberta ate a acao terminar, com limite de 12 segundos.
Nenhum cookie ou access token web e gravado ou retornado na interface.

O helper solicita os dados de persona da propria conta autenticada e retorna
SteamID64, nome publico e URL da foto derivada do AvatarHash. O app associa
esses dados ao perfil da conta verificada, atualiza a foto imediatamente e
salva somente os metadados publicos em `steam_profiles.json` na pasta
`%LOCALAPPDATA%/GamerLocker`. As consultas publicas seguintes usam o SteamID64
confirmado. Uma consulta publica antiga em andamento nao pode substituir
a foto recem-recebida da conta autenticada.

Validacao real de entrada no grupo, somente quando esta acao for desejada:

```powershell
powershell -ExecutionPolicy Bypass -File tools/steam_gc_helper/probe-saved-sessions.ps1 -JoinGamerLockerGroup
```
