# Roteiro da apresentação (20 min: 15 de exposição e demo + 5 de arguição)

Todos apresentam. O texto completo de cada fala está nas **notas do apresentador** de cada slide.

| Slides | Quem fala | Tempo | Assunto |
|---|---|---|---|
| 1–2 | Yuri | 1 min | Abertura, domínio (supermercado) e roteiro |
| 3–6 | Filipi | 3 min 40 s | OLTP: entidades, mapeamentos, fetch/cascade, 13 consultas, carga |
| 7–9 | Luiz Felipe | 3 min 15 s | Granularidade, estrela × floco, ETL, SCD tipo 2 |
| 10–13 | Liger | 3 min 50 s | OLAP, comparação de tempos, Apriori, k-means |
| 14–16 | Yuri | 3 min 10 s | Conclusões, demonstração ao vivo, perguntas |

## Antes de apresentar (no computador da demo)

1. PostgreSQL rodando, com o banco `supermercado` criado e populado (`CargaDados`), e o DW instalado:
   ```
   psql -U postgres -d supermercado -f sql/instalar_dw.sql
   ```
2. Abrir **três janelas** já posicionadas: o Eclipse com `App.java`, um terminal na pasta do repositório e o pgAdmin (ou `psql`).
3. Ensaiar a demo uma vez. Se não quiser que a demo altere o banco "oficial", faça um backup antes:
   `pg_dump -U postgres supermercado > backup.sql`.

## Demonstração (slide 15, cerca de 2 min)

1. **Cadastrar:** rodar `br.edu.bd2.supermercado.App` → menu de clientes → cadastrar um cliente (ex.: nome de um integrante, cidade digitada em minúsculas, como `  natal `, UF `rn`).
2. **Rodar o ETL:**
   ```
   psql -U postgres -d supermercado -f sql/etl/rodar_etl.sql
   ```
   Mostrar no log: `dw.dim_cliente` com **inseridas = 1** e `VALIDACAO | resultado | OK`.
3. **Ver no DW:**
   ```sql
   SELECT sk_cliente, nome, cidade, estado, versao, atual
   FROM dw.dim_cliente ORDER BY sk_cliente DESC LIMIT 1;
   ```
   Apontar: chave substituta nova, cidade padronizada (`Natal`, `RN`).
4. (Se sobrar tempo) mostrar o mesmo cliente no floco:
   ```sql
   SELECT c.sk_cliente, c.nome, ci.nome AS cidade, e.sigla, e.regiao
   FROM dw_floco.dim_cliente c
   JOIN dw_floco.dim_cidade ci ON ci.sk_cidade = c.sk_cidade
   JOIN dw_floco.dim_estado e ON e.sk_estado = ci.sk_estado
   ORDER BY c.sk_cliente DESC LIMIT 1;
   ```

**Plano B** se o Eclipse falhar: inserir o cliente direto no OLTP e seguir do passo 2.
```sql
WITH p AS (INSERT INTO pessoa (nome, cpf, cidade, estado) VALUES ('Cliente Demo', '12312312399', '  natal ', 'rn') RETURNING id)
INSERT INTO cliente (id) SELECT id FROM p;
```
