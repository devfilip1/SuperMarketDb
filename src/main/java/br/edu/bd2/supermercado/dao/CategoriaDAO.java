package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Categoria;

public class CategoriaDAO extends GenericDAO<Categoria, Long> {

    public CategoriaDAO(EntityManager em) {
        super(em, Categoria.class);
    }
}
