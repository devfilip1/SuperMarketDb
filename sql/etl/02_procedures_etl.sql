-- =====================================================================
-- Entrega 2 - ETL em PL/pgSQL: OLTP (public) -> staging (stg) -> DW (dw)
--
--   CALL etl.executar();   -- roda tudo: extrai, transforma, carrega o
--                          -- estrela, carrega o floco e valida
--
-- Requisitos do enunciado (item 4.3.2) e onde estao:
--   area de staging ............ etl.extrair()       -> esquema stg
--   tratamento de nulos ........ etl.transformar()   -> 'Não informado' / 'NI'
--   padronizacao de textos ..... etl.transformar()   -> espacos, maiusculas, UF
--   geracao da dimensao Tempo .. etl.carregar_tempo()
--   chaves substitutas ......... SERIAL nas dimensoes + lookup na fato
--   SCD tipo 2 ................. etl.carregar_dim_cliente() (cidade/estado)
--   medida derivada ............ valor_total = quantidade x preco_unitario
--   carga incremental .......... marca d'agua etl.controle.ultimo_item_venda_id
--   contagens antes/depois ..... etl.log_carga + etl.validar()
-- =====================================================================
SET client_encoding = 'UTF8';

-- ---------------------------------------------------------------------
-- Registro no log
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.registrar(
    p_exec INTEGER, p_etapa TEXT, p_tabela TEXT,
    p_antes BIGINT, p_depois BIGINT,
    p_inseridas BIGINT DEFAULT NULL, p_atualizadas BIGINT DEFAULT NULL,
    p_obs TEXT DEFAULT NULL)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO etl.log_carga (execucao_id, etapa, tabela, linhas_antes, linhas_depois, inseridas, atualizadas, observacao)
    VALUES (p_exec, p_etapa, p_tabela, p_antes, p_depois, p_inseridas, p_atualizadas, p_obs);
    RAISE NOTICE '% | % | antes=% depois=% inseridas=% atualizadas=% %',
        rpad(p_etapa, 13), rpad(p_tabela, 26), p_antes, p_depois,
        COALESCE(p_inseridas::TEXT, '-'), COALESCE(p_atualizadas::TEXT, '-'), COALESCE(p_obs, '');
END $$;

-- ---------------------------------------------------------------------
-- 1. EXTRACAO: OLTP -> staging (copia sem transformar)
-- Cadastros sao extraidos inteiros (sao pequenos); itens de venda so os
-- novos, a partir da marca d'agua (carga incremental).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.extrair(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_ultimo BIGINT;
    v_n      BIGINT;
BEGIN
    TRUNCATE stg.cliente, stg.produto, stg.loja, stg.item_venda;

    INSERT INTO stg.cliente
    SELECT p.id, p.nome, p.cpf, p.cidade, p.estado, c.cartao_fidelidade_id IS NOT NULL, clock_timestamp()
    FROM public.pessoa p
    JOIN public.cliente c ON c.id = p.id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'EXTRACAO', 'stg.cliente', 0, v_n, v_n);

    INSERT INTO stg.produto
    SELECT p.id, p.nome, p.preco, c.nome, clock_timestamp()
    FROM public.produto p
    LEFT JOIN public.categoria c ON c.id = p.categoria_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'EXTRACAO', 'stg.produto', 0, v_n, v_n);

    INSERT INTO stg.loja
    SELECT l.id, l.nome, l.cidade, l.estado, clock_timestamp()
    FROM public.loja l;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'EXTRACAO', 'stg.loja', 0, v_n, v_n);

    SELECT valor INTO v_ultimo FROM etl.controle WHERE chave = 'ultimo_item_venda_id';

    INSERT INTO stg.item_venda
    SELECT i.id, v.id, v.data_hora, v.cliente_id, v.loja_id, v.forma_pagamento,
           i.produto_id, i.quantidade, i.preco_unitario, clock_timestamp()
    FROM public.item_venda i
    JOIN public.venda v ON v.id = i.venda_id
    WHERE i.id > v_ultimo;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'EXTRACAO', 'stg.item_venda', 0, v_n, v_n, NULL,
                       format('itens com id > %s (marca d''agua)', v_ultimo));
END $$;

