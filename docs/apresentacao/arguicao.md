# Preparação para a arguição

O professor pode perguntar **qualquer parte a qualquer aluno**. Cada um deve conseguir responder todas as perguntas abaixo com as próprias palavras. Simulado sugerido: cada pessoa sorteia 3 perguntas de outra parte e responde sem olhar.

## Parte 1 – OLTP, JPA e Hibernate (Filipi)

1. **O que é a impedância objeto-relacional?** Diferença entre objetos (herança, referências, identidade por `==`) e tabelas (sem herança, chaves estrangeiras, identidade pela PK). Exemplo nosso: `Cliente extends Pessoa` virou 3 tabelas com `JOINED`.
2. **Por que JOINED e não SINGLE_TABLE?** Para manter `funcionario.matricula` NOT NULL e o modelo normalizado. Em SINGLE_TABLE a coluna teria de aceitar nulo para clientes.
3. **Por que os @ManyToOne são LAZY?** O padrão da JPA para eles é EAGER: listar cupons traria cliente, loja e operador de cada um. Quando precisamos, usamos `JOIN FETCH` (consultas Q3 e Q10).
4. **O que é o problema N+1?** 1 consulta para N objetos + 1 consulta por objeto ao acessar uma associação LAZY. Evita-se com `JOIN FETCH` ou `@EntityGraph`.
5. **Por que cascade ALL + orphanRemoval em Venda.itens e não em Venda.cliente?** O item só existe dentro do cupom; o cliente tem vida própria.
6. **Estados de uma entidade?** new → `persist` → managed → `close/detach/clear` → detached → `merge` → managed; managed → `remove` → removed.
7. **JPA × Hibernate?** JPA é a especificação (`javax.persistence`); Hibernate é a implementação. Trocar por EclipseLink muda só `pom.xml` e `persistence.xml`.
8. **Onde estão as @NamedQuery?** `Venda.totalPorCliente` (GROUP BY/HAVING) e `Produto.porCategoria`.
9. **Qual consulta Criteria tem filtros dinâmicos?** C1, busca de produtos por nome, categoria e preço máximo: só os filtros preenchidos entram no `where`.

## Parte 2 – DW e ETL (Luiz Felipe)

10. **Qual a granularidade da fato e por quê?** Um item vendido por cupom: o menor nível do OLTP. Permite agregar a qualquer nível e fazer a mineração de cestas.
11. **Quais são as medidas?** `quantidade` (aditiva), `preco_unitario` (não aditiva) e `valor_total` (aditiva, derivada no ETL). `numero_cupom` é dimensão degenerada.
12. **Estrela × floco: quantas junções?** Faturamento de Bebidas por UF: 2 no estrela, 5 no floco. Com filtro de ano: 3 × 6.
13. **Por que chaves substitutas?** SCD 2 (o mesmo cliente tem várias linhas), independência do OLTP, membro “Não informado” (sk 0) e junções mais leves.
14. **Como funciona o SCD tipo 2 no nosso ETL?** Se cidade/UF mudou: fecha a versão atual (`data_fim` = hoje, `atual` = false) e insere nova linha com nova `sk_cliente`, `versao` + 1. A fato usa a versão vigente na data da venda.
15. **Como é a carga incremental?** `etl.controle` guarda o maior `item_venda.id` carregado; a extração só pega itens acima dele. `id_item_origem` é UNIQUE na fato, então reexecutar não duplica.
16. **O que a staging faz?** Recebe a cópia crua do OLTP; a limpeza é feita nela, sem alterar o OLTP.
17. **Como provam que a carga está certa?** `etl.validar` compara linhas e soma em R$ entre OLTP, estrela e floco; tudo fica em `etl.log_carga`.
18. **Por que o DW é não volátil e variante no tempo?** O ETL só acrescenta; a mudança de cidade não apagou a cidade antiga. Todo fato tem data e toda versão de cliente tem vigência.

## Parte 3 – OLAP e mineração (Liger)

19. **Diferença entre slice e dice?** Slice fixa uma dimensão (só Pix); dice restringe várias ao mesmo tempo (RN × Açougue/Bebidas × 2º sem/2025).
20. **O que o ROLLUP faz?** Gera subtotais por nível da hierarquia (mês → trimestre → ano → total). CUBE gera todas as combinações.
21. **Qual modelo foi mais rápido e por quê?** Estrela (3,1 ms): menos junções e `valor_total` já calculado. O floco (4,5 ms) tem 6 junções e o dobro do tempo de planejamento.
22. **Explique suporte, confiança e lift com a nossa regra.** Flocão → Carne de Sol: suporte 4,3% (cupons com os dois), confiança 56% (de quem leva flocão, quantos levam carne de sol), lift 6,85 (56% / 8,2% de base).
23. **Por que k = 4 no k-means?** k = 2 tinha a maior silhueta (0,63), mas só separava fiéis do resto; em k = 4 a inércia achata e a silhueta segue razoável (0,48), com grupos que viram ações.
24. **Por que padronizar o RFM?** O k-means usa distância euclidiana; sem padronizar, o valor em R$ dominaria recência e frequência.
25. **Os dados são reais?** São gerados pela `CargaDados`, com cestas típicas e um grupo de clientes fiéis para imitar o comportamento real. A análise mostra que o método encontra esses padrões.

## Parte 4 – Visão geral (Yuri)

26. **OLTP × OLAP em uma frase?** OLTP registra transações curtas e atuais; OLAP analisa grandes volumes históricos.
27. **Inmon × Kimball?** Inmon: DW corporativo normalizado primeiro (top-down). Kimball: data marts dimensionais por processo, integrados por dimensões conformadas (bottom-up). Seguimos Kimball.
28. **Onde usaram IA?** Está declarado no relatório (seção 6.1). Todos revisaram e executaram o código e sabem explicá-lo.
