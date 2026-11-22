"""Gera o relatorio tecnico (ABNT) em .docx: docs/relatorio/relatorio_tecnico.docx

    python docs/relatorio/gerar_relatorio.py

Para atualizar o sumario e exportar o PDF, abra o .docx no Word, clique com o botao
direito no sumario > Atualizar campo > Atualizar o indice inteiro, e salve como PDF.
(Ou rode docs/relatorio/exportar_pdf.ps1, que faz isso automaticamente.)

Os dados da capa (instituicao, professor, nomes completos, cidade) ficam no
dicionario CAPA abaixo. Campos entre colchetes aparecem destacados em amarelo.
"""
import re
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_COLOR_INDEX, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

AQUI = Path(__file__).resolve().parent
REPO = AQUI.parent.parent
IMG = AQUI / "imagens"
MIN = REPO / "mineracao" / "dados"

CAPA = {
    "instituicao": "[NOME DA INSTITUIÇÃO]",
    "curso": "Engenharia de Software",
    "turma": "ESW-MAT-PIT-6S-T1",
    "disciplina": "Banco de Dados II",
    "professor": "[Nome do professor]",
    "integrantes": ["Filipi [sobrenome]", "Liger [sobrenome]", "Luiz Felipe [sobrenome]", "Yuri [sobrenome]"],
    "cidade": "[Cidade]",
    "ano": "2026",
    "titulo": "ORM E DATA WAREHOUSING EM UM SUPERMERCADO",
    "subtitulo": "do sistema transacional com JPA/Hibernate ao Data Warehouse com ETL, OLAP e mineração de dados",
}

FONTE = "Times New Roman"

# --------------------------------------------------------------------------- base


def configurar(doc):
    sec = doc.sections[0]
    sec.page_height, sec.page_width = Cm(29.7), Cm(21.0)
    sec.top_margin, sec.left_margin = Cm(3), Cm(3)
    sec.bottom_margin, sec.right_margin = Cm(2), Cm(2)
    st = doc.styles["Normal"]
    st.font.name, st.font.size = FONTE, Pt(12)
    st.element.rPr.rFonts.set(qn("w:eastAsia"), FONTE)
    pf = st.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    pf.space_before = pf.space_after = Pt(0)
    for nome, antes, depois in (("Heading 1", 0, 18), ("Heading 2", 18, 12)):
        h = doc.styles[nome]
        h.font.name, h.font.size, h.font.bold = FONTE, Pt(12), True
        h.font.color.rgb = RGBColor(0, 0, 0)
        h.font.italic = False
        rpr = h.element.get_or_add_rPr()
        fonts = rpr.find(qn("w:rFonts"))
        if fonts is None:
            fonts = OxmlElement("w:rFonts")
            rpr.append(fonts)
        for a in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
            fonts.set(qn(a), FONTE)
        for t in ("w:asciiTheme", "w:hAnsiTheme", "w:eastAsiaTheme", "w:cstheme"):
            if fonts.get(qn(t)) is not None:
                del fonts.attrib[qn(t)]
        h.paragraph_format.space_before, h.paragraph_format.space_after = Pt(antes), Pt(depois)
        h.paragraph_format.keep_with_next = True
        h.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE


def runs(par, texto, tamanho=None, negrito=False):
    """Escreve texto com **negrito**, `codigo` e [placeholder] destacado."""
    for parte in re.split(r"(\*\*.+?\*\*|`.+?`|\[[^\]]*\])", texto):
        if not parte:
            continue
        if parte.startswith("**"):
            r = par.add_run(parte[2:-2]); r.bold = True
        elif parte.startswith("`"):
            r = par.add_run(parte[1:-1]); r.font.name = "Courier New"; r.font.size = Pt(10.5)
        elif parte.startswith("[") and parte.endswith("]") and ("NOME" in parte or "sobrenome" in parte
                                                               or "Cidade" in parte or "professor" in parte
                                                               or "confirmar" in parte):
            r = par.add_run(parte); r.font.highlight_color = WD_COLOR_INDEX.YELLOW
        else:
            r = par.add_run(parte)
        if negrito:
            r.bold = True
        if tamanho and not parte.startswith("`"):
            r.font.size = Pt(tamanho)
    return par


def centro(doc, texto, negrito=False, tamanho=12, antes=0, depois=0, caixa_alta=False):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Cm(0)
    p.paragraph_format.space_before, p.paragraph_format.space_after = Pt(antes), Pt(depois)
    runs(p, texto.upper() if caixa_alta else texto, tamanho, negrito)
    return p


def quebra(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)