-- ---------------------------------------------------------------------
-- 2. TRANSFORMACAO (na staging): nulos, espacos, maiusculas, UF
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.transformar(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_nulos BIGINT;
    v_n     BIGINT;
BEGIN
    -- Clientes
    SELECT COUNT(*) INTO v_nulos FROM stg.cliente
    WHERE etl.limpar(nome) IS NULL OR etl.limpar(cidade) IS NULL OR etl.limpar(estado) IS NULL;

    UPDATE stg.cliente
    SET nome          = etl.nome_proprio(nome),
        cpf           = COALESCE(regexp_replace(cpf, '\D', '', 'g'), '00000000000'),
        cidade        = etl.nome_proprio(cidade),
        estado        = etl.uf(estado),
        possui_cartao = COALESCE(possui_cartao, false);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'TRANSFORMACAO', 'stg.cliente', v_n, v_n, NULL, v_n,
                       format('%s com nulo tratado; nome/cidade em Initcap, UF maiuscula', v_nulos));

    -- Produtos
    SELECT COUNT(*) INTO v_nulos FROM stg.produto
    WHERE etl.limpar(nome) IS NULL OR etl.limpar(categoria) IS NULL;

    UPDATE stg.produto
    SET nome      = etl.texto(nome),
        categoria = etl.nome_proprio(categoria);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'TRANSFORMACAO', 'stg.produto', v_n, v_n, NULL, v_n,
                       format('%s com nulo tratado', v_nulos));

    -- Lojas
    SELECT COUNT(*) INTO v_nulos FROM stg.loja
    WHERE etl.limpar(cidade) IS NULL OR etl.limpar(estado) IS NULL;

    UPDATE stg.loja
    SET nome   = etl.texto(nome),
        cidade = etl.nome_proprio(cidade),
        estado = etl.uf(estado);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CALL etl.registrar(p_exec, 'TRANSFORMACAO', 'stg.loja', v_n, v_n, NULL, v_n,
                       format('%s com nulo tratado', v_nulos));

    -- Itens: forma de pagamento padronizada; itens invalidos sao descartados
    UPDATE stg.item_venda SET forma_pagamento = COALESCE(upper(etl.limpar(forma_pagamento)), 'NI');

    DELETE FROM stg.item_venda
    WHERE quantidade IS NULL OR quantidade <= 0 OR preco_unitario IS NULL OR preco_unitario < 0;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    SELECT COUNT(*) INTO v_nulos FROM stg.item_venda;
    CALL etl.registrar(p_exec, 'TRANSFORMACAO', 'stg.item_venda', v_nulos + v_n, v_nulos,
                       NULL, NULL, format('%s itens descartados (quantidade/preco invalido)', v_n));
END $$;

