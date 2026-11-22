# Entrega 3 – OLAP, comparação de desempenho e mineração de dados

Relatório técnico completo: [../relatorio/relatorio_tecnico.pdf](../relatorio/relatorio_tecnico.pdf)

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `sql/olap/01_consultas_olap.sql` | 10 consultas OLAP (2 por operação), com ROLLUP, CUBE e GROUPING SETS |
| `sql/olap/02_comparacao_tempos.sql` | A mesma consulta no OLTP, no estrela e no floco, com `EXPLAIN ANALYZE` |
| `mineracao/medir_tempos.py` | Roda cada versão 30 vezes e calcula a mediana |
| `mineracao/mineracao.ipynb` | Notebook executado: Apriori e k-means, com resultados e conclusões |
| `mineracao/dados/` | Bases exportadas do DW (CSV), regras encontradas e gráficos |
| [resultados_olap.txt](resultados_olap.txt) / [comparacao_tempos.txt](comparacao_tempos.txt) | Saída das execuções |

## Como rodar

```
psql -U postgres -d supermercado -f sql/olap/01_consultas_olap.sql
pip install -r mineracao/requirements.txt
python mineracao/medir_tempos.py                       # usa PGUSER/PGPASSWORD (padrão postgres/postgres)
cd mineracao && jupyter notebook mineracao.ipynb
```

## Consultas OLAP

| # | Operação | Pergunta de negócio | Resultado |
|---|---|---|---|
| R1 | Roll-up | Faturamento por mês → trimestre → ano, com subtotais | 2025: R$ 183.682,29 em 979 cupons |
| R2 | Roll-up | Faturamento por loja → cidade → UF → total | RN = R$ 226.113,63 (61% da rede) |
| D1 | Drill-down | 2025: ano → semestre → mês, com ticket médio | ticket médio de R$ 187,62; picos em junho e outubro |
| D2 | Drill-down | Categoria → produto (descendo em Bebidas) | Açougue lidera (33%); Refrigerante Cola 2L é a bebida que mais fatura |
| S1 | Slice | Ano = 2025: loja × categoria | Açougue é a 1ª categoria em todas as lojas |
| S2 | Slice | Pagamento = Pix, por trimestre | de 53 a 67 cupons por trimestre completo |
| Di1 | Dice | Lojas do RN × Açougue e Bebidas × 2º sem/2025 | Açougue fatura cerca de 5× mais que Bebidas |
| Di2 | Dice | Clientes com cartão × fim de semana × 2026 (CUBE) | domingo fatura mais que sábado (R$ 13.438 × R$ 10.355) |
| P1 | Pivot | Categoria (linhas) × ano (colunas) | Açougue lidera todos os anos; Hortifruti é a última |
| P2 | Pivot | Loja (linhas) × forma de pagamento em % (colunas) | uso equilibrado, cerca de 20% a 30% cada |

## Mesma consulta nos três modelos

Pergunta: faturamento de cada categoria, por UF da loja, em 2025. Mediana de 30 execuções; as três versões devolvem as mesmas 30 linhas.

| Modelo | Junções | Execução (ms) | Planejamento (ms) |
|---|---|---|---|
| OLTP (`public`) | 4 | 4,057 | 0,209 |
| Estrela (`dw`) | 3 | **3,128** | 0,201 |
| Floco de neve (`dw_floco`) | 6 | 4,468 | 0,451 |

## Mineração

**Apriori** (mlxtend), sobre a matriz de 2.001 cupons × 100 produtos, com suporte ≥ 3%, confiança ≥ 50% e lift > 1: 208 conjuntos frequentes e 528 regras (51 simples). A regra simples mais forte é **Flocão de Milho → Carne de Sol** (suporte 0,043, confiança 0,565, lift 6,85).

**k-means** (scikit-learn) sobre recência, frequência e valor padronizados, com k = 4 (silhueta 0,48):

| Segmento | Clientes | Recência média (dias) | Cupons (média) | % do faturamento |
|---|---|---|---|---|
| VIP | 31 | 32 | 24,2 | 37,4% |
| Regulares | 115 | 38 | 7,9 | 44,5% |
| Esfriando | 50 | 165 | 6,6 | 17,4% |
| Inativos | 4 | 469 | 4,0 | 0,7% |

**Conclusões de negócio:**
1. Os ingredientes do cuscuz (flocão, carne de sol, queijo coalho) devem ficar próximos e entrar em promoções casadas.
2. Os cupons formam “missões de compra” (churrasco, cuscuz, higiene, limpeza, feira do mês), que podem orientar layout e encartes.
3. Os 31 clientes VIP (16% da base) geram 37% do faturamento e merecem um programa de fidelidade exclusivo.
4. Os 50 clientes “Esfriando” estão há cerca de 165 dias sem comprar: são o alvo de uma campanha de reativação.

## Observação sobre os dados

A classe `CargaDados` foi ajustada para gerar dados mais realistas, mantendo as mesmas quantidades (200 clientes, 100 produtos, 5 lojas, 2.000 cupons): 40% dos cupons seguem uma cesta típica e 30 clientes fiéis fazem cerca de 25% das compras. Sem isso, os produtos de cada cupom seriam sorteados de forma totalmente aleatória e o Apriori não encontraria associações (lift ≈ 1). Os números da Entrega 2 (`docs/entrega2`) foram atualizados com essa carga.
