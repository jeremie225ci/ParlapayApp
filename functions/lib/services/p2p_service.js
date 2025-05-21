"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.P2PService = void 0;
const firebase_1 = require("../config/firebase");
const rapyd_service_1 = require("./rapyd_service");
const UserRepository_1 = require("../repositories/UserRepository");
const WalletRepository_1 = require("../repositories/WalletRepository");
class P2PService {
    constructor() {
        this.rapydService = new rapyd_service_1.RapydService();
        this.userRepository = new UserRepository_1.UserRepository();
        this.walletRepository = new WalletRepository_1.WalletRepository();
    }
    /**
     * Realiza una transferencia P2P entre usuarios
     */
    async sendP2P(senderId, receiverId, amount, currency = "EUR") {
        try {
            // Verificar que ambos usuarios existen
            const [sender, receiver] = await Promise.all([
                this.userRepository.getUserById(senderId),
                this.userRepository.getUserById(receiverId),
            ]);
            if (!sender) {
                throw new Error(`Remitente ${senderId} no encontrado`);
            }
            if (!receiver) {
                throw new Error(`Destinatario ${receiverId} no encontrado`);
            }
            // Verificar que ambos tienen wallet Rapyd
            if (!sender.rapydWalletId) {
                throw new Error(`Remitente ${senderId} no tiene wallet Rapyd`);
            }
            if (!receiver.rapydWalletId) {
                throw new Error(`Destinatario ${receiverId} no tiene wallet Rapyd`);
            }
            // Verificar saldo del remitente
            const senderWallet = await this.walletRepository.getWallet(senderId);
            if (!senderWallet || senderWallet.balance < amount) {
                throw new Error("Saldo insuficiente");
            }
            // Crear transferencia en Rapyd
            const transfer = await this.rapydService.transferFunds(sender.rapydWalletId, receiver.rapydWalletId, amount, currency);
            // Actualizar saldos en Firestore
            const db = firebase_1.admin.firestore();
            const batch = db.batch();
            const timestamp = Date.now();
            // Actualizar saldo del remitente
            const senderWalletRef = db.collection("wallets").doc(senderId);
            batch.update(senderWalletRef, {
                balance: firebase_1.admin.firestore.FieldValue.increment(-amount),
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                transactions: firebase_1.admin.firestore.FieldValue.arrayUnion({
                    id: transfer.id,
                    amount: -amount,
                    type: "debit",
                    description: "Transferencia enviada",
                    receiverId,
                    timestamp,
                    rapydTransactionId: transfer.id,
                    status: "completed",
                }),
            });
            // Actualizar o crear wallet del destinatario
            const receiverWalletRef = db.collection("wallets").doc(receiverId);
            const receiverWalletDoc = await receiverWalletRef.get();
            if (receiverWalletDoc.exists) {
                batch.update(receiverWalletRef, {
                    balance: firebase_1.admin.firestore.FieldValue.increment(amount),
                    updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                    transactions: firebase_1.admin.firestore.FieldValue.arrayUnion({
                        id: transfer.id,
                        amount,
                        type: "credit",
                        description: "Transferencia recibida",
                        senderId,
                        timestamp,
                        rapydTransactionId: transfer.id,
                        status: "completed",
                    }),
                });
            }
            else {
                batch.set(receiverWalletRef, {
                    userId: receiverId,
                    rapydWalletId: receiver.rapydWalletId,
                    balance: amount,
                    transactions: [
                        {
                            id: transfer.id,
                            amount,
                            type: "credit",
                            description: "Transferencia recibida",
                            senderId,
                            timestamp,
                            rapydTransactionId: transfer.id,
                            status: "completed",
                        },
                    ],
                    createdAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            // Ejecutar batch
            await batch.commit();
            return transfer.id;
        }
        catch (error) {
            console.error("Error en transferencia P2P:", error);
            throw error;
        }
    }
}
exports.P2PService = P2PService;
//# sourceMappingURL=p2p_service.js.map