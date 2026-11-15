package br.edu.bd2.supermercado.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.EnumType;
import javax.persistence.Enumerated;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;
import javax.persistence.NamedQuery;
import javax.persistence.OneToMany;
import javax.persistence.Table;

@Entity
@Table(name = "venda")
@NamedQuery(name = "Venda.totalPorCliente",
        query = "SELECT c.nome, SUM(i.quantidade * i.precoUnitario) "
              + "FROM Venda v JOIN v.cliente c JOIN v.itens i "
              + "GROUP BY c.id, c.nome "
              + "HAVING SUM(i.quantidade * i.precoUnitario) > :minimo "
              + "ORDER BY SUM(i.quantidade * i.precoUnitario) DESC")
public class Venda {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "data_hora", nullable = false)
    private LocalDateTime dataHora;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "cliente_id")
    private Cliente cliente;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "loja_id")
    private Loja loja;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "funcionario_id")
    private Funcionario operador;

    @Enumerated(EnumType.STRING)
    @Column(name = "forma_pagamento", nullable = false, length = 10)
    private FormaPagamento formaPagamento;

    @OneToMany(mappedBy = "venda", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ItemVenda> itens = new ArrayList<>();

    public Venda() {
    }

    public Venda(LocalDateTime dataHora, Cliente cliente, Loja loja, Funcionario operador, FormaPagamento formaPagamento) {
        this.dataHora = dataHora;
        this.cliente = cliente;
        this.loja = loja;
        this.operador = operador;
        this.formaPagamento = formaPagamento;
    }

    public void adicionarItem(Produto produto, int quantidade) {
        itens.add(new ItemVenda(this, produto, quantidade, produto.getPreco()));
    }

    public BigDecimal getTotal() {
        BigDecimal total = BigDecimal.ZERO;
        for (ItemVenda i : itens) {
            total = total.add(i.getSubtotal());
        }
        return total;
    }

    public Long getId() { return id; }
    public LocalDateTime getDataHora() { return dataHora; }
    public Cliente getCliente() { return cliente; }
    public Loja getLoja() { return loja; }
    public Funcionario getOperador() { return operador; }
    public FormaPagamento getFormaPagamento() { return formaPagamento; }
    public List<ItemVenda> getItens() { return itens; }
}
