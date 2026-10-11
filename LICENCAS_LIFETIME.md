# Lifetime e soma de keys

Execute generated_keys/ativar_licencas_e_3_lifetime.sql no SQL Editor do Supabase.
Esse arquivo troca as funcoes de licenca e cadastra as mesmas tres keys lifetime.
A migracao separada esta em supabase/migrations/202610110002_licenses_v2.sql.

Licencas e keys antigas deixam de ser reconhecidas pelo app; suas tabelas
permanecem no banco para consulta. Essa troca foi autorizada. Dependencias
inesperadas impedem a alteracao inteira: nao usamos CASCADE.

Para gerar novos lotes, use tools/generate_product_keys.ps1 -Count 3 -Lifetime
ou -Count 2 -Days 30. Execute o SQL gerado para cadastrar cada lote. Gerar
arquivos localmente nao cadastra keys no servidor. Reexecutar o cadastro nao
reseta o uso de uma key. Os arquivos TXT sao privados e ignorados pelo Git.

Cada key pode ser usada uma unica vez. Keys temporarias somam dias ao prazo
existente; se venceu, contam a partir do resgate. Duas keys de 30 dias
acrescentam 60 dias. Lifetime nao tem vencimento. Uma conta lifetime nao
consome outra key: o resgate e recusado e a key fica disponivel.

O servidor bloqueia conta e key durante a transacao para impedir perda de saldo
ou uso duplicado em resgates simultaneos. Keys sao armazenadas como SHA-256.
Usuarios nao podem ler ou alterar diretamente as tabelas de keys e licencas.

A tela permite ativar outra key sem sair, mostra dias restantes arredondados
para cima, data de vencimento ou PRO vitalicio. O contador atualiza a cada
minuto. A autorizacao vem do servidor; o app nao soma dias localmente.

Validacao: deno run --allow-all tools/license_database_test.ts e flutter test.
O teste SQL executa a migracao em PostgreSQL via PGlite e valida soma, uso unico
entre contas, lifetime, renovacao e permissoes. auth.uid() e simulado no teste;
a migracao ainda precisa ser aplicada e conferida no Supabase de producao.

Convites para atualizacoes privadas continuam separados das licencas:
uma key PRO nao cadastra automaticamente a conta em private_update_access.
