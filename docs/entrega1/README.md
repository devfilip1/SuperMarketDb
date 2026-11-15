# Entrega 1 – Sistema OLTP (venda de produtos por cupom fiscal)

Diagramas: [diagramas.pdf](diagramas.pdf) · DDL: [../../sql/oltp/01_ddl_oltp.sql](../../sql/oltp/01_ddl_oltp.sql)

## Requisitos do item 4.2

| Requisito | Onde |
|---|---|
| Maven + `persistence.xml` | `pom.xml`, `src/main/resources/META-INF/persistence.xml` |
| ≥ 8 entidades | 9: Pessoa, Cliente, Funcionario, CartaoFidelidade, Loja, Categoria, Produto, Venda, ItemVenda |
| `@OneToOne` | `Cliente.cartao` |
| `@OneToMany`/`@ManyToOne` bidirecional | `Venda.itens` ↔ `ItemVenda.venda` |
| Entidade intermediária | `ItemVenda` (Venda N:N Produto) |
| `@Inheritance` | Pessoa → Cliente / Funcionario (`JOINED`) |
| `@Embeddable` e `@Enumerated` | `Endereco`; `Venda.formaPagamento` |
| Datas | `LocalDate` (cartão) e `LocalDateTime` (venda) |
| `GenericDAO<T, ID>` | `dao/GenericDAO.java` |
| 10 JPQL + 3 Criteria | `consulta/ConsultasJPQL.java`, `consulta/ConsultasCriteria.java` |
| Carga | `carga/CargaDados.java`: 5 lojas, 100 produtos, 200 clientes, 2.000 vendas (11/2024 a 10/2026) |
| CRUD de 2 entidades | `ui/MenuCliente.java`, `ui/MenuProduto.java` |

## Justificativa de fetch e cascade (para o relatório)

Os `@ManyToOne` e o `@OneToOne` são todos `LAZY`, porque o padrão da JPA para eles é EAGER. Com EAGER, listar cupons carregaria o cliente, a loja e o operador de cada um. Quando os dados associados são necessários, a consulta usa `JOIN FETCH` (Q3 e Q10).

| Associação | fetch | cascade | Motivo |
|---|---|---|---|
| `Venda.itens` | LAZY | ALL + orphanRemoval | O item só existe dentro do cupom |
| `Venda.cliente` / `loja` / `operador` | LAZY | — | O cupom não cria nem apaga cadastros |
| `ItemVenda.venda` / `produto` | LAZY | — | O produto tem ciclo de vida próprio |
| `Produto.categoria` | LAZY | — | A categoria tem ciclo de vida próprio |
| `Cliente.cartao` | LAZY | ALL + orphanRemoval | O cartão só existe com o cliente |

Herança `JOINED`: mantém o modelo normalizado e o NOT NULL de `funcionario.matricula`. Com `SINGLE_TABLE`, essa coluna teria de aceitar nulo para clientes.

## As 13 consultas (menu, opção 3)

| # | Pergunta | Recurso |
|---|---|---|
| Q1 | Clientes com total comprado acima de um valor | `@NamedQuery Venda.totalPorCliente`, GROUP BY/HAVING |
| Q2 | Produtos de uma categoria | `@NamedQuery Produto.porCategoria`, junção |
| Q3 | Cupom fiscal com itens e produtos | `JOIN FETCH` |
| Q4 | Cupons de uma loja, por página | `setFirstResult`/`setMaxResults` |
| Q5 | Faturamento por loja em um período | junção, GROUP BY |
| Q6 | Produtos com preço acima da média | subconsulta |
| Q7 | N produtos mais vendidos | GROUP BY, `setMaxResults` |
| Q8 | Faturamento por categoria | junção em cadeia, GROUP BY |
| Q9 | Formas de pagamento com mais de N cupons | GROUP BY/HAVING |
| Q10 | Clientes de uma cidade com cartão fidelidade | junção pelo `@OneToOne`, `JOIN FETCH` |
| C1 | Busca de produtos por nome, categoria e preço máximo | Criteria com filtros dinâmicos |
| C2 | Cupons de um cliente (CPF) em um período | Criteria com junção e `between` |
| C3 | Quantidade de cupons por loja | Criteria com GROUP BY |

Todas usam parâmetros nomeados, exceto Q6, Q7, Q8 e as Criteria.
