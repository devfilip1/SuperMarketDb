-- =====================================================================
-- Entrega 2 - Modelo ESTRELA (esquema dw)
-- Assunto: venda de produtos por cupom fiscal
-- Granularidade da fato: UM ITEM VENDIDO EM UM CUPOM FISCAL
--   (uma linha de dw.fato_venda = uma linha de item_venda do OLTP)
-- =====================================================================

SET client_encoding = 'UTF8';

DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;

-- ---------------------------------------------------------------------
-- Dimensao Tempo (gerada pelo ETL, nao vem do OLTP)
-- sk_tempo no formato AAAAMMDD (ex.: 20261019). 0 = data nao informada.
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_tempo (
    sk_tempo         INTEGER     PRIMARY KEY,
    data             DATE        NOT NULL UNIQUE,
    dia              SMALLINT    NOT NULL,
    mes              SMALLINT    NOT NULL,
    nome_mes         VARCHAR(15) NOT NULL,
    trimestre        SMALLINT    NOT NULL,
    semestre         SMALLINT    NOT NULL,
    ano              SMALLINT    NOT NULL,
    dia_semana       VARCHAR(15) NOT NULL,
    num_dia_semana   SMALLINT    NOT NULL,          -- 1 = domingo ... 7 = sabado
    fim_de_semana    BOOLEAN     NOT NULL
);

-- ---------------------------------------------------------------------
-- Dimensao Produto (SCD tipo 1: nome, categoria e preco sao sobrescritos)
-- Categoria fica DESNORMALIZADA aqui (no floco de neve vira tabela propria)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_produto (
    sk_produto   SERIAL         PRIMARY KEY,         -- chave substituta
    id_origem    BIGINT         NOT NULL UNIQUE,     -- chave natural (produto.id)
    nome         VARCHAR(120)   NOT NULL,
    categoria    VARCHAR(60)    NOT NULL,
    preco_atual  NUMERIC(10, 2)
);

-- ---------------------------------------------------------------------
-- Dimensao Cliente (SCD tipo 2 em cidade/estado)
-- Cada mudanca de cidade gera uma NOVA linha (nova sk_cliente);
-- a linha antiga recebe data_fim e atual = false.
-- Vigencia: [data_inicio, data_fim)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_cliente (
    sk_cliente     SERIAL       PRIMARY KEY,         -- chave substituta
    id_origem      BIGINT       NOT NULL,            -- chave natural (pessoa.id)
    nome           VARCHAR(120) NOT NULL,
    cpf            VARCHAR(11)  NOT NULL,
    cidade         VARCHAR(60)  NOT NULL,
    estado         CHAR(2)      NOT NULL,
    possui_cartao  BOOLEAN      NOT NULL,
    data_inicio    DATE         NOT NULL,
    data_fim       DATE         NOT NULL,
    atual          BOOLEAN      NOT NULL,
    versao         SMALLINT     NOT NULL
);
CREATE UNIQUE INDEX ux_dim_cliente_atual ON dw.dim_cliente (id_origem) WHERE atual;
CREATE INDEX ix_dim_cliente_origem ON dw.dim_cliente (id_origem, data_inicio, data_fim);

-- ---------------------------------------------------------------------
-- Dimensao Loja (SCD tipo 1)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_loja (
    sk_loja    SERIAL      PRIMARY KEY,
    id_origem  BIGINT      NOT NULL UNIQUE,
    nome       VARCHAR(80) NOT NULL,
    cidade     VARCHAR(60) NOT NULL,
    estado     CHAR(2)     NOT NULL
);

-- ---------------------------------------------------------------------
-- Dimensao Forma de Pagamento (enum FormaPagamento do OLTP)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_pagamento (
    sk_pagamento  SERIAL      PRIMARY KEY,
    codigo        VARCHAR(10) NOT NULL UNIQUE,
    descricao     VARCHAR(30) NOT NULL,
    eletronico    BOOLEAN     NOT NULL
);

-- ---------------------------------------------------------------------
-- Tabela FATO
-- Medidas: quantidade (aditiva), preco_unitario (nao aditiva),
--          valor_total = quantidade x preco_unitario (aditiva, DERIVADA no ETL)
-- numero_cupom: dimensao degenerada (id da venda no OLTP)
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_venda (
    sk_tempo        INTEGER        NOT NULL REFERENCES dw.dim_tempo (sk_tempo),
    sk_produto      INTEGER        NOT NULL REFERENCES dw.dim_produto (sk_produto),
    sk_cliente      INTEGER        NOT NULL REFERENCES dw.dim_cliente (sk_cliente),
    sk_loja         INTEGER        NOT NULL REFERENCES dw.dim_loja (sk_loja),
    sk_pagamento    INTEGER        NOT NULL REFERENCES dw.dim_pagamento (sk_pagamento),
    numero_cupom    BIGINT         NOT NULL,
    id_item_origem  BIGINT         NOT NULL UNIQUE,  -- item_venda.id (controle da carga incremental)
    hora            SMALLINT       NOT NULL,
    quantidade      INTEGER        NOT NULL,
    preco_unitario  NUMERIC(10, 2) NOT NULL,
    valor_total     NUMERIC(12, 2) NOT NULL
);
CREATE INDEX ix_fato_tempo   ON dw.fato_venda (sk_tempo);
CREATE INDEX ix_fato_produto ON dw.fato_venda (sk_produto);
CREATE INDEX ix_fato_cliente ON dw.fato_venda (sk_cliente);
CREATE INDEX ix_fato_loja    ON dw.fato_venda (sk_loja);

-- ---------------------------------------------------------------------
-- Membros "Não informado" (sk = 0): usados quando a chave nao e encontrada
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_tempo VALUES (0, DATE '1900-01-01', 0, 0, 'Não informado', 0, 0, 0, 'Não informado', 0, false);
INSERT INTO dw.dim_produto (sk_produto, id_origem, nome, categoria) VALUES (0, -1, 'Não informado', 'Não informado');
INSERT INTO dw.dim_cliente (sk_cliente, id_origem, nome, cpf, cidade, estado, possui_cartao, data_inicio, data_fim, atual, versao)
VALUES (0, -1, 'Não informado', '00000000000', 'Não informado', 'NI', false, DATE '1900-01-01', DATE '9999-12-31', true, 1);
INSERT INTO dw.dim_loja (sk_loja, id_origem, nome, cidade, estado) VALUES (0, -1, 'Não informado', 'Não informado', 'NI');
INSERT INTO dw.dim_pagamento (sk_pagamento, codigo, descricao, eletronico) VALUES (0, 'NI', 'Não informado', false);
