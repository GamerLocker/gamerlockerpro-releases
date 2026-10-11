# Classificacao CS2

A leitura preparada utiliza o nivel CS2 do campo 17 do snapshot de conta e
o estado Prime do objeto de conta tipo 7, campo 14 (valor 5 para Prime comprado)
ou o bit 16 do campo 13 (Prime legado), quando
retornado no cache pertencente ao SteamID autenticado. Campo ausente ou
estado nao reconhecido permanece nulo. O nivel Steam nao participa dessa leitura.

Na validacao atual, tres sessoes reais retornaram cooldown/VAC e estados Prime
verdadeiro/falso. O nivel CS2 nao foi retornado nessas consultas e permanece
nao confirmado. Prime ausente ou estado desconhecido nao e presumido como falso.

Nao ha nesta implementacao uma fonte validada para confirmar acesso ao
competitivo de contas sem Prime. Portanto, a tela exibe "Competitivo: nao
confirmado" somente para contas confirmadas como sem Prime. Ausencia de
cooldown, horas jogadas, nivel Steam ou nivel de XP
nao sao transformados em confirmacao desse acesso.

A regra desejada e classificar como "nivel 2" do app uma conta sem Prime com
acesso competitivo confirmado, mantendo separado o nivel oficial CS2. Essa
classificacao automatica ainda depende de encontrar e validar sua fonte.
Nao enviamos mensagens para iniciar matchmaking para tentar descobrir isso.

O helper aceita a aprovacao pelo celular e transmite esse progresso ao app.
Se nao houver aprovacao em ate 45 segundos, oferece o codigo como alternativa.
Os dialogos de codigo possuem controladores gerenciados pelo ciclo de vida
do widget, incluindo a animacao de fechamento. A versao 0.1.17 inclui essas
correcoes; a confirmacao automatica de acesso competitivo continua pendente.
