package br.edu.bd2.supermercado.consulta;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Cliente;
import br.edu.bd2.supermercado.modelo.Produto;
import br.edu.bd2.supermercado.modelo.Venda;

public class ConsultasJPQL {

    private final EntityManager em;

    public ConsultasJPQL(EntityManager em) {
        this.em = em;
    }

    public List<Object[]> q01ClientesComTotalAcimaDe(BigDecimal minimo) {
        return em.createNamedQuery("Venda.totalPorCliente", Object[].class)
                .setParameter("minimo", minimo)
                .getResultList();
    }

    public List<Produto> q02ProdutosDaCategoria(String categoria) {
        return em.createNamedQuery("Produto.porCategoria", Produto.class)
                .setParameter("categoria", categoria)
                .getResultList();
    }

    public Venda q03CupomComItens(Long numeroCupom) {
        return em.createQuery(
                "SELECT DISTINCT v FROM Venda v JOIN FETCH v.itens i JOIN FETCH i.produto WHERE v.id = :id",
                Venda.class)
                .setParameter("id", numeroCupom)
                .getSingleResult();
    }

    public List<Venda> q04CuponsDaLoja(Long lojaId, int pagina, int tamanho) {
        return em.createQuery(
                "SELECT v FROM Venda v WHERE v.loja.id = :loja ORDER BY v.dataHora DESC", Venda.class)
                .setParameter("loja", lojaId)
                .setFirstResult(pagina * tamanho)
                .setMaxResults(tamanho)
                .getResultList();
    }

    public List<Object[]> q05FaturamentoPorLoja(LocalDateTime inicio, LocalDateTime fim) {
        return em.createQuery(
                "SELECT l.nome, COUNT(DISTINCT v), SUM(i.quantidade * i.precoUnitario) "
              + "FROM Venda v JOIN v.loja l JOIN v.itens i "
              + "WHERE v.dataHora BETWEEN :inicio AND :fim "
              + "GROUP BY l.nome ORDER BY SUM(i.quantidade * i.precoUnitario) DESC", Object[].class)
                .setParameter("inicio", inicio)
                .setParameter("fim", fim)
                .getResultList();
    }

    public List<Produto> q06ProdutosAcimaDaMedia() {
        return em.createQuery(
                "SELECT p FROM Produto p WHERE p.preco > (SELECT AVG(p2.preco) FROM Produto p2) ORDER BY p.preco DESC",
                Produto.class)
                .getResultList();
    }

    public List<Object[]> q07ProdutosMaisVendidos(int n) {
        return em.createQuery(
                "SELECT p.nome, SUM(i.quantidade) FROM ItemVenda i JOIN i.produto p "
              + "GROUP BY p.id, p.nome ORDER BY SUM(i.quantidade) DESC", Object[].class)
                .setMaxResults(n)
                .getResultList();
    }

    public List<Object[]> q08FaturamentoPorCategoria() {
        return em.createQuery(
                "SELECT c.nome, SUM(i.quantidade * i.precoUnitario) "
              + "FROM ItemVenda i JOIN i.produto p JOIN p.categoria c "
              + "GROUP BY c.nome ORDER BY SUM(i.quantidade * i.precoUnitario) DESC", Object[].class)
                .getResultList();
    }

    public List<Object[]> q09FormasDePagamentoComMaisDe(long minimoCupons) {
        return em.createQuery(
                "SELECT v.formaPagamento, COUNT(v) FROM Venda v "
              + "GROUP BY v.formaPagamento HAVING COUNT(v) > :minimo ORDER BY COUNT(v) DESC", Object[].class)
                .setParameter("minimo", minimoCupons)
                .getResultList();
    }

    public List<Cliente> q10ClientesComCartaoNaCidade(String cidade) {
        return em.createQuery(
                "SELECT c FROM Cliente c JOIN FETCH c.cartao WHERE c.endereco.cidade = :cidade ORDER BY c.nome",
                Cliente.class)
                .setParameter("cidade", cidade)
                .getResultList();
    }
}
