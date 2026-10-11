# Dados da conta Steam

Abra a conta no GamerLocker e clique em "Dados Steam" no topo. A consulta
comeca automaticamente e utiliza o login/senha ou a sessao Steam Guard salva.
Nao exige Perfil Steam preenchido e nao entra em jogos para coletar esses dados.

Abas:

- Resumo: SteamID, foto, nome, nivel, criacao quando retornada, total de jogos,
  horas de CS2/CS:GO e tempo nas ultimas duas semanas.
- Jogos: biblioteca retornada pela sessao autenticada, incluindo jogos gratuitos,
  busca por nome e horas por jogo. Nao exige Web API key no aplicativo.
- Insignias e medalhas: insignias Steam e medalhas/moedas identificadas nos itens
  do inventario CS2. Nao sao conquistas de jogo ou uma consulta de todas as
  estatisticas do GC.
- Inventario: CS2, Dota 2, Team Fortress 2 ou Comunidade Steam. Outros jogos e
  contextos de inventario nao estao implementados nesta versao.

Inventarios sao paginados, ate 30 paginas por consulta e prazo de 22 segundos.
Se o limite/prazo for atingido, os itens ja recebidos ficam visiveis e a consulta
e marcada incompleta. Inventario privado, limitado ou com falha nao e mostrado
como vazio. As insignias sao as retornadas pela pagina de insignias consultada.

Atualizar permite repetir a consulta; selecionar outro inventario faz uma nova
consulta autenticada. Dados detalhados ficam em memoria, sem gravar cookies,
tokens, biblioteca ou inventario em arquivos de cache desprotegidos. A consulta
nao negocia, vende, transfere itens ou altera a privacidade da conta.

Validacao: biblioteca, horas, nivel e insignias retornaram em duas sessoes
reais salvas. Inventario nao ficou disponivel nessas duas consultas; parsing,
medalhas e interface foram validados com fixtures. A interface informa essa
limitacao sem inventar itens ou presumir que a conta nao os tem.
