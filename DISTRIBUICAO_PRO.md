# Distribuicao Pro

O canal Pro consulta exclusivamente os releases de
`GamerLocker/gamerlockerpro-releases`. O canal padrao continua consultando
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

O atualizador atual consulta o GitHub sem autenticacao. Um repositorio publico
permite baixar seus releases a qualquer pessoa com acesso ao endereco. Para
restringir de fato a distribuicao, sera necessario um repositorio privado com
acesso individual ou um servico de atualizacao autenticado; nunca embutir um
token GitHub compartilhado no aplicativo.
