# Entrega 2 – Data Warehouse carregado e scripts ETL

Diagramas: [diagramas.pdf](diagramas.pdf) · Log da execução: [log_execucao_etl.txt](log_execucao_etl.txt)

## Como rodar

Pré-requisito: OLTP populado (Entrega 1, classe `CargaDados`). Tudo roda no mesmo banco `supermercado` do PostgreSQL, em esquemas separados do OLTP.

```
psql -U postgres -d supermercado -f sql/instalar_dw.sql          # cria dw, dw_floco, stg, etl e faz a carga inicial
psql -U postgres -d supermercado -f sql/etl/rodar_etl.sql        # reexecuta o ETL (incremental) - usado na demo
psql -U postgres -d supermercado -f sql/etl/03_teste_scd2_incremental.sql   # teste de SCD2 (altera o OLTP!)
```

`instalar_dw.sql` apaga e recria o DW. `rodar_etl.sql` só acrescenta o que é novo.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `sql/dw/01_ddl_estrela.sql` | Modelo estrela (esquema `dw`) |
| `sql/dw/02_ddl_floco.sql` | Modelo floco de neve (esquema `dw_floco`) |
| `sql/dw/03_carga_floco.sql` | Procedure `etl.carregar_floco` |
| `sql/etl/01_staging_e_controle.sql` | Staging (`stg`), log e controle (`etl`), funções de limpeza |
| `sql/etl/02_procedures_etl.sql` | Procedures do ETL; `etl.executar()` orquestra tudo |
| `sql/etl/rodar_etl.sql` | Script único de reexecução, mostra o log de contagens |
| `sql/etl/03_teste_scd2_incremental.sql` | Teste de SCD2, nulos, padronização e carga incremental |
| `sql/instalar_dw.sql` | Instala tudo do zero e roda a carga inicial |

## Modelagem dimensional

**Granularidade:** um item vendido em um cupom fiscal. Uma linha de `fato_venda` corresponde a uma linha de `item_venda` do OLTP. É o menor nível disponível: permite analisar produto por produto e também somar até o cupom, o dia, a loja, etc. Com granularidade de cupom inteiro não seria possível saber quais produtos foram vendidos (necessário para a mineração de regras de associação).

**Modelo estrela (`dw`)**: 1 fato e 5 dimensões.

| Tabela | Conteúdo |
|---|---|
| `fato_venda` | medidas `quantidade` (aditiva), `preco_unitario` (não aditiva) e `valor_total` = quantidade × preço (aditiva, **derivada** no ETL); `numero_cupom` é dimensão degenerada |
| `dim_tempo` | dia, mês, nome do mês, trimestre, semestre, ano, dia da semana, fim de semana. Chave `AAAAMMDD` |
| `dim_produto` | nome, categoria (desnormalizada), preço atual – SCD tipo 1 |
| `dim_cliente` | nome, CPF, cidade, UF, possui cartão – **SCD tipo 2** em cidade/UF |
| `dim_loja` | nome, cidade, UF – SCD tipo 1 |
| `dim_pagamento` | Dinheiro, Débito, Crédito, Pix (enum `FormaPagamento`) |

**Modelo floco de neve (`dw_floco`)**: mesma fato, com 3 dimensões normalizadas.

- `dim_produto` → `dim_categoria`
- `dim_loja` → `dim_cidade` → `dim_estado` (com nome do estado e região)
- `dim_cliente` → `dim_cidade` → `dim_estado`

As chaves substitutas de produto, cliente, loja e pagamento são as mesmas nos dois modelos, então as duas fatos têm as mesmas linhas e podem ser comparadas diretamente.

**Mesma consulta nos dois modelos** (faturamento de Bebidas por UF da loja), com resultado idêntico:

| Modelo | Junções |
|---|---|
| Estrela | 2 (`fato` → `dim_produto`, `fato` → `dim_loja`) |
| Floco de neve | 5 (`fato` → `dim_produto` → `dim_categoria`, `fato` → `dim_loja` → `dim_cidade` → `dim_estado`) |

## ETL (PL/pgSQL)

Fluxo de `CALL etl.executar()`:

1. **Extração** (`etl.extrair`): copia do OLTP para a staging, sem transformar. Cadastros vão inteiros; itens de venda só os que têm `id` maior que a marca d'água.
2. **Transformação** (`etl.transformar`), feita na staging, sem tocar no OLTP:
   - nulos/vazios → `Não informado` (texto) e `NI` (UF);
   - padronização: espaços nas pontas e repetidos removidos, nomes e cidades em Initcap, UF em maiúscula, CPF só com dígitos;
   - itens com quantidade ≤ 0 ou preço negativo são descartados (e contados no log).
