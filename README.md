# SuperMarketDb – ORM e Data Warehousing (Banco de Dados II)

Equipe 4 – Supermercado: venda de produtos por cupom fiscal. JPA 2.1 + Hibernate 5.2.10.Final + PostgreSQL.

- Entrega 1 (OLTP): [docs/entrega1/README.md](docs/entrega1/README.md)
- Divisão de tarefas: [docs/planejamento/divisao-tarefas.pdf](docs/planejamento/divisao-tarefas.pdf)

## Como rodar

1. Crie o banco `supermercado` no PostgreSQL. As tabelas são criadas pelo Hibernate (`hbm2ddl.auto=update`) ou pelo script `sql/oltp/01_ddl_oltp.sql`.
2. Ajuste URL, usuário e senha em `src/main/resources/META-INF/persistence.xml`.
3. No Eclipse: `File > Import > Maven > Existing Maven Projects`.
4. Rode `br.edu.bd2.supermercado.carga.CargaDados` uma vez para gerar os dados.
5. Rode `br.edu.bd2.supermercado.App` para abrir o menu (CRUD de clientes e produtos e as 13 consultas).

Se usar JDK 9 ou mais novo em vez do JDK 8, adicione `--add-opens java.base/java.lang=ALL-UNNAMED` nos *VM arguments*.
