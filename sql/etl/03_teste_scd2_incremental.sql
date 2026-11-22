-- =====================================================================
-- Teste do ETL: SCD tipo 2, carga incremental, nulos e padronizacao.
-- ATENCAO: altera o OLTP (public). Rode so no banco de teste, depois de
-- sql/instalar_dw.sql.
--
--   psql -U bd2 -d supermercado -f sql/etl/03_teste_scd2_incremental.sql
--
-- O que o teste faz no OLTP:
--   1. o cliente de menor id muda de cidade, digitada "suja": '  recife ' / 'pe'
--   2. um cliente novo e cadastrado SEM cidade e SEM UF (nulos)
--   3. uma venda nova (hoje) com 2 itens e feita pelo cliente que mudou
-- Depois roda o ETL de novo e mostra o resultado no DW.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET client_min_messages = warning;

BEGIN;

SELECT MIN(c.id) AS cliente_teste FROM public.cliente c \gset

\echo '--- ANTES: versoes do cliente de teste em dw.dim_cliente ---'
SELECT sk_cliente, id_origem, nome, cidade, estado, versao, data_inicio, data_fim, atual
FROM dw.dim_cliente WHERE id_origem = :cliente_teste ORDER BY versao;

-- 1. mudanca de cidade (texto com espacos e minusculas de proposito)
UPDATE public.pessoa SET cidade = '  recife ', estado = 'pe' WHERE id = :cliente_teste;

-- 2. cliente novo com nulos
WITH p AS (
    INSERT INTO public.pessoa (nome, cpf, logradouro, cidade, estado)
    VALUES ('  joana   teste da silva ', '99988877766', NULL, NULL, NULL)
    RETURNING id
)
INSERT INTO public.cliente (id) SELECT id FROM p;

-- 3. venda nova com 2 itens
WITH v AS (
    INSERT INTO public.venda (data_hora, cliente_id, loja_id, funcionario_id, forma_pagamento)
    SELECT date_trunc('minute', LOCALTIMESTAMP), :cliente_teste,
           (SELECT MIN(id) FROM public.loja), (SELECT MIN(id) FROM public.funcionario), 'PIX'
    RETURNING id
)
INSERT INTO public.item_venda (venda_id, produto_id, quantidade, preco_unitario)
SELECT v.id, p.id, 2, p.preco
FROM v CROSS JOIN (SELECT id, preco FROM public.produto ORDER BY id LIMIT 2) p;

COMMIT;

\echo ''
\echo '--- Rodando o ETL de novo (incremental) ---'
CALL etl.executar();

SELECT etapa, tabela, linhas_antes AS antes, linhas_depois AS depois, inseridas, atualizadas, observacao
FROM etl.log_carga
WHERE execucao_id = (SELECT MAX(id) FROM etl.execucao)
  AND (etapa IN ('VALIDACAO') OR tabela IN ('stg.item_venda', 'dw.dim_cliente', 'dw.fato_venda'))
ORDER BY id;

\echo '--- DEPOIS: SCD2 -> versao antiga fechada e versao nova em Recife/PE ---'
SELECT sk_cliente, id_origem, nome, cidade, estado, versao, data_inicio, data_fim, atual
FROM dw.dim_cliente WHERE id_origem = :cliente_teste ORDER BY versao;

\echo '--- Vendas do cliente por versao (antigas na v1, a nova na v2) ---'
SELECT d.versao, d.cidade, COUNT(DISTINCT f.numero_cupom) AS cupons, SUM(f.valor_total) AS valor
FROM dw.fato_venda f JOIN dw.dim_cliente d ON d.sk_cliente = f.sk_cliente
WHERE d.id_origem = :cliente_teste
GROUP BY d.versao, d.cidade ORDER BY d.versao;

\echo '--- Cliente novo: nulos viraram Não informado / NI, nome padronizado ---'
SELECT sk_cliente, nome, cidade, estado, possui_cartao, versao
FROM dw.dim_cliente WHERE cpf = '99988877766';
