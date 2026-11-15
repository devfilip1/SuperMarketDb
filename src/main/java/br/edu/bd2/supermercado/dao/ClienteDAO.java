package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Cliente;

public class ClienteDAO extends GenericDAO<Cliente, Long> {

    public ClienteDAO(EntityManager em) {
        super(em, Cliente.class);
    }
}
