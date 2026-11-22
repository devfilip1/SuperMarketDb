-- =====================================================================
-- Reexecuta o ETL (carga incremental) e mostra o log da execucao.
-- E o script usado na demonstracao: cadastrar algo pela aplicacao JPA,
-- rodar este script e consultar o registro novo no DW.
--
--   psql -U bd2 -d supermercado -f sql/etl/rodar_etl.sql
-- =====================================================================
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET client_min_messages = warning;   -- o log completo fica em etl.log_carga

CALL etl.executar();

\echo ''
\echo '--- Execucao ---'
SELECT id, tipo, status, inicio::TIMESTAMP(0) AS inicio, (fim - inicio) AS duracao
FROM etl.execucao ORDER BY id DESC LIMIT 1;

\echo '--- Contagens antes e depois (etl.log_carga) ---'
SELECT etapa, tabela, linhas_antes AS antes, linhas_depois AS depois,
       inseridas, atualizadas, observacao
FROM etl.log_carga
WHERE execucao_id = (SELECT MAX(id) FROM etl.execucao)
ORDER BY id;