class Rel:
    def __init__(self, doc):
        self.doc = doc
        self.fig = 0
        self.tab = 0

    def h1(self, texto, nova_pagina=True):
        p = self.doc.add_heading(texto.upper(), level=1)
        p.paragraph_format.page_break_before = nova_pagina

    def h2(self, texto):
        self.doc.add_heading(texto, level=2)

    def q(self, texto):
        par = self.doc.add_paragraph()
        par.paragraph_format.space_before = Pt(12)
        par.paragraph_format.space_after = Pt(4)
        par.paragraph_format.keep_with_next = True
        r = par.add_run(texto); r.bold = True

    def p(self, texto):
        par = self.doc.add_paragraph()
        par.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        par.paragraph_format.first_line_indent = Cm(1.25)
        runs(par, texto)

    def itens(self, lista):
        for t in lista:
            par = self.doc.add_paragraph()
            par.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            par.paragraph_format.left_indent = Cm(1.25)
            par.paragraph_format.first_line_indent = Cm(-0.5)
            runs(par, "–  " + t)

    def codigo(self, texto):
        for linha in texto.strip("\n").split("\n"):
            par = self.doc.add_paragraph()
            par.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
            par.paragraph_format.left_indent = Cm(0.5)
            r = par.add_run(linha if linha else " ")
            r.font.name, r.font.size = "Courier New", Pt(9)
            sombra = OxmlElement("w:shd")
            sombra.set(qn("w:val"), "clear"); sombra.set(qn("w:color"), "auto"); sombra.set(qn("w:fill"), "F2F2F2")
            par._p.get_or_add_pPr().append(sombra)
        self.doc.add_paragraph().paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE

    def _legenda(self, tipo, n, titulo):
        par = self.doc.add_paragraph()
        par.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
        par.paragraph_format.space_before = Pt(6)
        par.paragraph_format.space_after = Pt(3)
        par.paragraph_format.keep_with_next = True
        r = par.add_run(f"{tipo} {n} – "); r.bold = True; r.font.size = Pt(10)
        runs(par, titulo, 10)

    def _fonte(self, texto="Elaborado pelos autores (2026)."):
        par = self.doc.add_paragraph()
        par.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
        par.paragraph_format.space_after = Pt(10)
        r = par.add_run("Fonte: " + texto); r.font.size = Pt(10)

    def figura(self, caminho, titulo, largura=15.5):
        self.fig += 1
        self._legenda("Figura", self.fig, titulo)
        par = self.doc.add_paragraph()
        par.alignment = WD_ALIGN_PARAGRAPH.CENTER
        par.paragraph_format.keep_with_next = True
        par.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
        par.add_run().add_picture(str(caminho), width=Cm(largura))
        self._fonte()

    def figura_dupla(self, cam1, tit1, larg1, cam2, tit2, larg2):
        """Duas figuras lado a lado (tabela sem bordas), cada uma com legenda e fonte."""
        t = self.doc.add_table(rows=1, cols=2)
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        for cel, cam, tit, larg in ((t.rows[0].cells[0], cam1, tit1, larg1), (t.rows[0].cells[1], cam2, tit2, larg2)):
            self.fig += 1
            cel.width = Cm(larg + 0.4)
            leg = cel.paragraphs[0]
            leg.alignment = WD_ALIGN_PARAGRAPH.CENTER
            leg.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
            r = leg.add_run(f"Figura {self.fig} – "); r.bold = True; r.font.size = Pt(10)
            runs(leg, tit, 10)
            img = cel.add_paragraph()
            img.alignment = WD_ALIGN_PARAGRAPH.CENTER
            img.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
            img.add_run().add_picture(str(cam), width=Cm(larg))
            fonte = cel.add_paragraph()
            fonte.alignment = WD_ALIGN_PARAGRAPH.CENTER
            fonte.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
            rf = fonte.add_run("Fonte: Elaborado pelos autores (2026)."); rf.font.size = Pt(10)
            for par in cel.paragraphs:
                par.paragraph_format.first_line_indent = Cm(0)
        self.doc.add_paragraph().paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE

    def tabela(self, titulo, cabecalho, linhas, larguras):
        self.tab += 1
        self._legenda("Tabela", self.tab, titulo)
        t = self.doc.add_table(rows=1, cols=len(cabecalho))
        t.style = "Table Grid"
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        for i, txt in enumerate(cabecalho):
            c = t.rows[0].cells[i]
            c.text = ""
            runs(c.paragraphs[0], txt, 10, True)
            sombra = OxmlElement("w:shd")
            sombra.set(qn("w:val"), "clear"); sombra.set(qn("w:color"), "auto"); sombra.set(qn("w:fill"), "E7E6E6")
            c._tc.get_or_add_tcPr().append(sombra)
        for linha in linhas:
            cels = t.add_row().cells
            for i, txt in enumerate(linha):
                cels[i].text = ""
                runs(cels[i].paragraphs[0], str(txt), 10)
        for linha in t.rows:
            for i, c in enumerate(linha.cells):
                c.width = Cm(larguras[i])
                for par in c.paragraphs:
                    par.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
                    par.paragraph_format.first_line_indent = Cm(0)
        self._fonte()


def campo(par, instrucao, texto=""):
    r = par.add_run()
    ini = OxmlElement("w:fldChar"); ini.set(qn("w:fldCharType"), "begin")
    ins = OxmlElement("w:instrText"); ins.set(qn("xml:space"), "preserve"); ins.text = instrucao
    sep = OxmlElement("w:fldChar"); sep.set(qn("w:fldCharType"), "separate")
    t = OxmlElement("w:t"); t.text = texto
    fim = OxmlElement("w:fldChar"); fim.set(qn("w:fldCharType"), "end")
    for e in (ini, ins, sep, t, fim):
        r._r.append(e)


# --------------------------------------------------------------------------- pre-textuais


def pre_textuais(doc):
    c = CAPA
    centro(doc, c["instituicao"], True, caixa_alta=False)
    centro(doc, c["curso"].upper(), True)
    centro(doc, f'{c["disciplina"].upper()} – TURMA {c["turma"]}', True, depois=60)
    for nome in c["integrantes"]:
        centro(doc, nome.upper())
    centro(doc, "", antes=80)
    centro(doc, c["titulo"], True, 14)
    centro(doc, c["subtitulo"][0].upper() + c["subtitulo"][1:], False, 12, depois=170)
    centro(doc, c["cidade"].upper() if not c["cidade"].startswith("[") else c["cidade"])
    centro(doc, c["ano"])
    quebra(doc)

    # folha de rosto
    for nome in c["integrantes"]:
        centro(doc, nome.upper())
    centro(doc, "", antes=110)
    centro(doc, c["titulo"], True, 14)
    centro(doc, c["subtitulo"][0].upper() + c["subtitulo"][1:], depois=60)
    nota = doc.add_paragraph()
    nota.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    nota.paragraph_format.left_indent = Cm(8)
    nota.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    runs(nota, f'Relatório técnico apresentado à disciplina de {c["disciplina"]} (2ª Unidade) do curso de '
               f'{c["curso"]}, turma {c["turma"]}, como requisito parcial de avaliação do trabalho em equipe '
               f'"ORM e Data Warehousing".', 11)
    nota2 = doc.add_paragraph()
    nota2.paragraph_format.left_indent = Cm(8)
    nota2.paragraph_format.space_before = Pt(12)
    runs(nota2, f'Professor: {c["professor"]}', 11)
    centro(doc, "", antes=150)
    centro(doc, c["cidade"].upper() if not c["cidade"].startswith("[") else c["cidade"])
    centro(doc, c["ano"])
    quebra(doc)

    # resumo
    centro(doc, "RESUMO", True, depois=18)
    r = doc.add_paragraph()
    r.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    runs(r, "Este relatório descreve a construção, de ponta a ponta, de um sistema de vendas por cupom fiscal "
            "para uma rede de supermercados e do Data Warehouse alimentado por ele. Na primeira etapa, o sistema "
            "transacional (OLTP) foi implementado em Java com a especificação JPA 2.1 e o Hibernate ORM 5.2.10 sobre "
            "PostgreSQL, com nove entidades, herança, classe embutida, camada DAO genérica, dez consultas JPQL e três "
            "consultas com Criteria API, populado com 200 clientes, 100 produtos, 5 lojas e 2.000 cupons ao longo de "
            "dois anos. Na segunda etapa, os dados foram levados por um processo ETL em PL/pgSQL, com área de staging, "
            "chaves substitutas, tratamento de nulos, padronização de textos, carga incremental e dimensão de mudança "
            "lenta do tipo 2, para dois modelos dimensionais do mesmo assunto: estrela e floco de neve. Sobre o "
            "Data Warehouse foram executadas consultas OLAP de roll-up, drill-down, slice, dice e pivot, comparado o "
            "tempo de uma mesma consulta nos três modelos e aplicadas duas técnicas de mineração de dados: regras de "
            "associação (Apriori) e agrupamento de clientes (k-means sobre RFM). Os resultados mostram que o modelo "
            "estrela respondeu a consulta analítica mais rápido que o OLTP e o floco de neve, que os cupons formam "
            "“missões de compra” bem definidas, como o cuscuz nordestino (Flocão de Milho → Carne de Sol, lift 6,85), "
            "e que 16% dos clientes geram 37% do faturamento.")
    k = doc.add_paragraph()
    k.paragraph_format.space_before = Pt(12)
    runs(k, "**Palavras-chave:** mapeamento objeto-relacional; JPA; Hibernate; data warehouse; ETL; OLAP; mineração de dados.")
    quebra(doc)

    # sumario
    centro(doc, "SUMÁRIO", True, depois=18)
    campo(doc.add_paragraph(), 'TOC \\o "1-2" \\h \\z \\u',
          "Clique com o botão direito e escolha “Atualizar campo” para gerar o sumário.")


