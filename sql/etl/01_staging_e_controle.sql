-- =====================================================================
-- Entrega 2 - ETL: area de STAGING (stg) e tabelas de CONTROLE (etl)
--
-- stg : copia "crua" do OLTP feita na extracao; e esvaziada a cada execucao.
--       As transformacoes (limpeza, padronizacao) sao feitas aqui, antes
--       da carga no DW, para nunca alterar o banco de producao (OLTP).
-- etl : historico das execucoes, log de contagens e marca d'agua da
--       carga incremental.
-- =====================================================================
SET client_encoding = 'UTF8';

DROP SCHEMA IF EXISTS stg CASCADE;
DROP SCHEMA IF EXISTS etl CASCADE;
CREATE SCHEMA stg;
CREATE SCHEMA etl;

-- ---------------------------- STAGING ----------------------------
CREATE TABLE stg.cliente (
    id_origem      BIGINT,
    nome           VARCHAR(120),
    cpf            VARCHAR(11),
    cidade         VARCHAR(60),
    estado         VARCHAR(10),
    possui_cartao  BOOLEAN,
    extraido_em    TIMESTAMP
);

CREATE TABLE stg.produto (
    id_origem    BIGINT,
    nome         VARCHAR(120),
    preco        NUMERIC(10, 2),
    categoria    VARCHAR(60),
    extraido_em  TIMESTAMP
);

CREATE TABLE stg.loja (
    id_origem    BIGINT,
    nome         VARCHAR(80),
    cidade       VARCHAR(60),
    estado       VARCHAR(10),
    extraido_em  TIMESTAMP
);

-- So recebe os itens NOVOS desde a ultima execucao (carga incremental)
CREATE TABLE stg.item_venda (
    id_item          BIGINT,
    id_venda         BIGINT,
    data_hora        TIMESTAMP,
    cliente_id       BIGINT,
    loja_id          BIGINT,
    forma_pagamento  VARCHAR(10),
    produto_id       BIGINT,
    quantidade       INTEGER,
    preco_unitario   NUMERIC(10, 2),
    extraido_em      TIMESTAMP
);

-- ---------------------------- CONTROLE ----------------------------
CREATE TABLE etl.execucao (
    id       SERIAL       PRIMARY KEY,
    inicio   TIMESTAMP    NOT NULL,
    fim      TIMESTAMP,
    tipo     VARCHAR(12)  NOT NULL,      -- INICIAL ou INCREMENTAL
    status   VARCHAR(20)  NOT NULL
);

CREATE TABLE etl.log_carga (
    id            SERIAL       PRIMARY KEY,
    execucao_id   INTEGER      NOT NULL REFERENCES etl.execucao (id),
    momento       TIMESTAMP    NOT NULL DEFAULT clock_timestamp(),
    etapa         VARCHAR(20)  NOT NULL,  -- EXTRACAO, TRANSFORMACAO, CARGA, CARGA FLOCO, VALIDACAO
    tabela        VARCHAR(40)  NOT NULL,
    linhas_antes  BIGINT,
    linhas_depois BIGINT,
    inseridas     BIGINT,
    atualizadas   BIGINT,
    observacao    VARCHAR(200)
);

-- Marca d'agua: maior item_venda.id ja carregado na fato
CREATE TABLE etl.controle (
    chave  VARCHAR(40) PRIMARY KEY,
    valor  BIGINT      NOT NULL
);
INSERT INTO etl.controle VALUES ('ultimo_item_venda_id', 0);

-- ------------------- Funcoes de limpeza/padronizacao -------------------

-- Remove espacos nas pontas e espacos repetidos; texto vazio vira NULL
CREATE FUNCTION etl.limpar(t TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
    SELECT NULLIF(regexp_replace(btrim(t), '\s+', ' ', 'g'), '')
$$;

-- Texto livre (nome de produto, loja): limpo, ou 'Não informado' se nulo
CREATE FUNCTION etl.texto(t TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
    SELECT COALESCE(etl.limpar(t), 'Não informado')
$$;

-- Nome proprio (pessoa, cidade): primeira letra de cada palavra maiuscula
CREATE FUNCTION etl.nome_proprio(t TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
    SELECT COALESCE(initcap(etl.limpar(t)), 'Não informado')
$$;

-- Sigla de UF: 2 letras maiusculas; qualquer outra coisa vira 'NI'
CREATE FUNCTION etl.uf(t TEXT) RETURNS CHAR(2)
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN upper(etl.limpar(t)) ~ '^[A-Z]{2}$' THEN upper(etl.limpar(t)) ELSE 'NI' END
$$;

-- Nome e regiao de cada UF (usado no floco de neve, dim_estado)
CREATE FUNCTION etl.nome_estado(sigla TEXT, OUT nome TEXT, OUT regiao TEXT)
LANGUAGE sql IMMUTABLE AS $$
    SELECT COALESCE(e.nome, 'Não informado'), COALESCE(e.regiao, 'Não informado')
    FROM (SELECT 1) x
    LEFT JOIN (VALUES
        ('AC','Acre','Norte'), ('AL','Alagoas','Nordeste'), ('AP','Amapá','Norte'),
        ('AM','Amazonas','Norte'), ('BA','Bahia','Nordeste'), ('CE','Ceará','Nordeste'),
        ('DF','Distrito Federal','Centro-Oeste'), ('ES','Espírito Santo','Sudeste'),
        ('GO','Goiás','Centro-Oeste'), ('MA','Maranhão','Nordeste'), ('MT','Mato Grosso','Centro-Oeste'),
        ('MS','Mato Grosso do Sul','Centro-Oeste'), ('MG','Minas Gerais','Sudeste'), ('PA','Pará','Norte'),
        ('PB','Paraíba','Nordeste'), ('PR','Paraná','Sul'), ('PE','Pernambuco','Nordeste'),
        ('PI','Piauí','Nordeste'), ('RJ','Rio de Janeiro','Sudeste'), ('RN','Rio Grande do Norte','Nordeste'),
        ('RS','Rio Grande do Sul','Sul'), ('RO','Rondônia','Norte'), ('RR','Roraima','Norte'),
        ('SC','Santa Catarina','Sul'), ('SP','São Paulo','Sudeste'), ('SE','Sergipe','Nordeste'),
        ('TO','Tocantins','Norte')
    ) AS e (sigla, nome, regiao) ON e.sigla = $1
$$;
