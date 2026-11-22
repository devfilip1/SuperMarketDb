-- =====================================================================
-- Entrega 3 - Consultas OLAP no modelo ESTRELA (esquema dw)
-- 2 consultas para cada operacao: roll-up, drill-down, slice, dice, pivot.
-- Cada consulta responde a uma pergunta de negocio do supermercado.
--
--   psql -U postgres -d supermercado -f sql/olap/01_consultas_olap.sql
--
-- Nas consultas com ROLLUP/CUBE/GROUPING SETS, as linhas de subtotal
-- aparecem com o rotulo 'TOTAL' (funcao GROUPING()).
-- =====================================================================
SET client_encoding = 'UTF8';
\pset pager off
\pset null '-'

-- =====================================================================
-- ROLL-UP: sobe na hierarquia, agregando (detalhe -> total)
-- =====================================================================

\echo '=== R1 (roll-up no Tempo) Como o faturamento evolui por ano, trimestre e mes, com subtotais? ==='
SELECT CASE WHEN GROUPING(t.ano) = 1 THEN 'TOTAL GERAL' ELSE t.ano::TEXT END            AS ano,
       CASE WHEN GROUPING(t.trimestre) = 1 THEN 'TOTAL' ELSE t.trimestre::TEXT || 'º tri' END AS trimestre,
       CASE WHEN GROUPING(t.mes) = 1 THEN 'TOTAL' ELSE t.nome_mes END                   AS mes,
       COUNT(DISTINCT f.numero_cupom)                                                     AS cupons,
       SUM(f.valor_total)                                                                 AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo
GROUP BY ROLLUP (t.ano, t.trimestre, (t.mes, t.nome_mes))
ORDER BY t.ano NULLS LAST, t.trimestre NULLS LAST, t.mes NULLS LAST;

\echo '=== R2 (roll-up na Geografia) Quanto cada loja fatura, somando por cidade, por estado e no total? ==='
SELECT CASE WHEN GROUPING(l.estado) = 1 THEN 'TOTAL GERAL' ELSE l.estado END AS uf,
       CASE WHEN GROUPING(l.cidade) = 1 THEN 'TOTAL' ELSE l.cidade END       AS cidade,
       CASE WHEN GROUPING(l.nome) = 1 THEN 'TOTAL' ELSE l.nome END           AS loja,
       SUM(f.quantidade)                                                     AS itens,
       SUM(f.valor_total)                                                    AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY ROLLUP (l.estado, l.cidade, l.nome)
ORDER BY l.estado NULLS LAST, l.cidade NULLS LAST, l.nome NULLS LAST;

-- =====================================================================
-- DRILL-DOWN: desce na hierarquia, detalhando (total -> detalhe)
-- =====================================================================

\echo '=== D1 (drill-down no Tempo) Em 2025: total do ano -> semestre -> mes (GROUPING SETS) ==='
SELECT CASE WHEN GROUPING(t.semestre) = 1 THEN 'ANO 2025' ELSE t.semestre::TEXT || 'º semestre' END AS nivel_semestre,
       CASE WHEN GROUPING(t.mes) = 1 THEN '-' ELSE t.nome_mes END AS mes,
       COUNT(DISTINCT f.numero_cupom) AS cupons,
       SUM(f.valor_total) AS faturamento,
       ROUND(SUM(f.valor_total) / COUNT(DISTINCT f.numero_cupom), 2) AS ticket_medio
FROM dw.fato_venda f
JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo
WHERE t.ano = 2025
GROUP BY GROUPING SETS ((), (t.semestre), (t.semestre, t.mes, t.nome_mes))
ORDER BY t.semestre NULLS FIRST, t.mes NULLS FIRST;

\echo '=== D2 (drill-down no Produto) Quanto fatura cada categoria? Descendo de Bebidas ate o produto ==='
SELECT CASE WHEN GROUPING(p.categoria) = 1 THEN 'TOTAL GERAL' ELSE p.categoria END AS categoria,
       CASE WHEN GROUPING(p.nome) = 1 THEN 'TOTAL DA CATEGORIA' ELSE p.nome END AS produto,
       SUM(f.quantidade) AS unidades,
       SUM(f.valor_total) AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
GROUP BY GROUPING SETS ((), (p.categoria), (p.categoria, p.nome))
HAVING GROUPING(p.categoria) = 1                       -- total geral
    OR GROUPING(p.nome) = 1                            -- nivel categoria (todas)
    OR p.categoria = 'Bebidas'                         -- detalhe so de Bebidas
ORDER BY GROUPING(p.categoria) DESC, GROUPING(p.nome) DESC, faturamento DESC;

-- =====================================================================
-- SLICE: fixa UMA dimensao em um valor e analisa as demais
-- =====================================================================

