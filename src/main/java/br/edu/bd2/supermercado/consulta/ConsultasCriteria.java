package br.edu.bd2.supermercado.consulta;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import javax.persistence.EntityManager;
import javax.persistence.criteria.CriteriaBuilder;
import javax.persistence.criteria.CriteriaQuery;
import javax.persistence.criteria.Join;
import javax.persistence.criteria.Predicate;
import javax.persistence.criteria.Root;

import br.edu.bd2.supermercado.modelo.Cliente;
import br.edu.bd2.supermercado.modelo.Loja;
import br.edu.bd2.supermercado.modelo.Produto;
import br.edu.bd2.supermercado.modelo.Venda;

public class ConsultasCriteria {

    private final EntityManager em;

    public ConsultasCriteria(EntityManager em) {
        this.em = em;
    }

    public List<Produto> c01BuscarProdutos(String nomeContem, String categoria, BigDecimal precoMaximo) {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<Produto> cq = cb.createQuery(Produto.class);
        Root<Produto> p = cq.from(Produto.class);

        List<Predicate> filtros = new ArrayList<>();
        if (nomeContem != null) {
            filtros.add(cb.like(cb.lower(p.<String>get("nome")), "%" + nomeContem.toLowerCase() + "%"));
        }
        if (categoria != null) {
            filtros.add(cb.equal(p.get("categoria").get("nome"), categoria));
        }
        if (precoMaximo != null) {
            filtros.add(cb.le(p.<BigDecimal>get("preco"), precoMaximo));
        }
        cq.select(p).where(filtros.toArray(new Predicate[0])).orderBy(cb.asc(p.get("nome")));
        return em.createQuery(cq).getResultList();
    }

    public List<Venda> c02CuponsDoCliente(String cpf, LocalDateTime inicio, LocalDateTime fim) {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<Venda> cq = cb.createQuery(Venda.class);
        Root<Venda> v = cq.from(Venda.class);
        Join<Venda, Cliente> c = v.join("cliente");

        cq.select(v)
          .where(cb.equal(c.get("cpf"), cpf), cb.between(v.<LocalDateTime>get("dataHora"), inicio, fim))
          .orderBy(cb.asc(v.get("dataHora")));
        return em.createQuery(cq).getResultList();
    }

    public List<Object[]> c03CuponsPorLoja() {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<Object[]> cq = cb.createQuery(Object[].class);
        Root<Venda> v = cq.from(Venda.class);
        Join<Venda, Loja> l = v.join("loja");

        cq.multiselect(l.get("nome"), cb.count(v))
          .groupBy(l.get("nome"))
          .orderBy(cb.asc(l.get("nome")));
        return em.createQuery(cq).getResultList();
    }
}
