"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PayoutService = void 0;
const stripe_1 = require("../config/stripe");
const firebase_1 = require("../config/firebase");
class PayoutService {
    constructor(ledgerService, userRepository) {
        this.ledgerService = ledgerService;
        this.userRepository = userRepository;
    }
    /**
     * Crea un payout (retiro) para un usuario
     */
    async createPayout(userId, amount, method = 'bank', accountInfo) {
        // 1. Verificar que el usuario existe y tiene una cuenta Stripe Connect
        const user = await this.userRepository.getUserById(userId);
        if (!user)
            throw new Error('Usuario no encontrado');
        if (!user.connectAccountId)
            throw new Error('El usuario no tiene una cuenta Stripe Connect');
        // 2. Verificar que el KYC está completo
        if (!user.kycCompleted)
            throw new Error('Por favor completa la verificación KYC antes de retirar fondos');
        // 3. Verificar el saldo disponible
        const userBalance = await this.ledgerService.getBalance(userId);
        if (userBalance < amount)
            throw new Error('Saldo insuficiente');
        // 4. Crear el payout
        let payout;
        try {
            payout = await (0, stripe_1.getStripe)().payouts.create({
                amount,
                currency: 'eur',
                method: method === 'bank' ? 'standard' : 'instant',
                metadata: { userId },
            }, { stripeAccount: user.connectAccountId });
        }
        catch (error) {
            console.error('Error al crear el payout:', error);
            throw new Error(`Error al crear el payout: ${error.message}`);
        }
        // 5. Actualizar el saldo del usuario
        await this.ledgerService.debit(userId, amount, `Retiro ${method === 'bank' ? 'bancario' : 'a tarjeta'} (${payout.id})`, { payoutId: payout.id, method, status: 'pending' });
        return payout;
    }
    /**
     * Transfiere fondos entre dos cuentas Connect
     * Esto es diferente del P2P interno ya que utiliza la API Stripe
     * @param amount Monto en centavos
     * @param sourceAccountId ID de la cuenta Stripe Connect origen
     * @param destinationAccountId ID de la cuenta Stripe Connect destino
     * @param description Descripción de la transferencia
     * @returns Objeto Transfer Stripe
     */
    async transferBetweenConnectedAccounts(amount, sourceAccountId, destinationAccountId, description = 'Transferencia entre cuentas') {
        if (amount <= 0)
            throw new Error('El monto debe ser positivo');
        try {
            // Crear la transferencia Stripe (desde la cuenta origen)
            const transfer = await (0, stripe_1.getStripe)().transfers.create({
                amount,
                currency: 'eur',
                destination: destinationAccountId,
                description,
            }, {
                stripeAccount: sourceAccountId, // Ejecutado desde la cuenta origen
            });
            // Nota: Podrías actualizar el ledger aquí si es necesario
            return transfer;
        }
        catch (error) {
            console.error('Error durante la transferencia entre cuentas:', error);
            throw new Error(`Error durante la transferencia: ${error.message}`);
        }
    }
    /**
     * Actualiza el estado de un payout
     * @param payoutId ID del payout
     * @param status Estado nuevo ('paid' o 'failed')
     * @param failureMessage Mensaje de error opcional
     */
    async updatePayoutStatus(payoutId, status, failureMessage) {
        try {
            // Buscar la transacción relacionada con el payout
            const db = firebase_1.admin.firestore().collection('transactions');
            const snapshot = await db
                .where('metadata.payoutId', '==', payoutId)
                .limit(1)
                .get();
            if (snapshot.empty) {
                console.warn(`Ninguna transacción encontrada para el payout ${payoutId}`);
                return;
            }
            const transaction = snapshot.docs[0];
            const transactionData = transaction.data();
            // Actualizar el estado de la transacción
            await transaction.ref.update({
                'metadata.status': status,
                'metadata.failureMessage': failureMessage || null,
                'metadata.updatedAt': firebase_1.admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`Payout ${payoutId} actualizado a ${status}`);
            // Si el payout falló, reembolsar al usuario
            if (status === 'failed' && transactionData.userId) {
                const amount = Math.abs(transactionData.amount);
                await this.ledgerService.credit(transactionData.userId, amount, `Reembolso del retiro fallido (${payoutId})`, {
                    originalPayoutId: payoutId,
                    failureReason: failureMessage
                });
                console.log(`Reembolso de ${amount} acreditado al usuario ${transactionData.userId}`);
            }
        }
        catch (error) {
            console.error(`Error actualizando estado del payout: ${error}`);
        }
    }
}
exports.PayoutService = PayoutService;
//# sourceMappingURL=PayoutService.js.map