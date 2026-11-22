-- =====================================================================
-- Entrega 2 - Modelo FLOCO DE NEVE (esquema dw_floco)
-- Mesmo assunto e mesma granularidade do estrela (um item por cupom).
-- Dimensoes normalizadas:
--   Produto -> Categoria
--   Loja    -> Cidade -> Estado
--   Cliente -> Cidade -> Estado
-- As chaves substitutas de produto, cliente, loja e pagamento sao as
-- mesmas do estrela, para que as duas fatos sejam comparaveis linha a linha.
-- =====================================================================

SET client_encoding = 'UTF8';

DROP SCHEMA IF EXISTS dw_floco CASCADE;
CREATE SCHEMA dw_floco;

CREATE TABLE dw_floco.dim_tempo (
    sk_tempo         INTEGER     PRIMARY KEY,
    data             DATE        NOT NULL UNIQUE,
    dia              SMALLINT    NOT NULL,
    mes              SMALLINT    NOT NULL,
    nome_mes         VARCHAR(15) NOT NULL,
    trimestre        SMALLINT    NOT NULL,
    semestre         SMALLINT    NOT NULL,
    ano              SMALLINT    NOT NULL,
    dia_semana       VARCHAR(15) NOT NULL,
    num_dia_semana   SMALLINT    NOT NULL,
    fim_de_semana    BOOLEAN     NOT NULL
);

-- ---------------- Geografia: Estado <- Cidade ----------------
CREATE TABLE dw_floco.dim_estado (
    sk_estado  SERIAL      PRIMARY KEY,
    sigla      CHAR(2)     NOT NULL UNIQUE,
    nome       VARCHAR(40) NOT NULL,
    regiao     VARCHAR(20) NOT NULL
);

CREATE TABLE dw_floco.dim_cidade (
    sk_cidade  SERIAL      PRIMARY KEY,
    nome       VARCHAR(60) NOT NULL,
    sk_estado  INTEGER     NOT NULL REFERENCES dw_floco.dim_estado (sk_estado),
    UNIQUE (nome, sk_estado)
);

-- ---------------- Produto -> Categoria ----------------
CREATE TABLE dw_floco.dim_categoria (
    sk_categoria  SERIAL      PRIMARY KEY,
    nome          VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE dw_floco.dim_produto (
    sk_produto    INTEGER        PRIMARY KEY,        -- mesma SK do estrela
    id_origem     BIGINT         NOT NULL UNIQUE,
    nome          VARCHAR(120)   NOT NULL,
    preco_atual   NUMERIC(10, 2),
    sk_categoria  INTEGER        NOT NULL REFERENCES dw_floco.dim_categoria (sk_categoria)
);

-- ---------------- Loja -> Cidade ----------------
CREATE TABLE dw_floco.dim_loja (
    sk_loja    INTEGER     PRIMARY KEY,
    id_origem  BIGINT      NOT NULL UNIQUE,
    nome       VARCHAR(80) NOT NULL,
    sk_cidade  INTEGER     NOT NULL REFERENCES dw_floco.dim_cidade (sk_cidade)
);

-- ---------------- Cliente -> Cidade (SCD tipo 2) ----------------
CREATE TABLE dw_floco.dim_cliente (
    sk_cliente     INTEGER      PRIMARY KEY,
    id_origem      BIGINT       NOT NULL,
    nome           VARCHAR(120) NOT NULL,
    cpf            VARCHAR(11)  NOT NULL,
    possui_cartao  BOOLEAN      NOT NULL,
    sk_cidade      INTEGER      NOT NULL REFERENCES dw_floco.dim_cidade (sk_cidade),
    data_inicio    DATE         NOT NULL,
    data_fim       DATE         NOT NULL,
    atual          BOOLEAN      NOT NULL,
    versao         SMALLINT     NOT NULL
);

CREATE TABLE dw_floco.dim_pagamento (
    sk_pagamento  INTEGER     PRIMARY KEY,
    codigo        VARCHAR(10) NOT NULL UNIQUE,
    descricao     VARCHAR(30) NOT NULL,
    eletronico    BOOLEAN     NOT NULL
);

CREATE TABLE dw_floco.fato_venda (
    sk_tempo        INTEGER        NOT NULL REFERENCES dw_floco.dim_tempo (sk_tempo),
    sk_produto      INTEGER        NOT NULL REFERENCES dw_floco.dim_produto (sk_produto),
    sk_cliente      INTEGER        NOT NULL REFERENCES dw_floco.dim_cliente (sk_cliente),
    sk_loja         INTEGER        NOT NULL REFERENCES dw_floco.dim_loja (sk_loja),
    sk_pagamento    INTEGER        NOT NULL REFERENCES dw_floco.dim_pagamento (sk_pagamento),
    numero_cupom    BIGINT         NOT NULL,
    id_item_origem  BIGINT         NOT NULL UNIQUE,
    hora            SMALLINT       NOT NULL,
    quantidade      INTEGER        NOT NULL,
    preco_unitario  NUMERIC(10, 2) NOT NULL,
    valor_total     NUMERIC(12, 2) NOT NULL
);
CREATE INDEX ix_ffato_tempo   ON dw_floco.fato_venda (sk_tempo);
CREATE INDEX ix_ffato_produto ON dw_floco.fato_venda (sk_produto);
CREATE INDEX ix_ffato_cliente ON dw_floco.fato_venda (sk_cliente);
CREATE INDEX ix_ffato_loja    ON dw_floco.fato_venda (sk_loja);