3. **Carga do estrela**:
   - `dim_tempo` gerada por `generate_series` para todos os dias dos anos que têm venda;
   - `dim_produto`, `dim_loja`, `dim_pagamento`: SCD tipo 1 (atualiza o que mudou, insere o que é novo);
   - `dim_cliente`: **SCD tipo 2**. Se a cidade/UF mudou, a versão atual é fechada (`data_fim` = hoje, `atual` = false) e uma nova versão é criada com nova chave substituta. Nome, CPF e cartão são tipo 1;
   - `fato_venda`: troca as chaves do OLTP pelas chaves substitutas. Para o cliente, usa a versão **vigente na data da venda**. Chave não encontrada → membro `0` (Não informado). Calcula `valor_total`.
4. **Carga do floco** (`etl.carregar_floco`): normaliza categoria, cidade e estado e copia a fato, também de forma incremental.
5. **Validação** (`etl.validar`): compara quantidade de linhas e soma em R$ entre OLTP, estrela e floco.

**Carga incremental:** `etl.controle.ultimo_item_venda_id` guarda o maior `item_venda.id` já carregado. Cada execução só extrai itens acima dele. `id_item_origem` é UNIQUE na fato, então rodar duas vezes não duplica nada.

**Log:** cada etapa grava em `etl.log_carga` as linhas antes, depois, inseridas e atualizadas. `etl.execucao` guarda tipo (INICIAL/INCREMENTAL), duração e status (OK/DIVERGENTE).

## Resultado da carga (log completo em `log_execucao_etl.txt`)

| Execução | O que aconteceu | Fato estrela | Fato floco | OLTP | Status |
|---|---|---|---|---|---|
| 1 – inicial | 200 clientes, 100 produtos, 5 lojas, 1.096 dias (2024–2026) | 0 → 10.007 | 0 → 10.007 | 10.007 itens, R$ 372.057,92 | OK |
| 2 – incremental sem mudanças | nada novo | 10.007 → 10.007 | 10.007 → 10.007 | igual | OK |
| 3 – teste SCD2 | 1 cliente mudou de cidade, 1 cliente novo com nulos, 1 cupom com 2 itens | 10.007 → 10.009 | 10.007 → 10.009 | 10.009 itens | OK |

Na execução 3, o cliente que mudou de João Pessoa/PB para `'  recife '`/`'pe'` ficou assim em `dw.dim_cliente`:

| sk_cliente | cidade | UF | versão | data_inicio | data_fim | atual |
|---|---|---|---|---|---|---|
| 1 | Joao Pessoa | PB | 1 | 1900-01-01 | 2026-11-22 | false |
| 201 | Recife | PE | 2 | 2026-11-22 | 9999-12-31 | true |

Os 31 cupons antigos continuam ligados à versão 1 (João Pessoa) e o cupom novo foi para a versão 2 (Recife): a história não é reescrita. O cliente novo sem cidade e sem UF entrou como `Não informado` / `NI`.

## Demonstração (apresentação)

1. Cadastrar um cliente ou produto pelo menu da aplicação (`App`, Entrega 1).
2. Rodar `sql/etl/rodar_etl.sql`. O log mostra `inseridas = 1` na dimensão.
3. Consultar no DW: `SELECT * FROM dw.dim_cliente ORDER BY sk_cliente DESC LIMIT 1;`

## Textos de apoio para o relatório

- **Q7 – não volátil e variante no tempo:** o ETL só insere no DW. Nada é apagado quando o OLTP muda: a mudança de cidade gera uma nova versão do cliente e as vendas antigas continuam na versão antiga. Toda linha da fato tem `sk_tempo` e toda versão de cliente tem período de vigência.
- **Q8 – granularidade:** um item por cupom (ver acima).
- **Q9 – estrela x floco:** 2 junções no estrela contra 5 no floco para a mesma consulta (ver acima).
- **Q10 – chaves substitutas:** (1) o SCD2 exige mais de uma linha por cliente, então o `id` do OLTP não pode ser PK; (2) o DW fica independente de mudanças ou reuso de chaves no OLTP; (3) permite o membro `0` "Não informado"; (4) inteiros pequenos deixam as junções da fato mais rápidas.
