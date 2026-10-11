# Distribuicao Pro

O canal Pro consulta a funcao Supabase `private-updates`, que le os releases
privados de `GamerLocker/gamerlockerpro-releases`. O canal padrao continua consultando
`GamerLocker/gamerlocker-releases`.

Para gerar o instalador Pro no Windows com Flutter, Visual Studio, .NET SDK e
Inno Setup instalados:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_gamerlocker_installer.ps1 -Channel pro
```

Configure localmente `config/dev.json` com `SUPABASE_URL` e
`SUPABASE_PUBLISHABLE_KEY`. Esse arquivo nao e versionado. Nunca use uma chave
Supabase de servico no cliente.

O instalador fica em `dist/pro/GamerLocker-Setup-v<versao>-windows-x64.exe`.
Para publicar uma atualizacao, aumente a versao em `pubspec.yaml`, gere o
instalador e anexe o EXE a um release com tag `v<versao>` no repositorio Pro.
O atualizador identifica arquivos com prefixo `GamerLocker-Setup-`.

Esta separacao define a origem das atualizacoes. O instalador mantem a identidade
e a pasta de instalacao do GamerLocker: instalar o canal Pro substitui a edicao
existente e preserva o cofre. Nao instala uma segunda copia lado a lado.

## Ativacao do servidor

1. Torne o repositorio GitHub privado antes de enviar codigo ou instaladores.
2. Execute `supabase/migrations/202610110001_private_updates.sql` no SQL Editor
   do projeto Supabase usado pelo app.
3. Crie um token GitHub fine-grained restrito a esse repositorio com permissao
   **Contents: Read-only**. Se a organizacao exigir aprovacao, aprove o token.
4. No Supabase, salve o token como secret `GITHUB_RELEASES_TOKEN`. Nunca coloque
   esse valor em `config/dev.json`, no Git, no instalador ou no chat.
5. Publique a funcao `supabase/functions/private-updates/index.ts`. Pela CLI:

```powershell
supabase login
supabase link --project-ref xroizpdhbsejstjqxlub
supabase functions deploy private-updates --no-verify-jwt
```

`verify_jwt=false` desliga apenas a verificacao do gateway: a funcao valida a
sessao com `/auth/v1/user` em **todas** as consultas e downloads. Ela consulta a
tabela com a sessao do usuario e RLS; nao usa plano ou permissao do cliente.

## Convidados

No SQL Editor, autorize uma conta ja cadastrada pelo email:

```sql
insert into public.private_update_access (user_id, expires_at)
select id, null from auth.users where lower(email) = lower('convidado@example.com')
on conflict (user_id) do update set expires_at = excluded.expires_at;
```

`null` permite acesso sem prazo. Para revogar:

```sql
delete from public.private_update_access
where user_id in (select id from auth.users where lower(email) = lower('convidado@example.com'));
```

O app verifica atualizacoes ao iniciar com sessao salva ou apos o login. Apenas
convidados ativos recebem dados de releases. O download tambem verifica o acesso;
o token GitHub permanece no servidor. A funcao transmite o arquivo sem expor a
URL temporaria do GitHub. O app confere o SHA-256 informado pelo GitHub antes de
executar. Releases sem digest SHA-256 nao sao oferecidos no canal Pro.

Para validar em producao, publique uma versao maior que a instalada e confirme:
convidado recebe e instala a atualizacao; conta sem convite nao recebe;
revogar o convite impede um novo download. Valide isso antes de distribuir.

O controle restringe novos downloads. Ele nao revoga um instalador ja baixado
nem impede um convidado de repassar uma copia.
