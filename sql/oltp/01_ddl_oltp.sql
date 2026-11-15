CREATE TABLE cartao_fidelidade (
    id           BIGSERIAL PRIMARY KEY,
    numero       VARCHAR(16) NOT NULL UNIQUE,
    data_emissao DATE        NOT NULL
);

CREATE TABLE pessoa (
    id         BIGSERIAL PRIMARY KEY,
    nome       VARCHAR(120) NOT NULL,
    cpf        VARCHAR(11)  NOT NULL UNIQUE,
    logradouro VARCHAR(120),
    cidade     VARCHAR(60),
    estado     VARCHAR(2)
);

CREATE TABLE cliente (
    id                   BIGINT PRIMARY KEY REFERENCES pessoa (id),
    cartao_fidelidade_id BIGINT UNIQUE REFERENCES cartao_fidelidade (id)
);

CREATE TABLE funcionario (
    id        BIGINT PRIMARY KEY REFERENCES pessoa (id),
    matricula VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE loja (
    id         BIGSERIAL PRIMARY KEY,
    nome       VARCHAR(80) NOT NULL,
    logradouro VARCHAR(120),
    cidade     VARCHAR(60),
    estado     VARCHAR(2)
);

CREATE TABLE categoria (
    id   BIGSERIAL PRIMARY KEY,
    nome VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE produto (
    id           BIGSERIAL PRIMARY KEY,
    nome         VARCHAR(120)   NOT NULL,
    preco        NUMERIC(10, 2) NOT NULL,
    categoria_id BIGINT         NOT NULL REFERENCES categoria (id)
);

CREATE TABLE venda (
    id              BIGSERIAL PRIMARY KEY,
    data_hora       TIMESTAMP   NOT NULL,
    cliente_id      BIGINT      NOT NULL REFERENCES cliente (id),
    loja_id         BIGINT      NOT NULL REFERENCES loja (id),
    funcionario_id  BIGINT      NOT NULL REFERENCES funcionario (id),
    forma_pagamento VARCHAR(10) NOT NULL
);

CREATE TABLE item_venda (
    id             BIGSERIAL PRIMARY KEY,
    venda_id       BIGINT         NOT NULL REFERENCES venda (id),
    produto_id     BIGINT         NOT NULL REFERENCES produto (id),
    quantidade     INTEGER        NOT NULL,
    preco_unitario NUMERIC(10, 2) NOT NULL
);