# --------------------------------------------------------------------------- texto


def corpo(rel):
    p, h1, h2, q, itens, codigo, figura, tabela = rel.p, rel.h1, rel.h2, rel.q, rel.itens, rel.codigo, rel.figura, rel.tabela

    # ===================================================================== 1
    h1("1 Introdução", nova_pagina=False)
    p("Supermercados registram milhares de cupons fiscais por mês. Cada cupom é uma transação curta: o caixa "
      "identifica o cliente, passa os produtos e registra a forma de pagamento. O banco que guarda essas transações "
      "precisa ser rápido para gravar e consistente, por isso é normalizado. Já as perguntas da gerência, como "
      "“qual categoria mais fatura em cada estado?” ou “quais produtos são comprados juntos?”, exigem ler e somar "
      "anos de vendas, um tipo de carga para o qual o banco transacional não foi desenhado.")
    p("Este trabalho trata desses dois mundos. A **parte prática** construiu, para a Equipe 4 (domínio "
      "Supermercado, fato “venda de produtos por cupom fiscal”), um sistema transacional (OLTP) em Java usando "
      "mapeamento objeto-relacional com JPA 2.1 e Hibernate 5.2.10, e, a partir dele, um Data Warehouse com dois "
      "modelos dimensionais (estrela e floco de neve), um processo ETL, consultas OLAP e uma análise de mineração "
      "de dados. A **parte teórica**, apresentada nas seções 2 e 3, explica os conceitos usados, sempre com exemplos "
      "tirados do próprio sistema. A seção 4 descreve o que foi construído e os resultados, a seção 5 responde às "
      "13 questões de fixação e a seção 6 traz as conclusões.")
    p("Todo o código, os scripts SQL, os diagramas e os resultados estão no repositório "
      "`github.com/devfilip1/SuperMarketDb`, organizado em `src/` (aplicação JPA), `sql/` (DDL do OLTP, do DW, ETL "
      "e OLAP), `mineracao/` (notebook Python) e `docs/` (documentação de cada entrega).")

    # ===================================================================== 2
    h1("2 Mapeamento objeto-relacional")
    h2("2.1 Conceito de ORM e a impedância objeto-relacional")
    p("Uma aplicação Java pensa em **objetos**: uma `Venda` tem uma lista de `ItemVenda`, cada item aponta para um "
      "`Produto`, e um `Cliente` é um tipo de `Pessoa`. Um banco relacional pensa em **tabelas** ligadas por chaves "
      "estrangeiras. A diferença entre esses dois modelos é chamada de **impedância objeto-relacional** "
      "(BAUER; KING; GREGORY, 2015) e aparece em cinco pontos:")
    itens([
        "**Identidade:** em Java, igualdade (`equals`) e identidade (`==`); no banco, a chave primária.",
        "**Herança:** `Cliente extends Pessoa` não existe no modelo relacional; mapeamos com "
        "`@Inheritance(strategy = JOINED)` (questão 1).",
        "**Associações:** objetos usam referências, que podem ser bidirecionais (`Venda.itens` e `ItemVenda.venda`); "
        "tabelas usam uma chave estrangeira (`item_venda.venda_id`), e o N:N exige tabela intermediária.",
        "**Granularidade:** `Endereco` é uma classe (`@Embeddable`), mas suas colunas ficam dentro de `pessoa` e `loja`.",
        "**Navegação:** `venda.getCliente().getNome()` em Java; no SQL, uma junção. Sem cuidado, gera o N+1 (questão 6).",
    ])
    p("O **ORM** (*Object-Relational Mapping*) resolve essa diferença com anotações que ligam classes e atributos a "
      "tabelas e colunas; o framework gera o SQL e controla cache e ciclo de vida, e o desenvolvedor trabalha só com "
      "objetos.")

    h2("2.2 OQL – Object Query Language")
    p("A OQL foi definida pelo **ODMG** (*Object Data Management Group*) como a linguagem de consulta padrão para "
      "bancos de dados orientados a objetos (CATTELL et al., 2000; ELMASRI; NAVATHE, 2018). Sua sintaxe lembra o "
      "SQL (`select ... from ... where`), mas a consulta é feita sobre **coleções de objetos** (*extents*) e permite "
      "navegar por atributos e relacionamentos com a notação de ponto, como em `v.cliente.nome`, sem escrever junções.")
    p("A JPQL e a HQL herdam essa ideia: consultam **entidades**, não tabelas, e o provedor traduz para SQL. A HQL "
      "nasceu no Hibernate e é um superconjunto da JPQL, padronizada na JPA (comparação na questão 2).")

    h2("2.3 JPA 2.1")
    p("A JPA (*Java Persistence API*, JSR 338) é a **especificação** padrão de persistência do Java. Ela define "
      "interfaces e anotações no pacote `javax.persistence`, mas não as implementa. Seus elementos principais são:")
    itens([
        "**Unidade de persistência:** `META-INF/persistence.xml`; a nossa, `vendasPU`, lista as 9 entidades e define "
        "driver, URL, dialeto e `hbm2ddl`.",
        "**EntityManagerFactory:** pesada, uma por aplicação (classe `JPAUtil`). **EntityManager:** leve, uma por "
        "unidade de trabalho; faz `persist`, `find`, `merge`, `remove`, consultas e transações, encapsuladas no "
        "`GenericDAO<T, ID>`.",
        "**Fetch e cascata:** `LAZY` carrega a associação só quando acessada; `EAGER`, junto. Todos os nossos "
        "`@ManyToOne` e o `@OneToOne` são `LAZY` (o padrão da JPA para eles é EAGER), e as consultas que precisam "
        "dos dados usam `JOIN FETCH`. A cascata propaga operações do pai para os filhos: `Venda.itens` usa "
        "`CascadeType.ALL` com `orphanRemoval`, porque o item só existe no cupom; `Venda.cliente` não tem cascata.",
    ])

    h2("2.4 Hibernate")
    p("O Hibernate (aqui, 5.2.10.Final) é a implementação da JPA mais usada. Sua `SessionFactory` e sua `Session` "
      "equivalem à `EntityManagerFactory` e ao `EntityManager`; desde a 5.2, a `Session` estende `EntityManager`, e o "
      "código JPA roda sem adaptação (RED HAT, 2017).")
    itens([
        "**Cache de 1º nível:** da `Session`, obrigatório: um `find` repetido na mesma unidade não volta ao banco. "
        "**Cache de 2º nível:** opcional, da `SessionFactory` (ex.: Ehcache); não foi usado.",
        "**Dialeto** adapta o SQL ao banco (`PostgreSQL95Dialect`); **hbm2ddl** gera ou atualiza o esquema a partir "
        "das entidades (usamos `update`).",
    ])

    # ===================================================================== 3
    h1("3 Data Warehousing")
    h2("3.1 Data Warehouse e Data Mart")
    p("Para Inmon (2005), um **Data Warehouse** é uma coleção de dados **orientada a assunto** (organizada por temas "
      "do negócio, como vendas), **integrada** (padroniza origens diferentes), **não volátil** (carregada e "
      "consultada, não alterada) e **variante no tempo** (todo dado ligado a um momento), que apoia a decisão. Um "
      "**Data Mart** é um subconjunto do DW focado em um departamento ou processo.")
    p("Inmon propõe uma abordagem *top-down*: primeiro um DW corporativo normalizado, depois os data marts. Kimball "
      "e Ross (2013) propõem a *bottom-up*: data marts dimensionais por processo, integrados por **dimensões "
      "conformadas**. Seguimos Kimball: um processo (venda por cupom), cujas dimensões Tempo, Produto e Cliente "
      "poderiam ser reaproveitadas por um data mart de estoque.")

    h2("3.2 Modelagem dimensional")
    itens([
        "**Fato:** registro de um evento mensurável do negócio. Nossa fato é `fato_venda`.",
        "**Dimensão:** contexto que descreve o fato (quem, o quê, onde, quando, como): `dim_cliente`, `dim_produto`, "
        "`dim_loja`, `dim_tempo` e `dim_pagamento`.",
        "**Medida:** valor numérico do fato, normalmente aditivo: `quantidade`, `preco_unitario` (não aditiva) e "
        "`valor_total`, medida derivada calculada no ETL (quantidade × preço unitário).",
        "**Granularidade:** o que uma linha da fato representa. A nossa é **um item vendido em um cupom fiscal** "
        "(questão 8).",
        "**Chave substituta (*surrogate key*):** inteiro sem significado gerado pelo DW, como `sk_cliente`, em vez da "
        "chave do OLTP (questão 10).",
        "**SCD (*Slowly Changing Dimension*):** no **tipo 1** o valor antigo é sobrescrito (nome e preço do produto); "
        "no **tipo 2** cria-se uma nova linha com nova chave e período de vigência, preservando o histórico (cidade e "
        "UF do cliente, com `data_inicio`, `data_fim`, `atual` e `versao`).",
    ])

    h2("3.3 Modelo estrela e modelo floco de neve")
    p("No **estrela**, cada dimensão é uma tabela desnormalizada ligada direto à fato (a categoria é coluna de "
      "`dim_produto`): consultas simples e rápidas, ao custo de redundância. No **floco de neve**, as dimensões são "
      "normalizadas em hierarquias (`dim_produto → dim_categoria`, `dim_loja → dim_cidade → dim_estado`): menos "
      "redundância, porém mais junções (KIMBALL; ROSS, 2013). O estrela é o padrão para análise; o floco se justifica "
      "com dimensões muito grandes ou hierarquias compartilhadas, como cidade/estado entre cliente e loja.")

    h2("3.4 ETL")
    p("ETL (*Extract, Transform, Load*) leva os dados das fontes ao DW: a **extração** lê; a **transformação** limpa, "
      "padroniza e integra; a **carga** grava dimensões e fato. A **staging** é a área intermediária onde se "
      "transforma sem tocar na origem. A **carga inicial** popula o DW; a **incremental** traz só o que mudou, "
      "controlada por data ou chave (marca d'água).")

    h2("3.5 OLTP x OLAP")
    p("O **OLTP** registra a operação diária: transações curtas de escrita, feitas por operadores, sobre dados atuais "
      "e normalizados. O **OLAP** responde a perguntas analíticas: consultas longas de leitura, feitas por gestores, "
      "sobre grande volume histórico (CHAUDHURI; DAYAL, 1997). O quadro completo está na questão 11.")
    p("O **ROLAP** guarda o cubo em tabelas relacionais (nosso caso: PostgreSQL com `GROUP BY ROLLUP/CUBE`); o "
      "**MOLAP**, em estruturas multidimensionais pré-calculadas; o **HOLAP** combina os dois. As operações roll-up, "
      "drill-down, slice, dice e pivot estão definidas e exemplificadas com SQL na questão 12.")

    h2("3.6 Mineração de dados")
    p("A mineração de dados é a etapa central do **KDD** (seleção, pré-processamento, transformação, mineração e "
      "interpretação) (FAYYAD; PIATETSKY-SHAPIRO; SMYTH, 1996). Suas tarefas são **classificação** (ex.: árvore de "
      "decisão), **regressão**, **agrupamento** (ex.: k-means) e **associação** (ex.: Apriori, de Agrawal e Srikant "
      "(1994), que usa o fato de que todo subconjunto de um conjunto frequente é frequente) (HAN; KAMBER; PEI, 2011).")

    # ===================================================================== 4
    h1("4 Desenvolvimento do sistema")
    h2("4.1 Etapa 1 – sistema OLTP com JPA e Hibernate")
    p("O sistema tem nove entidades: `Pessoa` (abstrata), `Cliente`, `Funcionario`, `CartaoFidelidade`, `Loja`, "
      "`Categoria`, `Produto`, `Venda` (o cupom fiscal) e `ItemVenda`, além da classe embutida `Endereco` e do "
      "enum `FormaPagamento` (dinheiro, débito, crédito e Pix). A Figura 1 mostra o diagrama de classes.")
    figura(IMG / "uml.png", "Diagrama de classes UML do sistema OLTP", 11.5)
    p("Os requisitos de mapeamento foram atendidos assim: `@OneToOne` em `Cliente.cartao`; `@OneToMany`/`@ManyToOne` "
      "bidirecional em `Venda.itens` ↔ `ItemVenda.venda`; a associação N:N entre `Venda` e `Produto` resolvida pela "
      "entidade `ItemVenda`; herança `JOINED`; `Endereco` como `@Embeddable` e `FormaPagamento` com `@Enumerated`; datas "
      "com `LocalDate` e `LocalDateTime`. O acesso é feito pela classe `GenericDAO<T, ID>` (um DAO por entidade), há 10 "
      "consultas JPQL (2 `@NamedQuery`) e 3 com Criteria API, e um menu de console faz o CRUD de clientes e produtos. O "
      "modelo relacional e o script DDL estão em `docs/entrega1` e `sql/oltp`.")
    p("Para os dados terem padrões reais, 40% dos cupons seguem uma “cesta típica” (churrasco, café da manhã, cuscuz, "
      "limpeza, higiene, feira do mês) e 30 clientes fiéis fazem cerca de 25% das compras. Resultado: **10.007 itens "
      "vendidos**, somando **R$ 372.057,92**.")

    h2("4.2 Etapa 2 – modelos dimensionais")
    p("Os modelos ficam nos esquemas `dw` (estrela) e `dw_floco` (floco de neve), com a mesma fato: um item por "
      "cupom, três medidas, o cupom como dimensão degenerada e cinco dimensões. A dimensão Tempo tem chave `AAAAMMDD`, "
      "e cada dimensão tem o membro 0, “Não informado”.")
    rel.figura_dupla(IMG / "estrela.png", "Modelo estrela (esquema dw)", 8.6,
                     IMG / "floco.png", "Modelo floco de neve (esquema dw_floco)", 6.6)

    h2("4.3 Etapa 2 – processo ETL")
    p("O ETL, em PL/pgSQL, roda com `CALL etl.executar()` (Figura 4). A **extração** copia os cadastros e só os "
      "itens com `id` acima da marca d'água de `etl.controle`. A **transformação**, na staging (`stg`), troca nulos "
      "por “Não informado”/“NI”, remove espaços extras, padroniza maiúsculas, UF e CPF e descarta itens inválidos. A "
      "**carga** gera a dimensão Tempo com `generate_series`, aplica SCD 1 em produto, loja e pagamento e SCD 2 em "
      "cliente, e insere a fato com chaves substitutas (o cliente na versão vigente na data da venda) e "
      "`valor_total` calculado. Depois, `etl.carregar_floco` normaliza o floco de neve e `etl.validar` compara OLTP, "
      "estrela e floco. Cada passo grava as contagens de antes e depois em `etl.log_carga`.")
    figura(IMG / "etl.png", "Fluxo do processo ETL", 16)
    tabela("Contagens registradas pelo ETL (log completo em docs/entrega2/log_execucao_etl.txt)",
           ["Execução", "Situação", "Fato estrela", "Fato floco", "OLTP", "Validação"],
           [["1 – inicial", "carga completa", "0 → 10.007", "0 → 10.007", "10.007 itens; R$ 372.057,92", "OK"],
            ["2 – incremental", "sem mudanças", "10.007 → 10.007", "10.007 → 10.007", "igual", "OK"],
            ["3 – incremental", "cliente mudou de cidade; cliente novo com nulos; cupom novo com 2 itens",
             "10.007 → 10.009", "10.007 → 10.009", "10.009 itens; R$ 372.130,70", "OK"]],
           [2.3, 4.2, 2.4, 2.4, 3.2, 1.5])
    p("Na execução 3, a cliente que mudou de João Pessoa/PB para “  recife ”/“pe” teve a versão 1 fechada e ganhou a "
      "versão 2 em Recife/PE, com nova chave; seus 31 cupons antigos seguem na versão 1. O cliente sem cidade e UF "
      "entrou como “Não informado”/“NI”.")

    h2("4.4 Consultas OLAP e comparação de desempenho")
    p("As dez consultas OLAP (duas por operação) estão em `sql/olap/01_consultas_olap.sql`. Achados: o **Açougue** é a "
      "categoria que mais fatura (33% do total), o **RN** responde por 61% do faturamento e, em 2025, o ticket médio "
      "foi de R$ 187,62.")
    p("A mesma pergunta (“faturamento por categoria e UF da loja em 2025”) rodou 30 vezes em cada modelo com "
      "`EXPLAIN ANALYZE` (`mineracao/medir_tempos.py`), com resultados idênticos.")
    tabela("Tempo da mesma consulta no OLTP, no estrela e no floco de neve (mediana de 30 execuções)",
           ["Modelo", "Junções", "Execução (ms)", "Planejamento (ms)"],
           [["OLTP (public)", "4", "4,057", "0,209"],
            ["Estrela (dw)", "3", "3,128", "0,201"],
            ["Floco de neve (dw_floco)", "6", "4,468", "0,451"]],
           [5.5, 2.2, 3.2, 3.6])
    p("O estrela foi cerca de 23% mais rápido que o OLTP e 30% mais rápido que o floco de neve, que gastou o dobro "
      "do tempo de planejamento por causa das seis junções. Com 10 mil linhas a diferença é de milissegundos; com "
      "milhões, tende a crescer, pois o filtro de ano cai numa dimensão pequena e `valor_total` já vem calculado.")

    h2("4.5 Mineração de dados")
    p("As técnicas rodam no notebook `mineracao/mineracao.ipynb` (pandas, mlxtend, scikit-learn), com as bases "
      "exportadas em CSV para `mineracao/dados/`.")
    p("**Regras de associação (Apriori).** Preparação: os 10.009 itens foram transformados em uma matriz de 2.001 "
      "cupons × 100 produtos (verdadeiro se o produto está no cupom). Parâmetros: suporte mínimo de 3%, confiança "
      "mínima de 50% e lift maior que 1. Resultado: 208 conjuntos frequentes e 528 regras, das quais 51 são simples "
      "(um produto → um produto). As de maior lift ligam ingredientes de uma mesma cesta, como molho de tomate e óleo → arroz "
      "(lift 11,5) e creme dental e papel higiênico → sabonete (lift 11,1).")
    p("**Agrupamento (k-means sobre RFM).** Preparação: recência (dias desde a última compra até 01/11/2026), "
      "frequência e valor de cada cliente, padronizados com `StandardScaler`. Parâmetros: k de 2 a 7 pelo cotovelo e "
      "pela silhueta; k = 2 teve a maior silhueta (0,63) mas só separava fiéis do resto, então escolhemos k = 4 "
      "(silhueta 0,48), onde a inércia achata (Tabela 3 e Figura 5).")
    tabela("Segmentos de clientes encontrados pelo k-means (k = 4)",
           ["Segmento", "Clientes", "Recência média (dias)", "Frequência média", "Valor médio (R$)", "% do faturamento"],
           [["VIP", "31", "32", "24,2", "4.488,80", "37,4%"],
            ["Regulares", "115", "38", "7,9", "1.439,80", "44,5%"],
            ["Esfriando", "50", "165", "6,6", "1.293,30", "17,4%"],
            ["Inativos", "4", "469", "4,0", "665,80", "0,7%"]],
           [2.6, 1.8, 3.0, 2.6, 2.8, 2.8])
    figura(MIN / "kmeans_segmentos.png", "Clientes por segmento (tamanho do ponto proporcional à recência)", 9.5)
    p("**Interpretação de negócio.** (1) A regra simples mais forte é **Flocão de Milho → Carne de Sol** (confiança "
      "56%, lift 6,85): os ingredientes do cuscuz devem ficar próximos e entrar em promoções casadas. (2) As regras "
      "formam “missões de compra” (churrasco, cuscuz, higiene, limpeza, feira), que podem orientar layout e encartes. "
      "(3) Os 31 clientes VIP (16% da base) geram 37% do faturamento: merecem um programa de fidelidade. (4) Os 50 "
      "clientes “Esfriando” estão há 165 dias sem comprar: são o alvo de uma campanha de reativação.")

    # ===================================================================== 5
    h1("5 Questões de fixação")
    q("Questão 1 – Impedância objeto-relacional: herança e muitos-para-muitos")
    p("**Herança:** em Java, `Cliente` e `Funcionario` herdam de `Pessoa` o nome, o CPF e o endereço. O banco "
      "relacional não tem herança, então é preciso escolher uma estratégia. Usamos `JOINED`: a tabela `pessoa` guarda os "
      "atributos comuns e `cliente`/`funcionario` guardam só os específicos, com a mesma chave primária. Uma consulta "
      "polimórfica como `SELECT p FROM Pessoa p` vira um SQL com junções externas entre as três tabelas, montado "
      "pelo Hibernate. **Muitos-para-muitos:** uma venda tem vários produtos e um produto aparece em várias vendas. Em "
      "Java isso seria uma `List<Produto>` dentro de `Venda`; no banco é obrigatório uma tabela intermediária. Como "
      "o item tem atributos próprios (quantidade e preço unitário na hora da venda), a associação foi promovida à "
      "entidade `ItemVenda`, com dois `@ManyToOne`.")
    q("Questão 2 – A mesma consulta em OQL, JPQL e SQL")
    p("Pergunta: “nome e total gasto dos clientes de Natal”. Em OQL e JPQL, navega-se pelos objetos; em SQL, é "
      "preciso juntar quatro tabelas e conhecer a herança `JOINED`.")
    codigo("""-- OQL (ODMG): consulta sobre o extent Vendas, navegando por ponto
select struct(nome: v.cliente.nome, total: sum(select i.quantidade * i.precoUnitario from i in v.itens))
from Vendas v
where v.cliente.endereco.cidade = "Natal"
group by v.cliente.nome

-- JPQL: entidades e atributos; o provedor gera as juncoes
SELECT c.nome, SUM(i.quantidade * i.precoUnitario)
FROM Venda v JOIN v.cliente c JOIN v.itens i
WHERE c.endereco.cidade = :cidade
GROUP BY c.id, c.nome

-- SQL (PostgreSQL): tabelas, colunas e juncoes explicitas
SELECT p.nome, SUM(i.quantidade * i.preco_unitario)
FROM venda v
JOIN cliente c    ON c.id = v.cliente_id
JOIN pessoa p     ON p.id = c.id
JOIN item_venda i ON i.venda_id = v.id
WHERE p.cidade = 'Natal'
GROUP BY p.id, p.nome;""")
    q("Questão 3 – Especificação JPA x Hibernate; troca por EclipseLink")
    p("A JPA é uma **especificação**: o contrato (`EntityManager` e anotações em `javax.persistence`). O Hibernate é "
      "uma **implementação** (*provider*) com extras (HQL, `Session`, filtros). Como nosso código usa só "
      "`javax.persistence`, trocar por EclipseLink muda apenas a configuração: a dependência no `pom.xml`, o "
      "`<provider>` no `persistence.xml` (`org.eclipse.persistence.jpa.PersistenceProvider`) e as propriedades "
      "`hibernate.*` (que viram `eclipselink.target-database` e `eclipselink.ddl-generation`). Entidades, DAOs e "
      "consultas continuam iguais.")
    q("Questão 4 – Os quatro estados de uma entidade")
    tabela("Estados de uma entidade JPA e métodos do EntityManager",
           ["Estado", "Significado", "Como chega / sai"],
           [["New (transiente)", "objeto criado com `new`, sem id e sem vínculo", "`new Cliente(...)`; sai com `persist()`"],
            ["Managed", "gerenciado: mudanças são gravadas no commit/flush", "`persist()`, `find()`, `getReference()`, consulta, `merge()` (devolve cópia gerenciada)"],
            ["Detached", "tem id, mas não é mais gerenciado", "`detach()`, `clear()`, `close()` ou fim da transação; volta com `merge()`"],
            ["Removed", "marcado para exclusão no commit", "`remove()` de entidade gerenciada; volta a managed com `persist()` antes do commit"]],
           [3.2, 5.6, 7.2])
    p("No `GenericDAO`, `salvar` chama `persist` (new → managed), `atualizar` chama `merge` (detached → managed, "
      "usado quando o menu edita um cliente carregado antes) e `remover` chama `remove` sobre uma referência "
      "gerenciada (managed → removed).")
    q("Questão 5 – SINGLE_TABLE, JOINED e TABLE_PER_CLASS")
    p("**SINGLE_TABLE** coloca toda a hierarquia em uma tabela com uma coluna discriminadora. É a mais rápida, sem "
      "junções, mas não é normalizada: as colunas das subclasses precisam aceitar nulo. **JOINED** usa uma tabela por "
      "classe, ligadas pela chave primária. É normalizada e permite `NOT NULL` nas colunas específicas, mas exige "
      "junções para montar o objeto. **TABLE_PER_CLASS** cria uma tabela completa por classe concreta, repetindo as "
      "colunas herdadas. Consultar uma subclasse é rápido, mas consultas polimórficas viram `UNION` e geração de chave "
      "é mais difícil. Escolhemos **JOINED** para manter `funcionario.matricula` como `NOT NULL UNIQUE`; com "
      "`SINGLE_TABLE`, a matrícula teria de aceitar nulo para os clientes.")
    q("Questão 6 – O problema N+1")
    p("Ocorre quando uma consulta traz N objetos (1 SELECT) e, ao navegar por uma associação LAZY de cada um, o ORM "
      "faz mais um SELECT por objeto (N SELECTs). Exemplo no nosso sistema: listar 20 cupons e imprimir "
      "`v.getCliente().getNome()` geraria 1 + 20 consultas. A solução é buscar tudo de uma vez com **JOIN FETCH** "
      "(`SELECT DISTINCT v FROM Venda v JOIN FETCH v.itens i JOIN FETCH i.produto WHERE v.id = :id`, nossa consulta "
      "Q3) ou com um **@EntityGraph**/`@NamedEntityGraph`, que declara os atributos a carregar e é passado como dica "
      "(`javax.persistence.fetchgraph`) em `find` ou na consulta.")
    q("Questão 7 – Por que o DW é não volátil e variante no tempo")
    p("É **não volátil** porque o ETL só acrescenta dados: não há `UPDATE` de fatos nem `DELETE` quando algo muda no "
      "OLTP. Quando a cidade de um cliente mudou, o DW não sobrescreveu a cidade: fechou a versão antiga e criou outra "
      "(SCD tipo 2), e as 31 vendas antigas continuam atribuídas a João Pessoa. É **variante no tempo** porque todo "
      "fato está ligado a `dim_tempo` e toda versão de cliente tem `data_inicio` e `data_fim`. Assim, é possível "
      "perguntar “quanto faturamos com clientes de João Pessoa em 2025?” e obter a resposta de 2025, não a de hoje.")
    q("Questão 8 – Granularidade da fato")
    p("Granularidade é o nível de detalhe de uma linha da fato. Escolhemos **um item vendido em um cupom fiscal** "
      "(uma linha de `item_venda` = uma linha de `fato_venda`), o menor nível disponível no OLTP. Com ela é possível "
      "analisar produto e categoria, somar até cupom, dia, loja ou cliente (agregar é sempre possível; desagregar, "
      "não) e aplicar regras de associação, que precisam saber quais produtos saíram no mesmo cupom. Uma fato por "
      "cupom inteiro perderia o produto; uma fato diária por loja perderia o cliente e o cupom.")
    q("Questão 9 – Estrela x floco de neve: número de junções")
    p("Para a consulta “faturamento de Bebidas por UF da loja”, o estrela usa **2 junções** (fato → `dim_produto`, "
      "fato → `dim_loja`), porque categoria e UF são colunas das próprias dimensões. O floco de neve usa **5 "
      "junções** (fato → `dim_produto` → `dim_categoria` e fato → `dim_loja` → `dim_cidade` → `dim_estado`). Com o "
      "filtro de ano, a consulta da Tabela 2 tem 3 junções no estrela e 6 no floco. As duas versões devolvem o "
      "mesmo resultado. O estrela é mais simples de escrever e mais rápido; o floco evita repetir o nome da categoria "
      "em cada produto e o nome do estado em cada cidade, e permite reaproveitar a hierarquia cidade → estado entre "
      "cliente e loja.")
    q("Questão 10 – Por que chaves substitutas")
    itens([
        "**Histórico (SCD 2):** o mesmo cliente do OLTP (`id_origem` = 11) tem duas linhas em `dim_cliente` (sk 1 e "
        "sk 201); a chave do OLTP não poderia ser chave primária.",
        "**Independência da origem:** se o OLTP reutilizar ou mudar uma chave, ou se outra fonte for integrada com "
        "chaves conflitantes, o DW não é afetado.",
        "**Membro “Não informado”:** a chave 0 representa ausência de valor sem violar a integridade da fato.",
        "**Desempenho:** inteiros pequenos e sequenciais deixam índices e junções da fato mais leves que chaves "
        "naturais longas, como o CPF.",
    ])
    q("Questão 11 – Quadro comparativo OLTP x OLAP")
    tabela("OLTP x OLAP no nosso sistema",
           ["Critério", "OLTP (esquema public)", "OLAP (esquemas dw e dw_floco)"],
           [["Objetivo", "registrar cupons e cadastros", "analisar vendas e apoiar decisões"],
            ["Usuário", "operador de caixa, atendente", "gerente, analista de BI"],
            ["Operações", "INSERT/UPDATE/DELETE curtos", "SELECT com agregações (ROLLUP, CUBE)"],
            ["Volume por operação", "poucas linhas (um cupom)", "milhares a milhões de linhas"],
            ["Dados", "atuais", "históricos (nov/2024 a nov/2026)"],
            ["Modelagem", "normalizada (3FN), 9 tabelas", "dimensional: estrela (desnormalizado) e floco"],
            ["Atualização", "contínua, pela aplicação JPA", "periódica, pelo ETL (carga incremental)"],
            ["Chaves", "naturais/de negócio (id, CPF)", "substitutas (sk_*)"],
            ["Histórico de mudanças", "sobrescreve (cidade nova apaga a antiga)", "preserva (SCD tipo 2)"],
            ["Desempenho otimizado para", "escrita e consulta por chave", "leitura e agregação"]],
           [3.8, 5.8, 6.4])
    q("Questão 12 – Operações OLAP com o SQL executado")
    p("Todas as consultas abaixo estão em `sql/olap/01_consultas_olap.sql` (há duas por operação; uma de cada é "
      "mostrada aqui).")
    p("**Roll-up** – agrega subindo na hierarquia de Tempo (mês → trimestre → ano → total geral). O "
      "`GROUP BY ROLLUP` gera os subtotais de cada nível; o resultado mostrou 2025 com R$ 183.682,29.")
    codigo("""SELECT t.ano, t.trimestre, t.nome_mes, SUM(f.valor_total) FROM dw.fato_venda f
JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo GROUP BY ROLLUP (t.ano, t.trimestre, (t.mes, t.nome_mes));""")
    p("**Drill-down** – parte do total e detalha: da categoria até o produto, descendo em Bebidas. Revelou que o "
      "Refrigerante Cola 2L é a bebida que mais fatura (R$ 6.604,99).")
    codigo("""SELECT p.categoria, p.nome, SUM(f.valor_total) FROM dw.fato_venda f
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
GROUP BY GROUPING SETS ((), (p.categoria), (p.categoria, p.nome))
HAVING GROUPING(p.nome) = 1 OR p.categoria = 'Bebidas';""")
    p("**Slice** – fixa uma dimensão em um valor (forma de pagamento = Pix) e analisa as demais por trimestre.")
    codigo("""SELECT t.ano, t.trimestre, SUM(f.valor_total) FROM dw.fato_venda f
JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo JOIN dw.dim_pagamento pg ON pg.sk_pagamento = f.sk_pagamento
WHERE pg.codigo = 'PIX' GROUP BY t.ano, t.trimestre;""")
    p("**Dice** – restringe várias dimensões: lojas do RN × Açougue e Bebidas × 2º semestre de 2025. No subcubo, "
      "o Açougue fatura cerca de 5 vezes mais que Bebidas em todas as lojas.")
    codigo("""SELECT l.nome, p.categoria, SUM(f.valor_total) FROM dw.fato_venda f
JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo JOIN dw.dim_loja l ON l.sk_loja = f.sk_loja
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto
WHERE l.estado = 'RN' AND p.categoria IN ('Acougue', 'Bebidas') AND t.ano = 2025 AND t.semestre = 2
GROUP BY l.nome, p.categoria;""")
    p("**Pivot** – gira o cubo: os anos, que seriam linhas, viram colunas, com uma categoria por linha.")
    codigo("""SELECT p.categoria, SUM(f.valor_total) FILTER (WHERE t.ano = 2025) AS "2025",
       SUM(f.valor_total) FILTER (WHERE t.ano = 2026) AS "2026"
FROM dw.fato_venda f JOIN dw.dim_tempo t ON t.sk_tempo = f.sk_tempo
JOIN dw.dim_produto p ON p.sk_produto = f.sk_produto GROUP BY p.categoria;""")
    q("Questão 13 – Suporte, confiança e lift")
    p("Para uma regra A → B: **suporte** é a fração dos cupons que contêm A e B juntos; **confiança** é, entre os "
      "cupons que têm A, a fração que também tem B (suporte(A∪B) / suporte(A)); **lift** é a confiança dividida pelo "
      "suporte de B, isto é, quantas vezes ter A aumenta a chance de ter B em relação a um cupom qualquer. Lift = 1 "
      "indica independência; lift > 1, associação positiva.")
    p("Regra encontrada: **Flocão de Milho 500g → Carne de Sol kg**, com suporte 0,043, confiança 0,565 e lift 6,85. "
      "Interpretação: 4,3% de todos os 2.001 cupons têm os dois produtos juntos; 56% dos clientes que levam flocão "
      "também levam carne de sol; e, como a carne de sol aparece sozinha em só 8,2% dos cupons, levar flocão torna a "
      "compra de carne de sol 6,85 vezes mais provável. É a “missão” cuscuz nordestino: vale expor os dois produtos "
      "juntos e não dar desconto nos dois ao mesmo tempo, já que um puxa a venda do outro.")

    # ===================================================================== 6
    h1("6 Conclusão")
    p("O trabalho percorreu todo o caminho do dado: da tela de cadastro, em Java, até a conclusão de negócio. O ORM "
      "permitiu escrever o sistema transacional apenas com objetos, deixando ao Hibernate a geração do SQL, a "
      "herança e a navegação entre associações. As escolhas de mapeamento (herança `JOINED`, associações `LAZY` com "
      "`JOIN FETCH` quando necessário, cascata só onde o filho depende do pai) foram justificadas pelo próprio "
      "domínio.")
    p("Na parte analítica, a granularidade de item por cupom e as chaves substitutas permitiram SCD tipo 2 e "
      "carga incremental, com a validação do ETL provando que OLTP, estrela e floco de neve guardam exatamente os "
      "mesmos 10.009 itens e o mesmo valor. A comparação de desempenho confirmou na prática o que a teoria prevê: o "
      "estrela, com menos junções e medida pré-calculada, foi o mais rápido; o floco de neve trocou desempenho por "
      "menos redundância. Por fim, a mineração transformou os dados em recomendações concretas: organizar a loja por "
      "missões de compra, criar um programa para os clientes VIP e reativar os clientes que estão esfriando.")
    p("Como trabalhos futuros, a equipe sugere agendar o ETL (por exemplo, com `pg_cron`), criar um painel de BI "
      "sobre o modelo estrela e aplicar uma árvore de decisão para prever quais clientes regulares tendem a se "
      "tornar VIP.")

    # ===================================================================== IA
    h2("6.1 Declaração de uso de ferramentas de inteligência artificial")
    p("Conforme as regras do trabalho, a equipe declara que utilizou o assistente de IA **Claude (Anthropic)** nas "
      "seguintes partes:")
    itens([
        "**Etapa 2 (Data Warehouse e ETL):** geração dos scripts DDL dos modelos estrela e floco de neve, das "
        "procedures de ETL (staging, SCD tipo 2, carga incremental, log e validação) e dos diagramas.",
        "**Etapa 3 (OLAP e mineração):** geração das consultas OLAP, do script de comparação de tempos e do notebook "
        "de mineração (Apriori e k-means), e ajuste da classe de carga para gerar cestas de compra realistas.",
        "**Relatório:** redação inicial deste texto, a partir dos resultados obtidos no sistema.",
        "**Etapa 1 (OLTP):** [confirmar com o responsável se houve uso de IA nesta etapa].",
    ])
    p("Todo o material gerado foi executado e validado pela equipe no PostgreSQL. As contagens, os tempos e os "
      "resultados de mineração apresentados vêm dessas execuções, e todos os integrantes revisaram o conteúdo para a "
      "arguição.")

    # ===================================================================== referencias
    h1("Referências", nova_pagina=True)
    refs = [
        "AGRAWAL, R.; SRIKANT, R. Fast algorithms for mining association rules. In: INTERNATIONAL CONFERENCE ON VERY "
        "LARGE DATA BASES, 20., 1994, Santiago. **Proceedings** [...]. San Francisco: Morgan Kaufmann, 1994. p. 487-499.",
        "BAUER, C.; KING, G.; GREGORY, G. **Java Persistence with Hibernate**. 2. ed. Shelter Island: Manning, 2015.",
        "CATTELL, R. G. G. et al. **The Object Data Standard**: ODMG 3.0. San Francisco: Morgan Kaufmann, 2000.",
        "CHAUDHURI, S.; DAYAL, U. An overview of data warehousing and OLAP technology. **ACM SIGMOD Record**, New York, "
        "v. 26, n. 1, p. 65-74, 1997.",
        "ELMASRI, R.; NAVATHE, S. B. **Sistemas de Banco de Dados**. 7. ed. São Paulo: Pearson, 2018.",
        "FAYYAD, U.; PIATETSKY-SHAPIRO, G.; SMYTH, P. From data mining to knowledge discovery in databases. **AI "
        "Magazine**, v. 17, n. 3, p. 37-54, 1996.",
        "HAN, J.; KAMBER, M.; PEI, J. **Data Mining**: concepts and techniques. 3. ed. Waltham: Morgan Kaufmann, 2011.",
        "INMON, W. H. **Building the Data Warehouse**. 4. ed. Indianapolis: Wiley, 2005.",
        "KEITH, M.; SCHINCARIOL, M. **Pro JPA 2 in Java EE 8**. 3. ed. New York: Apress, 2018.",
        "KIMBALL, R.; ROSS, M. **The Data Warehouse Toolkit**: the definitive guide to dimensional modeling. 3. ed. "
        "Indianapolis: Wiley, 2013.",
        "ORACLE. **JSR 338**: Java Persistence API, version 2.1. 2013. Disponível em: "
        "https://jcp.org/en/jsr/detail?id=338. Acesso em: 22 nov. 2026.",
        "POSTGRESQL GLOBAL DEVELOPMENT GROUP. **PostgreSQL 17 Documentation**. 2024. Disponível em: "
        "https://www.postgresql.org/docs/17/. Acesso em: 22 nov. 2026.",
        "RED HAT. **Hibernate ORM 5.2 User Guide**. 2017. Disponível em: "
        "https://docs.jboss.org/hibernate/orm/5.2/userguide/html_single/Hibernate_User_Guide.html. "
        "Acesso em: 22 nov. 2026.",
    ]
    for ref in refs:
        par = rel.doc.add_paragraph()
        par.alignment = WD_ALIGN_PARAGRAPH.LEFT
        par.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
        par.paragraph_format.space_after = Pt(12)
        runs(par, ref)


def main():
    doc = Document()
    configurar(doc)
    pre_textuais(doc)

    # secao textual: numero de pagina no canto superior direito
    sec = doc.add_section(WD_SECTION.NEW_PAGE)
    sec.header.is_linked_to_previous = False
    cab = sec.header.paragraphs[0]
    cab.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    campo(cab, "PAGE", "1")
    doc.sections[0].different_first_page_header_footer = False

    corpo(Rel(doc))
    destino = AQUI / "relatorio_tecnico.docx"
    doc.save(destino)
    print("ok", destino)


if __name__ == "__main__":
    main()
