# Cooldown temporario do CS2 - GamerLocker

Implementacao adicionada nesta versao:

- `lib/steam_cooldown_service.dart`: localiza e executa o helper do Steam GC e interpreta o JSON.
- `lib/main.dart`: adiciona o card/status "Cooldown CS2" no dashboard e nos detalhes da conta.
- `tools/steam_gc_helper/`: helper C#/.NET usando SteamKit2 para autenticar localmente, marcar o AppID 730 como ativo, abrir sessao com o GC e solicitar a mensagem 9110.
- `windows/CMakeLists.txt`: inclui o helper publicado no bundle Windows/MSIX.

## Antes de compilar o GamerLocker

No PowerShell, na raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\steam_gc_helper\build.ps1
```

O script requer .NET 8 SDK, publica o helper como executavel self-contained e o copia para `windows/steam_gc_helper`.

Depois use seu fluxo normal Flutter/MSIX.

## Fluxo no app

1. A conta precisa ser do tipo Steam e ter `Perfil Steam`/`SteamID` para o bloco aparecer.
2. Para consultar o GC, os campos `Login` e `Senha` precisam estar preenchidos.
3. Clique em `Verificar`.
4. Se o Steam Guard for solicitado, o app abre uma caixa para inserir o codigo.
5. O app mostra sem cooldown, cooldown ativo e tempo restante, ou o erro retornado.

## Privacidade

O helper recebe usuario/senha apenas via stdin do processo local. Esta implementacao nao envia as credenciais para Supabase e o helper nao as grava em arquivo.
