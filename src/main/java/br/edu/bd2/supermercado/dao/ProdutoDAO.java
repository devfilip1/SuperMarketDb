package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Produto;

public class ProdutoDAO extends GenericDAO<Produto, Long> {

    public ProdutoDAO(EntityManager em) {
        super(em, Produto.class);
    }
}
