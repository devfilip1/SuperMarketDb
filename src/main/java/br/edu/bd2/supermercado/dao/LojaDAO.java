package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Loja;

public class LojaDAO extends GenericDAO<Loja, Long> {

    public LojaDAO(EntityManager em) {
        super(em, Loja.class);
    }
}
