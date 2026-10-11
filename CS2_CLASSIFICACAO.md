# Classificacao CS2

A leitura preparada utiliza o nivel CS2 do campo 17 do snapshot de conta e
o estado Prime do objeto de conta tipo 7, campo 14, quando explicitamente
retornado no cache pertencente ao SteamID autenticado. Campo ausente ou
estado nao reconhecido permanece nulo. O nivel Steam nao participa dessa leitura.

Nas duas sessoes reais consultadas, o GC retornou cooldown/VAC, mas nao retornou
os campos de nivel CS2 ou Prime. Esses estados permanecem nao confirmados.

Nao ha nesta implementacao uma fonte validada para confirmar acesso ao
competitivo de contas sem Prime. Portanto, a tela exibe "Competitivo: nao
confirmado". Ausencia de cooldown, horas jogadas, nivel Steam ou nivel de XP
nao sao transformados em confirmacao desse acesso.

A regra desejada e classificar como "nivel 2" do app uma conta sem Prime com
acesso competitivo confirmado, mantendo separado o nivel oficial CS2. Essa
classificacao automatica ainda depende de encontrar e validar sua fonte.
Nao enviamos mensagens para iniciar matchmaking para tentar descobrir isso.

As alteracoes foram testadas localmente; nao ha novo instalador/release para
essa classificacao enquanto sua confirmacao automatica permanece pendente.
