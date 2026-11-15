package br.edu.bd2.supermercado.dao;

import java.util.List;
import java.util.function.Consumer;

import javax.persistence.EntityManager;
import javax.persistence.EntityTransaction;

public class GenericDAO<T, ID> {

    private final EntityManager em;
    private final Class<T> classe;

    public GenericDAO(EntityManager em, Class<T> classe) {
        this.em = em;
        this.classe = classe;
    }

    public void salvar(T entidade) {
        emTransacao(em -> em.persist(entidade));
    }

    public void atualizar(T entidade) {
        emTransacao(em -> em.merge(entidade));
    }

    public void remover(ID id) {
        emTransacao(em -> em.remove(em.getReference(classe, id)));
    }

    public T buscarPorId(ID id) {
        return em.find(classe, id);
    }

    public List<T> listarTodos() {
        return em.createQuery("SELECT e FROM " + classe.getSimpleName() + " e ORDER BY e.id", classe)
                .getResultList();
    }

    private void emTransacao(Consumer<EntityManager> operacao) {
        EntityTransaction tx = em.getTransaction();
        try {
            tx.begin();
            operacao.accept(em);
            tx.commit();
        } catch (RuntimeException e) {
            if (tx.isActive()) {
                tx.rollback();
            }
            throw e;
        }
    }
}
