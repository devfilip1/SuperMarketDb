package br.edu.bd2.supermercado.ui;

import java.math.BigDecimal;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.dao.CategoriaDAO;
import br.edu.bd2.supermercado.dao.ProdutoDAO;
import br.edu.bd2.supermercado.modelo.Categoria;
import br.edu.bd2.supermercado.modelo.Produto;
import br.edu.bd2.supermercado.util.JPAUtil;

public class MenuProduto {

    public void abrir() {
        while (true) {
            System.out.println("\n--- Produtos ---\n1 - Listar\n2 - Cadastrar\n3 - Alterar\n4 - Excluir\n0 - Voltar");
            String op = Console.ler("Opcao");
            if (op.equals("0")) {
                return;
            }
            EntityManager em = JPAUtil.getEntityManager();
            try {
                ProdutoDAO dao = new ProdutoDAO(em);
                switch (op) {
                    case "1": listar(dao); break;
                    case "2": cadastrar(dao, em); break;
                    case "3": alterar(dao); break;
                    case "4": excluir(dao); break;
                    default: System.out.println("Opcao invalida.");
                }
            } catch (RuntimeException e) {
                System.out.println("Operacao nao realizada: " + Console.causa(e));
            } finally {
                em.close();
            }
        }
    }

    private void listar(ProdutoDAO dao) {
        for (Produto p : dao.listarTodos()) {
            System.out.printf("%4d  %-32s R$ %8s  %s%n", p.getId(), p.getNome(), p.getPreco(), p.getCategoria().getNome());
        }
    }

    private void cadastrar(ProdutoDAO dao, EntityManager em) {
        CategoriaDAO categorias = new CategoriaDAO(em);
        for (Categoria c : categorias.listarTodos()) {
            System.out.println("  " + c.getId() + " - " + c.getNome());
        }
        Categoria categoria = categorias.buscarPorId(Console.lerId("Id da categoria"));
        if (categoria == null) {
            System.out.println("Categoria nao encontrada.");
            return;
        }
        Produto p = new Produto(Console.ler("Nome"), new BigDecimal(Console.ler("Preco (ex.: 9.90)")), categoria);
        dao.salvar(p);
        System.out.println("Produto cadastrado com id " + p.getId() + ".");
    }

    private void alterar(ProdutoDAO dao) {
        Produto p = dao.buscarPorId(Console.lerId("Id do produto"));
        if (p == null) {
            System.out.println("Produto nao encontrado.");
            return;
        }
        p.setNome(Console.ler("Nome", p.getNome()));
        p.setPreco(new BigDecimal(Console.ler("Preco", p.getPreco().toString())));
        dao.atualizar(p);
        System.out.println("Produto alterado.");
    }

    private void excluir(ProdutoDAO dao) {
        dao.remover(Console.lerId("Id do produto"));
        System.out.println("Produto excluido.");
    }
}
