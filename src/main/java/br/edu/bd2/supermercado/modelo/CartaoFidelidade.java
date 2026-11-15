package br.edu.bd2.supermercado.modelo;

import java.time.LocalDate;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "cartao_fidelidade")
public class CartaoFidelidade {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 16)
    private String numero;

    @Column(name = "data_emissao", nullable = false)
    private LocalDate dataEmissao;

    public CartaoFidelidade() {
    }

    public CartaoFidelidade(String numero, LocalDate dataEmissao) {
        this.numero = numero;
        this.dataEmissao = dataEmissao;
    }

    public Long getId() { return id; }
    public String getNumero() { return numero; }
    public LocalDate getDataEmissao() { return dataEmissao; }
}
