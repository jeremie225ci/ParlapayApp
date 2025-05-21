"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.WalletService = void 0;
const rapyd_service_1 = require("./rapyd_service");
const WalletRepository_1 = require("../repositories/WalletRepository");
const UserRepository_1 = require("../repositories/UserRepository");
class WalletService {
    constructor() {
        this.rapydService = new rapyd_service_1.RapydService();
        this.walletRepository = new WalletRepository_1.WalletRepository();
        this.userRepository = new UserRepository_1.UserRepository();
    }
    /**
     * Obtiene el wallet de un usuario, sincronizando con Rapyd si es necesario
     */
    async getWallet(userId) {
        try {
            // Obtener usuario
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                throw new Error(`Usuario ${userId} no encontrado`);
            }
            // Obtener wallet de Firestore
            let wallet = await this.walletRepository.getWallet(userId);
            // Si el usuario tiene wallet Rapyd pero no wallet en Firestore, crearlo
            if (user.rapydWalletId && !wallet) {
                await this.walletRepository.createWallet(userId, user.rapydWalletId);
                wallet = await this.walletRepository.getWallet(userId);
            }
            // Si el usuario tiene wallet Rapyd, sincronizar saldo
            if (user.rapydWalletId && wallet) {
                try {
                    // Obtener saldo de Rapyd
                    const balanceData = await this.rapydService.getWalletBalance(user.rapydWalletId);
                    const accounts = balanceData.accounts || [];
                    let rapydBalance = 0;
                    // Sumar saldos de todas las cuentas/monedas en EUR
                    accounts.forEach((account) => {
                        if (account.currency === "EUR") {
                            rapydBalance = account.balance;
                        }
                    });
                    // Si hay diferencia, actualizar en Firestore
                    if (wallet.balance !== rapydBalance) {
                        await this.walletRepository.updateBalance(userId, rapydBalance);
                        wallet.balance = rapydBalance;
                    }
                }
                catch (error) {
                    console.error(`Error obteniendo wallet:`, error);
                    throw error;
                }
            }
            return wallet;
        }
        catch (error) {
            console.error(`Error obteniendo wallet:`, error);
            throw error;
        }
    }
    /**
     * Añade fondos al wallet de un usuario
     */
    async addFunds(userId, amount, paymentMethod) {
        try {
            // Obtener usuario
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                throw new Error(`Usuario ${userId} no encontrado`);
            }
            // Verificar que el usuario tiene wallet Rapyd
            if (!user.rapydWalletId) {
                throw new Error(`Usuario ${userId} no tiene wallet Rapyd`);
            }
            // Realizar pago en Rapyd
            const payment = await this.rapydService.addFunds(user.rapydWalletId, amount, "EUR", paymentMethod);
            // Si el pago requiere acción adicional (3DS, etc.)
            if (payment.status === "ACT") {
                return {
                    success: true,
                    requiresAction: true,
                    redirectUrl: payment.redirect_url,
                    paymentId: payment.id,
                };
            }
            // Si el pago es exitoso, actualizar saldo en Firestore
            if (payment.status === "CLO") {
                // Obtener wallet actual
                const wallet = await this.walletRepository.getWallet(userId);
                const newBalance = wallet ? wallet.balance + amount : amount;
                // Actualizar wallet
                await this.walletRepository.updateBalance(userId, newBalance);
                // Crear transacción
                const transaction = {
                    id: payment.id,
                    amount: amount,
                    senderId: "deposit",
                    receiverId: userId,
                    timestamp: new Date(),
                    description: "Depósito de fondos",
                    type: "credit",
                    status: "completed",
                    rapydTransactionId: payment.id,
                };
                await this.walletRepository.addTransaction(userId, transaction);
                return {
                    success: true,
                    newBalance,
                    paymentId: payment.id,
                };
            }
            return {
                success: false,
                error: "Estado de pago desconocido",
            };
        }
        catch (error) {
            console.error(`Error al añadir fondos:`, error);
            throw error;
        }
    }
    /**
     * Retira fondos del wallet de un usuario
     */
    async withdrawFunds(userId, amount) {
        try {
            // Verificar saldo
            const wallet = await this.walletRepository.getWallet(userId);
            if (!wallet || wallet.balance < amount) {
                throw new Error("Saldo insuficiente");
            }
            // Obtener usuario
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                throw new Error(`Usuario ${userId} no encontrado`);
            }
            // Verificar que el usuario tiene wallet Rapyd y beneficiario
            if (!user.rapydWalletId || !user.rapydBeneficiaryId) {
                throw new Error(`Usuario ${userId} no tiene wallet Rapyd o sin beneficiario`);
            }
            // Realizar retiro en Rapyd
            const payout = await this.rapydService.withdrawFunds(user.rapydWalletId, amount, "EUR", user.rapydBeneficiaryId);
            // Crear transacción
            const transaction = {
                id: payout.id,
                amount: -amount,
                senderId: userId,
                receiverId: "bank_payout",
                timestamp: new Date(),
                description: "Retiro a cuenta bancaria",
                type: "debit",
                status: "pending",
                rapydTransactionId: payout.id,
            };
            // Actualizar wallet
            await this.walletRepository.updateBalance(userId, -amount);
            await this.walletRepository.addTransaction(userId, transaction);
            return {
                success: true,
                transactionId: payout.id,
            };
        }
        catch (error) {
            console.error("Error al retirar fondos:", error);
            throw error;
        }
    }
}
exports.WalletService = WalletService;
//# sourceMappingURL=wallet_service.js.map