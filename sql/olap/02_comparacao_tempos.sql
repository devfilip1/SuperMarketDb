-- =====================================================================
-- Entrega 3 - Mesma consulta no OLTP, no ESTRELA e no FLOCO DE NEVE
-- Pergunta: "Qual foi o faturamento de cada categoria, por UF da loja, em 2025?"
--
--   psql -U postgres -d supermercado -f sql/olap/02_comparacao_tempos.sql
--
-- O script mineracao/medir_tempos.py roda cada versao 30 vezes e usa a
-- mediana do "Execution Time" do EXPLAIN ANALYZE (tabela no README da entrega 3).
-- =====================================================================
SET client_encoding = 'UTF8';
\pset pager off

\echo '=== OLTP (public): 4 junções ==='
EXPLAIN (ANALYZE, COSTS OFF, TIMING ON)
SELECT c.nome AS categoria, l.estado AS uf, SUM(i.quantidade * i.preco_unitario) AS faturamento
FROM public.item_venda i
JOIN public.venda     v ON v.id = i.venda_id
JOIN public.produto   p ON p.id = i.produto_id
JOIN public.categoria c ON c.id = p.categoria_id
JOIN public.loja      l ON l.id = v.loja_id
WHERE v.data_hora >= DATE '2025-01-01' AND v.data_hora < DATE '2026-01-01'
GROUP BY c.nome, l.estado;

\echo '=== ESTRELA (dw): 3 junções ==='
EXPLAIN (ANALYZE, COSTS OFF, TIMING ON)
SELECT p.categoria, l.estado AS uf, SUM(f.valor_total) AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_tempo   t ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
JOIN dw.dim_loja    l ON l.sk_loja = f.sk_loja
WHERE t.ano = 2025
GROUP BY p.categoria, l.estado;

\echo '=== FLOCO DE NEVE (dw_floco): 6 junções ==='
EXPLAIN (ANALYZE, COSTS OFF, TIMING ON)
SELECT c.nome AS categoria, e.sigla AS uf, SUM(f.valor_total) AS faturamento
FROM dw_floco.fato_venda f
JOIN dw_floco.dim_tempo     t  ON t.sk_tempo = f.sk_tempo
JOIN dw_floco.dim_produto   p  ON p.sk_produto = f.sk_produto
JOIN dw_floco.dim_categoria c  ON c.sk_categoria = p.sk_categoria
JOIN dw_floco.dim_loja      l  ON l.sk_loja = f.sk_loja
JOIN dw_floco.dim_cidade    ci ON ci.sk_cidade = l.sk_cidade
JOIN dw_floco.dim_estado    e  ON e.sk_estado = ci.sk_estado
WHERE t.ano = 2025
GROUP BY c.nome, e.sigla;
