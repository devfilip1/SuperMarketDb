package br.edu.bd2.supermercado.dao;

import javax.persistence.EntityManager;

import br.edu.bd2.supermercado.modelo.Funcionario;

public class FuncionarioDAO extends GenericDAO<Funcionario, Long> {

    public FuncionarioDAO(EntityManager em) {
        super(em, Funcionario.class);
    }
}
