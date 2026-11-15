package br.edu.bd2.supermercado.modelo;

import javax.persistence.CascadeType;
import javax.persistence.Entity;
import javax.persistence.FetchType;
import javax.persistence.JoinColumn;
import javax.persistence.OneToOne;
import javax.persistence.Table;

@Entity
@Table(name = "cliente")
public class Cliente extends Pessoa {

    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    @JoinColumn(name = "cartao_fidelidade_id", unique = true)
    private CartaoFidelidade cartao;

    public Cliente() {
    }

    public Cliente(String nome, String cpf, Endereco endereco) {
        super(nome, cpf, endereco);
    }

    public CartaoFidelidade getCartao() { return cartao; }
    public void setCartao(CartaoFidelidade cartao) { this.cartao = cartao; }
}
