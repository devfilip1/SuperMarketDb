package br.edu.bd2.supermercado.ui;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.dao.ClienteDAO;
import br.edu.bd2.supermercado.modelo.Cliente;
import br.edu.bd2.supermercado.modelo.Endereco;
import br.edu.bd2.supermercado.util.JPAUtil;

public class MenuCliente {

    public void abrir() {
        while (true) {
            System.out.println("\n--- Clientes ---\n1 - Listar\n2 - Cadastrar\n3 - Alterar\n4 - Excluir\n0 - Voltar");
            String op = Console.ler("Opcao");
            if (op.equals("0")) {
                return;
            }
            EntityManager em = JPAUtil.getEntityManager();
            try {
                ClienteDAO dao = new ClienteDAO(em);
                switch (op) {
                    case "1": listar(dao); break;
                    case "2": cadastrar(dao); break;
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

    private void listar(ClienteDAO dao) {
        for (Cliente c : dao.listarTodos()) {
            System.out.printf("%4d  %-35s %s  %s%n", c.getId(), c.getNome(), c.getCpf(), c.getEndereco());
        }
    }

    private void cadastrar(ClienteDAO dao) {
        Cliente c = new Cliente(Console.ler("Nome"), Console.ler("CPF (11 digitos)"),
                new Endereco(Console.ler("Logradouro"), Console.ler("Cidade"), Console.ler("UF")));
        dao.salvar(c);
        System.out.println("Cliente cadastrado com id " + c.getId() + ".");
    }

    private void alterar(ClienteDAO dao) {
        Cliente c = dao.buscarPorId(Console.lerId("Id do cliente"));
        if (c == null) {
            System.out.println("Cliente nao encontrado.");
            return;
        }
        Endereco e = c.getEndereco();
        c.setNome(Console.ler("Nome", c.getNome()));
        e.setLogradouro(Console.ler("Logradouro", e.getLogradouro()));
        e.setCidade(Console.ler("Cidade", e.getCidade()));
        e.setEstado(Console.ler("UF", e.getEstado()));
        dao.atualizar(c);
        System.out.println("Cliente alterado.");
    }

    private void excluir(ClienteDAO dao) {
        dao.remover(Console.lerId("Id do cliente"));
        System.out.println("Cliente excluido.");
    }
}
