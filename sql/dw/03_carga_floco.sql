-- =====================================================================
-- Entrega 2 - Carga do modelo FLOCO DE NEVE (dw_floco)
--
-- Roda no fim de cada execucao do ETL (chamada por etl.executar()).
-- Le os dados ja limpos e padronizados (staging -> dimensoes do estrela)
-- e os NORMALIZA: separa categoria, cidade e estado em tabelas proprias.
-- Tambem e incremental: so insere o que ainda nao existe no floco.
-- =====================================================================
SET client_encoding = 'UTF8';

CREATE OR REPLACE PROCEDURE etl.carregar_floco(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_antes BIGINT;
    v_ins   BIGINT;
    v_upd   BIGINT;
BEGIN
    -- Tempo (mesma estrutura do estrela)
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_tempo;
    INSERT INTO dw_floco.dim_tempo
    SELECT * FROM dw.dim_tempo
    ON CONFLICT (sk_tempo) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_tempo', v_antes, v_antes + v_ins, v_ins, 0);

    -- Estado (de clientes e lojas)
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_estado;
    INSERT INTO dw_floco.dim_estado (sigla, nome, regiao)
    SELECT u.estado, (etl.nome_estado(u.estado)).nome, (etl.nome_estado(u.estado)).regiao
    FROM (SELECT estado FROM dw.dim_cliente UNION SELECT estado FROM dw.dim_loja) u
    ON CONFLICT (sigla) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_estado', v_antes, v_antes + v_ins, v_ins, 0);

    -- Cidade -> Estado
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_cidade;
    INSERT INTO dw_floco.dim_cidade (nome, sk_estado)
    SELECT u.cidade, e.sk_estado
    FROM (SELECT cidade, estado FROM dw.dim_cliente UNION SELECT cidade, estado FROM dw.dim_loja) u
    JOIN dw_floco.dim_estado e ON e.sigla = u.estado
    ON CONFLICT (nome, sk_estado) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_cidade', v_antes, v_antes + v_ins, v_ins, 0);

    -- Categoria
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_categoria;
    INSERT INTO dw_floco.dim_categoria (nome)
    SELECT DISTINCT categoria FROM dw.dim_produto
    ON CONFLICT (nome) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_categoria', v_antes, v_antes + v_ins, v_ins, 0);

    -- Produto -> Categoria
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_produto;
    INSERT INTO dw_floco.dim_produto (sk_produto, id_origem, nome, preco_atual, sk_categoria)
    SELECT p.sk_produto, p.id_origem, p.nome, p.preco_atual, c.sk_categoria
    FROM dw.dim_produto p
    JOIN dw_floco.dim_categoria c ON c.nome = p.categoria
    ON CONFLICT (sk_produto) DO UPDATE
        SET nome = EXCLUDED.nome, preco_atual = EXCLUDED.preco_atual, sk_categoria = EXCLUDED.sk_categoria
        WHERE (dw_floco.dim_produto.nome, dw_floco.dim_produto.preco_atual, dw_floco.dim_produto.sk_categoria)
              IS DISTINCT FROM (EXCLUDED.nome, EXCLUDED.preco_atual, EXCLUDED.sk_categoria);
    GET DIAGNOSTICS v_upd = ROW_COUNT;
    v_ins := (SELECT COUNT(*) FROM dw_floco.dim_produto) - v_antes;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_produto', v_antes, v_antes + v_ins, v_ins, v_upd - v_ins);

    -- Loja -> Cidade
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_loja;
    INSERT INTO dw_floco.dim_loja (sk_loja, id_origem, nome, sk_cidade)
    SELECT l.sk_loja, l.id_origem, l.nome, ci.sk_cidade
    FROM dw.dim_loja l
    JOIN dw_floco.dim_estado e  ON e.sigla = l.estado
    JOIN dw_floco.dim_cidade ci ON ci.nome = l.cidade AND ci.sk_estado = e.sk_estado
    ON CONFLICT (sk_loja) DO UPDATE
        SET nome = EXCLUDED.nome, sk_cidade = EXCLUDED.sk_cidade
        WHERE (dw_floco.dim_loja.nome, dw_floco.dim_loja.sk_cidade)
              IS DISTINCT FROM (EXCLUDED.nome, EXCLUDED.sk_cidade);
    GET DIAGNOSTICS v_upd = ROW_COUNT;
    v_ins := (SELECT COUNT(*) FROM dw_floco.dim_loja) - v_antes;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_loja', v_antes, v_antes + v_ins, v_ins, v_upd - v_ins);

    -- Cliente -> Cidade (copia as versoes SCD2 do estrela, com as mesmas SKs)
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_cliente;
    INSERT INTO dw_floco.dim_cliente (sk_cliente, id_origem, nome, cpf, possui_cartao, sk_cidade,
                                      data_inicio, data_fim, atual, versao)
    SELECT c.sk_cliente, c.id_origem, c.nome, c.cpf, c.possui_cartao, ci.sk_cidade,
           c.data_inicio, c.data_fim, c.atual, c.versao
    FROM dw.dim_cliente c
    JOIN dw_floco.dim_estado e  ON e.sigla = c.estado
    JOIN dw_floco.dim_cidade ci ON ci.nome = c.cidade AND ci.sk_estado = e.sk_estado
    ON CONFLICT (sk_cliente) DO UPDATE
        SET nome = EXCLUDED.nome, cpf = EXCLUDED.cpf, possui_cartao = EXCLUDED.possui_cartao,
            data_fim = EXCLUDED.data_fim, atual = EXCLUDED.atual
        WHERE (dw_floco.dim_cliente.nome, dw_floco.dim_cliente.cpf, dw_floco.dim_cliente.possui_cartao,
               dw_floco.dim_cliente.data_fim, dw_floco.dim_cliente.atual)
              IS DISTINCT FROM (EXCLUDED.nome, EXCLUDED.cpf, EXCLUDED.possui_cartao, EXCLUDED.data_fim, EXCLUDED.atual);
    GET DIAGNOSTICS v_upd = ROW_COUNT;
    v_ins := (SELECT COUNT(*) FROM dw_floco.dim_cliente) - v_antes;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_cliente', v_antes, v_antes + v_ins, v_ins, v_upd - v_ins);

    -- Pagamento
    SELECT COUNT(*) INTO v_antes FROM dw_floco.dim_pagamento;
    INSERT INTO dw_floco.dim_pagamento
    SELECT sk_pagamento, codigo, descricao, eletronico FROM dw.dim_pagamento
    ON CONFLICT (sk_pagamento) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.dim_pagamento', v_antes, v_antes + v_ins, v_ins, 0);

    -- Fato (incremental: so itens que ainda nao estao no floco)
    SELECT COUNT(*) INTO v_antes FROM dw_floco.fato_venda;
    INSERT INTO dw_floco.fato_venda
    SELECT f.sk_tempo, f.sk_produto, f.sk_cliente, f.sk_loja, f.sk_pagamento,
           f.numero_cupom, f.id_item_origem, f.hora, f.quantidade, f.preco_unitario, f.valor_total
    FROM dw.fato_venda f
    WHERE f.id_item_origem > (SELECT COALESCE(MAX(id_item_origem), 0) FROM dw_floco.fato_venda);
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA FLOCO', 'dw_floco.fato_venda', v_antes, v_antes + v_ins, v_ins, 0);
END $$;
