package br.edu.bd2.supermercado.modelo;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Table;

@Entity
@Table(name = "funcionario")
public class Funcionario extends Pessoa {

    @Column(nullable = false, unique = true, length = 10)
    private String matricula;

    public Funcionario() {
    }

    public Funcionario(String nome, String cpf, Endereco endereco, String matricula) {
        super(nome, cpf, endereco);
        this.matricula = matricula;
    }

    public String getMatricula() { return matricula; }
    public void setMatricula(String matricula) { this.matricula = matricula; }
}
