"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LedgerService = void 0;
const firebase_1 = require("../config/firebase");
const uuid_1 = require("uuid");
class LedgerService {
    constructor() {
        this.db = firebase_1.admin.firestore();
        this.walletsCol = 'wallets';
        this.txCol = 'transactions';
    }
    async credit(userId, amount, description, metadata) {
        if (amount <= 0)
            throw new Error('Le montant doit être positif');
        const txId = (0, uuid_1.v4)();
        const now = firebase_1.admin.firestore.FieldValue.serverTimestamp();
        const txData = {
            id: txId,
            userId,
            amount,
            type: 'credit',
            description,
            metadata,
            timestamp: now,
        };
        await this.db.runTransaction(async (tx) => {
            const wRef = this.db.collection(this.walletsCol).doc(userId);
            const wDoc = await tx.get(wRef);
            if (!wDoc.exists) {
                tx.set(wRef, { balance: amount, updatedAt: now });
            }
            else {
                const current = (wDoc.data()?.balance ?? 0);
                tx.update(wRef, { balance: current + amount, updatedAt: now });
            }
            tx.set(this.db.collection(this.txCol).doc(txId), txData);
        });
        return txData;
    }
    async debit(userId, amount, description, metadata) {
        if (amount <= 0)
            throw new Error('Le montant doit être positif');
        const txId = (0, uuid_1.v4)();
        const now = firebase_1.admin.firestore.FieldValue.serverTimestamp();
        const txData = {
            id: txId,
            userId,
            amount: -amount,
            type: 'debit',
            description,
            metadata,
            timestamp: now,
        };
        await this.db.runTransaction(async (tx) => {
            const wRef = this.db.collection(this.walletsCol).doc(userId);
            const wDoc = await tx.get(wRef);
            if (!wDoc.exists)
                throw new Error('Wallet inexistant');
            const current = (wDoc.data()?.balance ?? 0);
            if (current < amount)
                throw new Error('Solde insuffisant');
            tx.update(wRef, { balance: current - amount, updatedAt: now });
            tx.set(this.db.collection(this.txCol).doc(txId), txData);
        });
        return txData;
    }
    async getBalance(userId) {
        const doc = await this.db.collection(this.walletsCol).doc(userId).get();
        return (doc.exists ? doc.data()?.balance : 0) || 0;
    }
    async getTransactions(userId, limit = 50) {
        const snap = await this.db
            .collection(this.txCol)
            .where('userId', '==', userId)
            .orderBy('timestamp', 'desc')
            .limit(limit)
            .get();
        return snap.docs.map(d => d.data());
    }
    async sumAllBalances() {
        const snap = await this.db.collection(this.walletsCol).get();
        return snap.docs.reduce((sum, d) => sum + (d.data().balance || 0), 0);
    }
}
exports.LedgerService = LedgerService;
//# sourceMappingURL=LedgerService.js.map