"""Mede o tempo da MESMA consulta no OLTP, no estrela e no floco de neve.

Le as 3 versoes de sql/olap/02_comparacao_tempos.sql, roda cada uma 30 vezes
com EXPLAIN (ANALYZE, FORMAT JSON) e mostra a mediana do tempo de execucao.
Tambem confere que as 3 versoes devolvem o mesmo resultado.

    python mineracao/medir_tempos.py
Conexao: variaveis PGHOST, PGUSER, PGPASSWORD, PGDATABASE (padrao: localhost, postgres, postgres, supermercado)
"""
import os
import re
import statistics
import sys
from pathlib import Path

import psycopg2

RODADAS = 30
SQL = Path(__file__).resolve().parent.parent / "sql" / "olap" / "02_comparacao_tempos.sql"


def ler_consultas():
    texto = SQL.read_text(encoding="utf-8")
    blocos = re.findall(r"\\echo '=== (.+?) ==='\s*EXPLAIN \([^)]*\)\s*(SELECT.+?);", texto, re.S)
    return [(nome, sql) for nome, sql in blocos]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    con = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", "postgres"),
        dbname=os.getenv("PGDATABASE", "supermercado"),
    )
    cur = con.cursor()
    resultados = {}
    print(f"{'Modelo':<34} {'junções':>7} {'mediana (ms)':>13} {'mín (ms)':>9} {'máx (ms)':>9} {'planej. (ms)':>12}")
    for nome, sql in ler_consultas():
        juncoes = len(re.findall(r"\bJOIN\b", sql))
        execucao, planejamento = [], []
        for _ in range(RODADAS):
            cur.execute("EXPLAIN (ANALYZE, FORMAT JSON) " + sql)
            plano = cur.fetchone()[0][0]
            execucao.append(plano["Execution Time"])
            planejamento.append(plano["Planning Time"])
        cur.execute(sql)
        resultados[nome] = sorted((str(a), str(b), round(float(c), 2)) for a, b, c in cur.fetchall())
        print(f"{nome:<34} {juncoes:>7} {statistics.median(execucao):>13.3f} {min(execucao):>9.3f} "
              f"{max(execucao):>9.3f} {statistics.median(planejamento):>12.3f}")
    iguais = len({tuple(r) for r in resultados.values()}) == 1
    print(f"\nAs {len(resultados)} versões devolvem o mesmo resultado: {'SIM' if iguais else 'NÃO'} "
          f"({len(next(iter(resultados.values())))} linhas cada)")
    con.close()


if __name__ == "__main__":
    main()
