package br.edu.bd2.supermercado;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.consulta.ConsultasCriteria;
import br.edu.bd2.supermercado.consulta.ConsultasJPQL;
import br.edu.bd2.supermercado.modelo.Cliente;
import br.edu.bd2.supermercado.modelo.ItemVenda;
import br.edu.bd2.supermercado.modelo.Produto;
import br.edu.bd2.supermercado.modelo.Venda;
import br.edu.bd2.supermercado.ui.Console;
import br.edu.bd2.supermercado.ui.MenuCliente;
import br.edu.bd2.supermercado.ui.MenuProduto;
import br.edu.bd2.supermercado.util.JPAUtil;

public class App {

    public static void main(String[] args) {
        try {
            while (true) {
                System.out.println("\n=== Supermercado Bom Lar ===\n1 - Clientes\n2 - Produtos\n3 - Executar as 13 consultas\n0 - Sair");
                switch (Console.ler("Opcao")) {
                    case "1": new MenuCliente().abrir(); break;
                    case "2": new MenuProduto().abrir(); break;
                    case "3": executarConsultas(); break;
                    case "0": return;
                    default: System.out.println("Opcao invalida.");
                }
            }
        } finally {
            JPAUtil.fechar();
        }
    }

    private static void executarConsultas() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            ConsultasJPQL jpql = new ConsultasJPQL(em);
            ConsultasCriteria criteria = new ConsultasCriteria(em);
            LocalDateTime inicio2025 = LocalDateTime.of(2025, 1, 1, 0, 0);
            LocalDateTime fim2025 = LocalDateTime.of(2025, 12, 31, 23, 59, 59);

            System.out.println("\nQ1 - Clientes com total comprado acima de R$ 3.000");
            imprimir(jpql.q01ClientesComTotalAcimaDe(new BigDecimal("3000")));

            System.out.println("\nQ2 - Produtos da categoria Bebidas");
            jpql.q02ProdutosDaCategoria("Bebidas").forEach(App::imprimir);

            System.out.println("\nQ3 - Cupom fiscal 1 com itens");
            Venda cupom = jpql.q03CupomComItens(1L);
            System.out.println("  Cupom " + cupom.getId() + " de " + cupom.getDataHora() + " - " + cupom.getFormaPagamento());
            for (ItemVenda i : cupom.getItens()) {
                System.out.println("  " + i.getQuantidade() + " x " + i.getProduto().getNome() + " R$ " + i.getPrecoUnitario());
            }
            System.out.println("  Total: R$ " + cupom.getTotal());

            System.out.println("\nQ4 - Cupons da loja 1, pagina 1 (5 por pagina)");
            jpql.q04CuponsDaLoja(1L, 0, 5).forEach(v -> System.out.println("  Cupom " + v.getId() + " - " + v.getDataHora()));

            System.out.println("\nQ5 - Faturamento por loja em 2025");
            imprimir(jpql.q05FaturamentoPorLoja(inicio2025, fim2025));

            System.out.println("\nQ6 - Produtos com preco acima da media");
            jpql.q06ProdutosAcimaDaMedia().forEach(App::imprimir);

            System.out.println("\nQ7 - 5 produtos mais vendidos");
            imprimir(jpql.q07ProdutosMaisVendidos(5));

            System.out.println("\nQ8 - Faturamento por categoria");
            imprimir(jpql.q08FaturamentoPorCategoria());

            System.out.println("\nQ9 - Formas de pagamento com mais de 400 cupons");
            imprimir(jpql.q09FormasDePagamentoComMaisDe(400));

            System.out.println("\nQ10 - Clientes de Natal com cartao fidelidade");
            for (Cliente c : jpql.q10ClientesComCartaoNaCidade("Natal")) {
                System.out.println("  " + c.getNome() + " - cartao " + c.getCartao().getNumero());
            }

            System.out.println("\nC1 - Produtos de Limpeza ate R$ 10 (filtro de nome nao informado)");
            criteria.c01BuscarProdutos(null, "Limpeza", new BigDecimal("10")).forEach(App::imprimir);

            Cliente cliente = cupom.getCliente();
            System.out.println("\nC2 - Cupons de " + cliente.getNome() + " (CPF " + cliente.getCpf() + ") em 2025");
            criteria.c02CuponsDoCliente(cliente.getCpf(), inicio2025, fim2025)
                    .forEach(v -> System.out.println("  Cupom " + v.getId() + " - " + v.getDataHora()));

            System.out.println("\nC3 - Cupons emitidos por loja");
            imprimir(criteria.c03CuponsPorLoja());
        } finally {
            em.close();
        }
    }

    private static void imprimir(List<Object[]> linhas) {
        linhas.forEach(l -> System.out.println("  " + Arrays.toString(l)));
    }

    private static void imprimir(Produto p) {
        System.out.println("  " + p.getNome() + " - R$ " + p.getPreco());
    }
}
