package br.edu.bd2.supermercado.carga;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.CartaoFidelidade;
import br.edu.bd2.supermercado.modelo.Categoria;
import br.edu.bd2.supermercado.modelo.Cliente;
import br.edu.bd2.supermercado.modelo.Endereco;
import br.edu.bd2.supermercado.modelo.FormaPagamento;
import br.edu.bd2.supermercado.modelo.Funcionario;
import br.edu.bd2.supermercado.modelo.Loja;
import br.edu.bd2.supermercado.modelo.Produto;
import br.edu.bd2.supermercado.modelo.Venda;
import br.edu.bd2.supermercado.util.JPAUtil;

public class CargaDados {

    private static final int CLIENTES = 200;
    private static final int VENDAS = 2000;
    private static final LocalDate INICIO = LocalDate.of(2024, 11, 1);
    private static final LocalDate FIM = LocalDate.of(2026, 10, 31);

    private static final String[][] LOJAS = {
        { "Bom Lar Centro", "Av. Rio Branco, 512", "Natal", "RN" },
        { "Bom Lar Ponta Negra", "Av. Roberto Freire, 3100", "Natal", "RN" },
        { "Bom Lar Parnamirim", "Av. Brigadeiro Everaldo Breves, 870", "Parnamirim", "RN" },
        { "Bom Lar Manaira", "Av. Flavio Ribeiro Coutinho, 220", "Joao Pessoa", "PB" },
        { "Bom Lar Boa Viagem", "Av. Conselheiro Aguiar, 1450", "Recife", "PE" },
    };

    private static final String[][] CATALOGO = {
        { "Mercearia", "Arroz Tipo 1 5kg;27.90", "Feijao Carioca 1kg;8.49", "Acucar Cristal 1kg;4.79", "Cafe Torrado 250g;12.99",
          "Macarrao Espaguete 500g;4.59", "Oleo de Soja 900ml;7.99", "Farinha de Mandioca 1kg;6.49", "Flocao de Milho 500g;2.99",
          "Molho de Tomate 340g;2.89", "Sal Refinado 1kg;2.49" },
        { "Hortifruti", "Banana Prata kg;5.99", "Maca Gala kg;10.99", "Laranja Pera kg;4.49", "Tomate kg;7.49", "Cebola kg;5.49",
          "Batata Inglesa kg;6.29", "Cenoura kg;4.99", "Mamao Formosa kg;6.99", "Alface Crespa;2.99", "Coentro Maco;1.99" },
        { "Acougue", "Carne Moida kg;42.90", "Alcatra kg;54.90", "Picanha kg;79.90", "Costela Bovina kg;29.90", "Carne de Sol kg;49.90",
          "Frango Inteiro kg;12.49", "Peito de Frango kg;22.90", "Linguica Toscana kg;24.90", "File de Tilapia kg;49.90",
          "Coxa e Sobrecoxa kg;14.90" },
        { "Frios e Laticinios", "Leite Integral 1L;5.29", "Iogurte Natural 170g;3.49", "Manteiga 200g;14.90", "Margarina 500g;8.99",
          "Requeijao 200g;8.49", "Queijo Mussarela kg;49.90", "Presunto kg;34.90", "Queijo Coalho kg;44.90",
          "Creme de Leite 200g;3.99", "Leite Condensado 395g;7.49" },
        { "Padaria", "Pao Frances kg;16.90", "Pao de Forma 500g;8.99", "Pao Integral 500g;10.49", "Pao de Queijo 400g;13.90",
          "Bolo de Milho;14.90", "Bolo de Chocolate;16.90", "Coxinha;5.50", "Torta de Frango Fatia;8.90",
          "Biscoito Cream Cracker 400g;5.49", "Rosca Doce;9.90" },
        { "Bebidas", "Refrigerante Cola 2L;10.99", "Refrigerante Guarana 2L;8.49", "Cerveja Lata 350ml;3.99",
          "Cerveja Long Neck 330ml;6.49", "Agua Mineral 500ml;1.99", "Agua Mineral 1,5L;3.49", "Suco de Uva 1L;14.90",
          "Suco de Caju 500ml;6.99", "Vinho Tinto 750ml;24.90", "Cachaca 965ml;15.90" },
        { "Limpeza", "Sabao em Po 1,6kg;22.90", "Amaciante 2L;15.90", "Agua Sanitaria 2L;6.49", "Detergente 500ml;2.79",
          "Desinfetante 2L;11.90", "Esponja Pack 3;4.99", "Saco de Lixo 50L;7.49", "Limpador Multiuso 500ml;5.99",
          "Sabao em Barra 5un;9.90", "Lustra Moveis 200ml;8.49" },
        { "Higiene", "Creme Dental 90g;4.99", "Escova Dental;7.99", "Sabonete 85g;2.49", "Shampoo 350ml;17.90",
          "Condicionador 350ml;18.90", "Desodorante 150ml;15.90", "Papel Higienico 12 rolos;21.90", "Fralda G 30un;54.90",
          "Absorvente 8un;5.99", "Fio Dental 50m;6.99" },
        { "Matinais", "Leite em Po 400g;21.90", "Achocolatado 400g;9.49", "Cereal Matinal 300g;14.90", "Aveia em Flocos 250g;5.99",
          "Biscoito Recheado 130g;2.79", "Geleia de Morango 230g;11.90", "Granola 500g;16.90", "Mel 280g;19.90",
          "Torrada 160g;6.49", "Cafe Soluvel 100g;13.90" },
        { "Bazar", "Carvao 3kg;17.90", "Fosforo Pack 10;3.49", "Pilha AA Pack 4;16.90", "Copo Descartavel 100un;6.49",
          "Vela Pack 8;7.99", "Lampada LED 9W;12.90", "Papel Aluminio 30cm;8.99", "Filme PVC 28cm;7.49",
          "Guardanapo 50un;3.99", "Prato Descartavel 10un;5.49" },
    };

