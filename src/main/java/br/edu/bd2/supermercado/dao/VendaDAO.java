package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Venda;

public class VendaDAO extends GenericDAO<Venda, Long> {

    public VendaDAO(EntityManager em) {
        super(em, Venda.class);
    }
}
