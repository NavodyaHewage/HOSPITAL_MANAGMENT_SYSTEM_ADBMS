package com.hospital.hms.module.pharmacy.entity;

/** Mirrors ENUM('Receive','Dispense','Adjustment','Return'). */
public enum StockTransactionType {

    Receive(true),
    Dispense(false),
    Adjustment(false),
    Return(true);

    private final boolean inbound;

    StockTransactionType(boolean inbound) {
        this.inbound = inbound;
    }

    /** True when the movement ADDS stock - matches trg_stock_tx_ai_apply. */
    public boolean isInbound() {
        return inbound;
    }
}
