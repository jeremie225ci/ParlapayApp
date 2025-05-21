"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.WalletRepository = void 0;
const firebase_1 = require("../config/firebase");
class WalletRepository {
    constructor() {
        this.db = firebase_1.admin.firestore();
        this.walletsCollection = "wallets";
    }
    /**
     * Obtiene el wallet de un usuario
     */
    async getWallet(userId) {
        try {
            const walletDoc = await this.db.collection(this.walletsCollection).doc(userId).get();
            if (!walletDoc.exists) {
                return null;
            }
            const wallet = walletDoc.data();
            return {
                id: walletDoc.id,
                ...wallet,
            };
        }
        catch (error) {
            console.error("Error obteniendo wallet:", error);
            throw error;
        }
    }
    /**
     * Crea un nuevo wallet
     */
    async createWallet(userId, rapydWalletId) {
        try {
            await this.db.collection(this.walletsCollection).doc(userId).set({
                userId,
                rapydWalletId,
                balance: 0,
                currency: "EUR",
                accountStatus: "active",
                transactions: [],
                createdAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error("Error creando wallet:", error);
            throw error;
        }
    }
    /**
     * Actualiza un wallet existente
     */
    async updateWallet(userId, walletData) {
        try {
            await this.db
                .collection(this.walletsCollection)
                .doc(userId)
                .update({
                ...walletData,
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error("Error actualizando wallet:", error);
            throw error;
        }
    }
    /**
     * Actualiza el saldo de un wallet
     */
    async updateBalance(userId, amount) {
        try {
            await this.db
                .collection(this.walletsCollection)
                .doc(userId)
                .update({
                balance: firebase_1.admin.firestore.FieldValue.increment(amount),
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error("Error actualizando saldo:", error);
            throw error;
        }
    }
    /**
     * Añade una transacción al wallet
     */
    async addTransaction(userId, transaction) {
        try {
            await this.db
                .collection(this.walletsCollection)
                .doc(userId)
                .update({
                transactions: firebase_1.admin.firestore.FieldValue.arrayUnion(transaction),
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error("Error añadiendo transacción:", error);
            throw error;
        }
    }
    /**
     * Obtiene las transacciones de un wallet
     */
    async getTransactions(userId, limit = 20) {
        try {
            const walletDoc = await this.db.collection(this.walletsCollection).doc(userId).get();
            if (!walletDoc.exists) {
                return [];
            }
            const wallet = walletDoc.data();
            // Asegurarse de que transactions existe y es un array
            const transactions = wallet.transactions || [];
            // Ordenar transacciones por timestamp descendente y limitar
            return [...transactions]
                .sort((a, b) => {
                const aTime = a.timestamp instanceof Date ? a.timestamp.getTime() : a.timestamp;
                const bTime = b.timestamp instanceof Date ? b.timestamp.getTime() : b.timestamp;
                return bTime - aTime;
            })
                .slice(0, limit);
        }
        catch (error) {
            console.error("Error obteniendo transacciones:", error);
            throw error;
        }
    }
    /**
     * Observa cambios en un wallet
     */
    watchWallet(userId, callback) {
        return this.db
            .collection(this.walletsCollection)
            .doc(userId)
            .onSnapshot((snapshot) => {
            callback(snapshot);
        }, (error) => {
            console.error("Error observando wallet:", error);
        });
    }
}
exports.WalletRepository = WalletRepository;
//# sourceMappingURL=WalletRepository.js.map