\echo '=== S1 (slice Tempo: ano = 2025) Em 2025, quanto cada loja vendeu de cada categoria? ==='
SELECT l.nome AS loja, p.categoria, SUM(f.valor_total) AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_tempo   t ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_loja    l ON l.sk_loja = f.sk_loja
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
WHERE t.ano = 2025
GROUP BY l.nome, p.categoria
ORDER BY l.nome, faturamento DESC;

\echo '=== S2 (slice Pagamento: Pix) Como o uso do Pix evoluiu por trimestre? ==='
SELECT t.ano, t.trimestre,
       COUNT(DISTINCT f.numero_cupom) AS cupons_pix,
       SUM(f.valor_total) AS faturamento_pix
FROM dw.fato_venda f
JOIN dw.dim_tempo     t  ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_pagamento pg ON pg.sk_pagamento = f.sk_pagamento
WHERE pg.codigo = 'PIX'
GROUP BY t.ano, t.trimestre
ORDER BY t.ano, t.trimestre;

-- =====================================================================
-- DICE: restringe VARIAS dimensoes ao mesmo tempo (subcubo)
-- =====================================================================

\echo '=== Di1 (dice) Lojas do RN x categorias Acougue e Bebidas x 2º semestre de 2025: quem vende mais? ==='
SELECT l.nome AS loja, p.categoria, SUM(f.quantidade) AS unidades, SUM(f.valor_total) AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_tempo   t ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_loja    l ON l.sk_loja = f.sk_loja
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
WHERE l.estado = 'RN'
  AND p.categoria IN ('Acougue', 'Bebidas')
  AND t.ano = 2025 AND t.semestre = 2
GROUP BY l.nome, p.categoria
ORDER BY p.categoria, faturamento DESC;

\echo '=== Di2 (dice) Clientes COM cartao fidelidade, no fim de semana, em 2026: como pagam? (CUBE) ==='
SELECT CASE WHEN GROUPING(pg.descricao) = 1 THEN 'TOTAL' ELSE pg.descricao END AS forma_pagamento,
       CASE WHEN GROUPING(t.dia_semana) = 1 THEN 'TOTAL' ELSE t.dia_semana END AS dia,
       COUNT(DISTINCT f.numero_cupom) AS cupons,
       SUM(f.valor_total) AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_tempo     t  ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_cliente   c  ON c.sk_cliente = f.sk_cliente
JOIN dw.dim_pagamento pg ON pg.sk_pagamento = f.sk_pagamento
WHERE c.possui_cartao
  AND t.fim_de_semana
  AND t.ano = 2026
GROUP BY CUBE (pg.descricao, t.dia_semana)
ORDER BY GROUPING(pg.descricao), pg.descricao, GROUPING(t.dia_semana), t.dia_semana;

-- =====================================================================
-- PIVOT: gira o cubo, transformando valores de uma dimensao em colunas
-- =====================================================================

\echo '=== P1 (pivot) Faturamento de cada categoria (linhas) por ano (colunas). Obs.: 2024 = nov-dez; 2026 = jan-nov ==='
SELECT p.categoria,
       SUM(f.valor_total) FILTER (WHERE t.ano = 2024) AS "2024",
       SUM(f.valor_total) FILTER (WHERE t.ano = 2025) AS "2025",
       SUM(f.valor_total) FILTER (WHERE t.ano = 2026) AS "2026",
       SUM(f.valor_total)                              AS total
FROM dw.fato_venda f
JOIN dw.dim_tempo   t ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
GROUP BY p.categoria
ORDER BY total DESC;

\echo '=== P2 (pivot) Participacao (%) de cada forma de pagamento (colunas) em cada loja (linhas) ==='
SELECT l.nome AS loja,
       ROUND(100.0 * SUM(f.valor_total) FILTER (WHERE pg.codigo = 'DINHEIRO') / SUM(f.valor_total), 1) AS "Dinheiro %",
       ROUND(100.0 * SUM(f.valor_total) FILTER (WHERE pg.codigo = 'DEBITO')   / SUM(f.valor_total), 1) AS "Debito %",
       ROUND(100.0 * SUM(f.valor_total) FILTER (WHERE pg.codigo = 'CREDITO')  / SUM(f.valor_total), 1) AS "Credito %",
       ROUND(100.0 * SUM(f.valor_total) FILTER (WHERE pg.codigo = 'PIX')      / SUM(f.valor_total), 1) AS "Pix %",
       SUM(f.valor_total) AS faturamento
FROM dw.fato_venda f
JOIN dw.dim_loja      l  ON l.sk_loja = f.sk_loja
JOIN dw.dim_pagamento pg ON pg.sk_pagamento = f.sk_pagamento
GROUP BY l.nome
ORDER BY faturamento DESC;