    private static final String[] NOMES = { "Maria", "Ana", "Francisca", "Antonia", "Juliana", "Fernanda", "Patricia",
            "Camila", "Beatriz", "Larissa", "Jose", "Joao", "Antonio", "Francisco", "Carlos", "Paulo", "Pedro", "Lucas",
            "Rafael", "Marcos" };
    private static final String[] SOBRENOMES = { "Silva", "Santos", "Oliveira", "Souza", "Lima", "Pereira", "Ferreira",
            "Costa", "Almeida", "Nascimento", "Medeiros", "Dantas", "Bezerra", "Cavalcanti", "Araujo" };
    private static final String[] RUAS = { "Rua Joao Pessoa", "Av. Prudente de Morais", "Rua Apodi", "Av. Hermes da Fonseca",
            "Rua Mossoro", "Av. Salgado Filho", "Av. Epitacio Pessoa", "Rua da Aurora", "Av. Boa Viagem", "Rua do Sol" };

    private final EntityManager em;
    private final Random rnd = new Random(2026);
    private long cpf = 10000000000L;

    public CargaDados(EntityManager em) {
        this.em = em;
    }

    public static void main(String[] args) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            new CargaDados(em).executar();
        } finally {
            em.close();
            JPAUtil.fechar();
        }
    }

    public void executar() {
        if (em.createQuery("SELECT COUNT(v) FROM Venda v", Long.class).getSingleResult() > 0) {
            System.out.println("O banco ja possui vendas; carga cancelada.");
            return;
        }
        em.getTransaction().begin();
        try {
            List<Loja> lojas = new ArrayList<>();
            List<List<Funcionario>> operadores = new ArrayList<>();
            int matricula = 1;
            for (String[] l : LOJAS) {
                Loja loja = new Loja(l[0], new Endereco(l[1], l[2], l[3]));
                em.persist(loja);
                lojas.add(loja);
                List<Funcionario> caixa = new ArrayList<>();
                for (int i = 0; i < 2; i++) {
                    Funcionario f = new Funcionario(nome(), novoCpf(), endereco(l[2], l[3]), String.format("F%03d", matricula++));
                    em.persist(f);
                    caixa.add(f);
                }
                operadores.add(caixa);
            }

            List<Produto> produtos = new ArrayList<>();
            for (String[] cat : CATALOGO) {
                Categoria categoria = new Categoria(cat[0]);
                em.persist(categoria);
                for (int i = 1; i < cat.length; i++) {
                    String[] p = cat[i].split(";");
                    Produto produto = new Produto(p[0], new BigDecimal(p[1]), categoria);
                    em.persist(produto);
                    produtos.add(produto);
                }
            }

            List<Cliente> clientes = new ArrayList<>();
            for (int i = 0; i < CLIENTES; i++) {
                String[] loja = LOJAS[rnd.nextInt(LOJAS.length)];
                Cliente c = new Cliente(nome(), novoCpf(), endereco(loja[2], loja[3]));
                if (i % 2 == 0) {
                    c.setCartao(new CartaoFidelidade(String.format("6050%012d", i + 1), dataAleatoria()));
                }
                em.persist(c);
                clientes.add(c);
            }

            FormaPagamento[] formas = FormaPagamento.values();
            for (int i = 0; i < VENDAS; i++) {
                int l = rnd.nextInt(lojas.size());
                LocalDateTime dataHora = dataAleatoria().atTime(8 + rnd.nextInt(14), rnd.nextInt(60));
                Venda v = new Venda(dataHora, clientes.get(rnd.nextInt(clientes.size())), lojas.get(l),
                        operadores.get(l).get(rnd.nextInt(2)), formas[rnd.nextInt(formas.length)]);
                Collections.shuffle(produtos, rnd);
                int itens = 1 + rnd.nextInt(8);
                for (int j = 0; j < itens; j++) {
                    v.adicionarItem(produtos.get(j), 1 + rnd.nextInt(4));
                }
                em.persist(v);
            }
            em.getTransaction().commit();
            System.out.println("Carga concluida: 5 lojas, 10 funcionarios, " + produtos.size() + " produtos, "
                    + CLIENTES + " clientes, " + VENDAS + " vendas.");
        } catch (RuntimeException e) {
            em.getTransaction().rollback();
            throw e;
        }
    }

    private String nome() {
        return NOMES[rnd.nextInt(NOMES.length)] + " " + SOBRENOMES[rnd.nextInt(SOBRENOMES.length)] + " "
                + SOBRENOMES[rnd.nextInt(SOBRENOMES.length)];
    }

    private String novoCpf() {
        cpf += 1 + rnd.nextInt(999999);
        return String.valueOf(cpf);
    }

    private Endereco endereco(String cidade, String estado) {
        return new Endereco(RUAS[rnd.nextInt(RUAS.length)] + ", " + (1 + rnd.nextInt(2000)), cidade, estado);
    }

    private LocalDate dataAleatoria() {
        return INICIO.plusDays(rnd.nextInt((int) ChronoUnit.DAYS.between(INICIO, FIM) + 1));
    }
}
