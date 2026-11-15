package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.ItemVenda;

public class ItemVendaDAO extends GenericDAO<ItemVenda, Long> {

    public ItemVendaDAO(EntityManager em) {
        super(em, ItemVenda.class);
    }
}
