package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.CartaoFidelidade;

public class CartaoFidelidadeDAO extends GenericDAO<CartaoFidelidade, Long> {

    public CartaoFidelidadeDAO(EntityManager em) {
        super(em, CartaoFidelidade.class);
    }
}