-- ---------------------------------------------------------------------
-- 3a. Dimensao TEMPO: gera todos os dias dos anos que tem venda
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.carregar_tempo(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_antes BIGINT;
    v_n     BIGINT := 0;
    v_ini   DATE;
    v_fim   DATE;
BEGIN
    SELECT COUNT(*) INTO v_antes FROM dw.dim_tempo;
    SELECT date_trunc('year', MIN(data_hora))::DATE,
           (date_trunc('year', MAX(data_hora)) + INTERVAL '1 year - 1 day')::DATE
    INTO v_ini, v_fim
    FROM stg.item_venda;

    IF v_ini IS NOT NULL THEN
        INSERT INTO dw.dim_tempo
        SELECT to_char(d, 'YYYYMMDD')::INTEGER,
               d,
               EXTRACT(DAY FROM d),
               EXTRACT(MONTH FROM d),
               (ARRAY['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
                      'Agosto','Setembro','Outubro','Novembro','Dezembro'])[EXTRACT(MONTH FROM d)],
               EXTRACT(QUARTER FROM d),
               CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END,
               EXTRACT(YEAR FROM d),
               (ARRAY['Domingo','Segunda-feira','Terça-feira','Quarta-feira',
                      'Quinta-feira','Sexta-feira','Sábado'])[EXTRACT(DOW FROM d) + 1],
               EXTRACT(DOW FROM d) + 1,
               EXTRACT(DOW FROM d) IN (0, 6)
        FROM generate_series(v_ini, v_fim, INTERVAL '1 day') AS g (d)
        ON CONFLICT (sk_tempo) DO NOTHING;
        GET DIAGNOSTICS v_n = ROW_COUNT;
    END IF;

    CALL etl.registrar(p_exec, 'CARGA', 'dw.dim_tempo', v_antes, v_antes + v_n, v_n, 0,
                       format('periodo %s a %s', v_ini, v_fim));
END $$;

-- ---------------------------------------------------------------------
-- 3b. Dimensoes PRODUTO, LOJA e PAGAMENTO (SCD tipo 1: sobrescreve)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.carregar_dimensoes_tipo1(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_antes BIGINT;
    v_ins   BIGINT;
    v_upd   BIGINT;
BEGIN
    -- Produto
    SELECT COUNT(*) INTO v_antes FROM dw.dim_produto;
    UPDATE dw.dim_produto d
    SET nome = s.nome, categoria = s.categoria, preco_atual = s.preco
    FROM stg.produto s
    WHERE d.id_origem = s.id_origem
      AND (d.nome, d.categoria, d.preco_atual) IS DISTINCT FROM (s.nome, s.categoria, s.preco);
    GET DIAGNOSTICS v_upd = ROW_COUNT;
    INSERT INTO dw.dim_produto (id_origem, nome, categoria, preco_atual)
    SELECT s.id_origem, s.nome, s.categoria, s.preco
    FROM stg.produto s
    WHERE NOT EXISTS (SELECT 1 FROM dw.dim_produto d WHERE d.id_origem = s.id_origem);
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA', 'dw.dim_produto', v_antes, v_antes + v_ins, v_ins, v_upd);

    -- Loja
    SELECT COUNT(*) INTO v_antes FROM dw.dim_loja;
    UPDATE dw.dim_loja d
    SET nome = s.nome, cidade = s.cidade, estado = s.estado
    FROM stg.loja s
    WHERE d.id_origem = s.id_origem
      AND (d.nome, d.cidade, d.estado) IS DISTINCT FROM (s.nome, s.cidade, s.estado::CHAR(2));
    GET DIAGNOSTICS v_upd = ROW_COUNT;
    INSERT INTO dw.dim_loja (id_origem, nome, cidade, estado)
    SELECT s.id_origem, s.nome, s.cidade, s.estado
    FROM stg.loja s
    WHERE NOT EXISTS (SELECT 1 FROM dw.dim_loja d WHERE d.id_origem = s.id_origem);
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA', 'dw.dim_loja', v_antes, v_antes + v_ins, v_ins, v_upd);

    -- Forma de pagamento (valores do enum FormaPagamento)
    SELECT COUNT(*) INTO v_antes FROM dw.dim_pagamento;
    INSERT INTO dw.dim_pagamento (codigo, descricao, eletronico)
    SELECT DISTINCT s.forma_pagamento,
           CASE s.forma_pagamento
               WHEN 'DINHEIRO' THEN 'Dinheiro'
               WHEN 'DEBITO'   THEN 'Cartão de débito'
               WHEN 'CREDITO'  THEN 'Cartão de crédito'
               WHEN 'PIX'      THEN 'Pix'
               ELSE initcap(s.forma_pagamento)
           END,
           s.forma_pagamento <> 'DINHEIRO'
    FROM stg.item_venda s
    WHERE s.forma_pagamento <> 'NI'
      AND NOT EXISTS (SELECT 1 FROM dw.dim_pagamento d WHERE d.codigo = s.forma_pagamento);
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    CALL etl.registrar(p_exec, 'CARGA', 'dw.dim_pagamento', v_antes, v_antes + v_ins, v_ins, 0);
END $$;

-- ---------------------------------------------------------------------
-- 3c. Dimensao CLIENTE com SCD TIPO 2
--   * mudou cidade/estado -> fecha a versao atual (data_fim = hoje,
--     atual = false) e cria uma nova versao (nova sk_cliente);
--   * nome, CPF e cartao fidelidade sao tipo 1 (corrigidos em todas as versoes);
--   * cliente novo -> versao 1, vigente desde 1900-01-01.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.carregar_dim_cliente(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_hoje   DATE := current_date;
    v_antes  BIGINT;
    v_tipo1  BIGINT;
    v_scd2   BIGINT;
    v_novos  BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_antes FROM dw.dim_cliente;

    -- Tipo 1
    UPDATE dw.dim_cliente d
    SET nome = s.nome, cpf = s.cpf, possui_cartao = s.possui_cartao
    FROM stg.cliente s
    WHERE d.id_origem = s.id_origem
      AND (d.nome, d.cpf, d.possui_cartao) IS DISTINCT FROM (s.nome, s.cpf, s.possui_cartao);
    GET DIAGNOSTICS v_tipo1 = ROW_COUNT;

    -- Tipo 2: fecha a versao antiga e abre a nova no mesmo comando
    WITH fechadas AS (
        UPDATE dw.dim_cliente d
        SET data_fim = v_hoje, atual = false
        FROM stg.cliente s
        WHERE d.atual
          AND d.id_origem = s.id_origem
          AND (d.cidade, d.estado) IS DISTINCT FROM (s.cidade, s.estado::CHAR(2))
        RETURNING d.id_origem, d.versao
    )
    INSERT INTO dw.dim_cliente (id_origem, nome, cpf, cidade, estado, possui_cartao,
                                data_inicio, data_fim, atual, versao)
    SELECT s.id_origem, s.nome, s.cpf, s.cidade, s.estado, s.possui_cartao,
           v_hoje, DATE '9999-12-31', true, f.versao + 1
    FROM fechadas f
    JOIN stg.cliente s ON s.id_origem = f.id_origem;
    GET DIAGNOSTICS v_scd2 = ROW_COUNT;

    -- Clientes novos
    INSERT INTO dw.dim_cliente (id_origem, nome, cpf, cidade, estado, possui_cartao,
                                data_inicio, data_fim, atual, versao)
    SELECT s.id_origem, s.nome, s.cpf, s.cidade, s.estado, s.possui_cartao,
           DATE '1900-01-01', DATE '9999-12-31', true, 1
    FROM stg.cliente s
    WHERE NOT EXISTS (SELECT 1 FROM dw.dim_cliente d WHERE d.id_origem = s.id_origem);
    GET DIAGNOSTICS v_novos = ROW_COUNT;

    CALL etl.registrar(p_exec, 'CARGA', 'dw.dim_cliente', v_antes, v_antes + v_scd2 + v_novos,
                       v_scd2 + v_novos, v_tipo1,
                       format('%s clientes novos; %s novas versoes SCD2 (mudanca de cidade)', v_novos, v_scd2));
END $$;

-- ---------------------------------------------------------------------
-- 3d. FATO: troca chaves naturais por chaves substitutas e calcula a
-- medida derivada. Para o cliente, usa a versao vigente na DATA DA VENDA.
-- Chave nao encontrada -> membro 0 ('Não informado').
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.carregar_fato(p_exec INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_antes BIGINT;
    v_n     BIGINT;
    v_sem   BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_antes FROM dw.fato_venda;

    INSERT INTO dw.fato_venda (sk_tempo, sk_produto, sk_cliente, sk_loja, sk_pagamento,
                               numero_cupom, id_item_origem, hora,
                               quantidade, preco_unitario, valor_total)
    SELECT COALESCE(t.sk_tempo, 0),
           COALESCE(p.sk_produto, 0),
           COALESCE(cv.sk_cliente, ca.sk_cliente, 0),
           COALESCE(l.sk_loja, 0),
           COALESCE(pg.sk_pagamento, 0),
           s.id_venda,
           s.id_item,
           EXTRACT(HOUR FROM s.data_hora),
           s.quantidade,
           s.preco_unitario,
           ROUND(s.quantidade * s.preco_unitario, 2)          -- medida derivada
    FROM stg.item_venda s
    LEFT JOIN dw.dim_tempo     t  ON t.data = s.data_hora::DATE
    LEFT JOIN dw.dim_produto   p  ON p.id_origem = s.produto_id
    LEFT JOIN dw.dim_cliente   cv ON cv.id_origem = s.cliente_id
                                 AND s.data_hora::DATE >= cv.data_inicio
                                 AND s.data_hora::DATE <  cv.data_fim
    LEFT JOIN dw.dim_cliente   ca ON ca.id_origem = s.cliente_id AND ca.atual
    LEFT JOIN dw.dim_loja      l  ON l.id_origem = s.loja_id
    LEFT JOIN dw.dim_pagamento pg ON pg.codigo = s.forma_pagamento
    ON CONFLICT (id_item_origem) DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    SELECT COUNT(*) INTO v_sem FROM dw.fato_venda
    WHERE 0 IN (sk_tempo, sk_produto, sk_cliente, sk_loja, sk_pagamento);

    -- avanca a marca d'agua
    UPDATE etl.controle
    SET valor = GREATEST(valor, COALESCE((SELECT MAX(id_item) FROM stg.item_venda), 0))
    WHERE chave = 'ultimo_item_venda_id';

    CALL etl.registrar(p_exec, 'CARGA', 'dw.fato_venda', v_antes, v_antes + v_n, v_n, 0,
                       format('%s linhas apontam para membro Não informado', v_sem));
END $$;

-- ---------------------------------------------------------------------
-- 4. VALIDACAO: total do OLTP = total do estrela = total do floco
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.validar(p_exec INTEGER, INOUT p_ok BOOLEAN DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    o_qtd BIGINT; o_val NUMERIC;
    e_qtd BIGINT; e_val NUMERIC;
    f_qtd BIGINT; f_val NUMERIC;
BEGIN
    SELECT COUNT(*), COALESCE(SUM(quantidade * preco_unitario), 0) INTO o_qtd, o_val FROM public.item_venda;
    SELECT COUNT(*), COALESCE(SUM(valor_total), 0) INTO e_qtd, e_val FROM dw.fato_venda;
    SELECT COUNT(*), COALESCE(SUM(valor_total), 0) INTO f_qtd, f_val FROM dw_floco.fato_venda;

    p_ok := (o_qtd = e_qtd AND e_qtd = f_qtd AND o_val = e_val AND e_val = f_val);

    CALL etl.registrar(p_exec, 'VALIDACAO', 'public.item_venda', NULL, o_qtd, NULL, NULL, format('valor total R$ %s', o_val));
    CALL etl.registrar(p_exec, 'VALIDACAO', 'dw.fato_venda',      NULL, e_qtd, NULL, NULL, format('valor total R$ %s', e_val));
    CALL etl.registrar(p_exec, 'VALIDACAO', 'dw_floco.fato_venda', NULL, f_qtd, NULL, NULL, format('valor total R$ %s', f_val));
    CALL etl.registrar(p_exec, 'VALIDACAO', 'resultado', NULL, NULL, NULL, NULL,
                       CASE WHEN p_ok THEN 'OK: OLTP, estrela e floco batem' ELSE 'DIVERGENCIA entre OLTP e DW' END);
END $$;

-- ---------------------------------------------------------------------
-- Orquestrador: e o que o script sql/etl/rodar_etl.sql chama
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE etl.executar()
LANGUAGE plpgsql AS $$
DECLARE
    v_exec INTEGER;
    v_tipo TEXT;
    v_ok   BOOLEAN;
BEGIN
    v_tipo := CASE WHEN (SELECT valor FROM etl.controle WHERE chave = 'ultimo_item_venda_id') = 0
                   THEN 'INICIAL' ELSE 'INCREMENTAL' END;
    INSERT INTO etl.execucao (inicio, tipo, status) VALUES (clock_timestamp(), v_tipo, 'EM ANDAMENTO')
    RETURNING id INTO v_exec;
    RAISE NOTICE '=== Execucao % do ETL (carga %) ===', v_exec, v_tipo;

    CALL etl.extrair(v_exec);
    CALL etl.transformar(v_exec);
    CALL etl.carregar_tempo(v_exec);
    CALL etl.carregar_dimensoes_tipo1(v_exec);
    CALL etl.carregar_dim_cliente(v_exec);
    CALL etl.carregar_fato(v_exec);
    CALL etl.carregar_floco(v_exec);          -- sql/dw/03_carga_floco.sql
    CALL etl.validar(v_exec, v_ok);

    UPDATE etl.execucao
    SET fim = clock_timestamp(), status = CASE WHEN v_ok THEN 'OK' ELSE 'DIVERGENTE' END
    WHERE id = v_exec;
END $$;
