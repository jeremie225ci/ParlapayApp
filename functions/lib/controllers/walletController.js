"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.WalletController = void 0;
class WalletController {
    constructor(ledgerService, p2pService, payoutService, stripeAccountService, paymentIntentService, userRepository) {
        this.ledgerService = ledgerService;
        this.p2pService = p2pService;
        this.payoutService = payoutService;
        this.stripeAccountService = stripeAccountService;
        this.paymentIntentService = paymentIntentService;
        this.userRepository = userRepository;
    }
    /**
     * Crea una cuenta Stripe básica (sin onboarding) para usuarios con KYC aprobado
     */
    async createBasicAccount(req, res) {
        try {
            const { userId, email } = req.body;
            if (!userId || !email) {
                res.status(400).json({ error: 'userId y email son requeridos' });
                return;
            }
            // Verificar que el usuario tiene KYC aprobado
            const user = await this.userRepository.getUserById(userId);
            if (!user || user.kycStatus !== 'approved') {
                res.status(400).json({
                    error: 'El usuario debe tener KYC aprobado para crear una cuenta'
                });
                return;
            }
            // Verificar si ya tiene cuenta
            if (user.connectAccountId) {
                res.status(400).json({
                    error: 'El usuario ya tiene una cuenta Stripe',
                    accountId: user.connectAccountId
                });
                return;
            }
            // Crear cuenta Express básica
            const account = await this.stripeAccountService.createExpressAccountWithFullInfo({
                email,
                metadata: {
                    firebaseUserId: userId,
                    kycApproved: true
                }
            });
            // Actualizar usuario con el ID de la cuenta
            await this.userRepository.updateConnectedAccount(userId, account.id);
            res.json({
                accountId: account.id,
                status: 'created'
            });
        }
        catch (error) {
            console.error('Error al crear cuenta básica:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Crea un PaymentIntent para recargar el wallet
     */
    async createPaymentIntent(req, res) {
        try {
            const { amount, currency, description, userId } = req.body;
            if (!userId || amount == null) {
                res.status(400).json({ error: 'userId y amount son requeridos' });
                return;
            }
            const user = await this.userRepository.getUserById(userId);
            if (!user || !user.connectAccountId) {
                res.status(400).json({ error: 'Usuario sin cuenta Stripe Connect' });
                return;
            }
            // Crear el PaymentIntent
            const pi = await this.paymentIntentService.createPaymentIntent({
                amount: Math.round(Number(amount) * 100),
                currency: currency || 'eur',
                description,
                destinationAccountId: user.connectAccountId,
                metadata: { firebaseUserId: userId }
            });
            res.json({ clientSecret: pi.client_secret, paymentIntentId: pi.id });
        }
        catch (error) {
            console.error('Error al crear PaymentIntent:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Confirma un pago y actualiza el saldo
     */
    async confirmPayment(req, res) {
        try {
            const { paymentIntentId, userId, amount } = req.body;
            if (!paymentIntentId || !userId || amount == null) {
                res.status(400).json({ error: 'Datos incompletos' });
                return;
            }
            // Verificar el estado del PaymentIntent
            const pi = await this.paymentIntentService.retrievePaymentIntent(paymentIntentId);
            if (pi.status !== 'succeeded') {
                res.status(400).json({ error: 'El pago no se completó' });
                return;
            }
            // Acreditar el saldo del usuario
            const amountCents = Math.round(Number(amount) * 100);
            await this.ledgerService.credit(userId, amountCents, `Recarga via ${pi.payment_method_types?.[0] || 'tarjeta'} (${pi.id})`, { paymentIntentId: pi.id });
            // Obtener el nuevo saldo
            const newBalance = await this.ledgerService.getBalance(userId);
            res.json({ success: true, newBalance: newBalance / 100 }); // Convertir a euros
        }
        catch (error) {
            console.error('Error al confirmar pago:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Realiza una transferencia P2P entre usuarios
     */
    async transferFunds(req, res) {
        try {
            const { senderId, receiverId, amount } = req.body;
            if (!senderId || !receiverId || amount == null) {
                res.status(400).json({ error: 'Datos incompletos' });
                return;
            }
            // Ejecutar transferencia P2P
            const amountCents = Math.round(Number(amount) * 100);
            const p2pId = await this.p2pService.sendP2P(senderId, receiverId, amountCents, `Transferencia P2P`);
            res.json({ success: true, p2pId });
        }
        catch (error) {
            console.error('Error en transferencia P2P:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Retira fondos (SEPA o reembolso a tarjeta)
     */
    async withdrawFunds(req, res) {
        try {
            const { userId, amount, withdrawalMethod, accountInfo } = req.body;
            if (!userId || amount == null || !withdrawalMethod) {
                res.status(400).json({ error: 'Datos incompletos' });
                return;
            }
            // Verificar saldo
            const balance = await this.ledgerService.getBalance(userId);
            const amountCents = Math.round(Number(amount) * 100);
            if (balance < amountCents) {
                res.status(400).json({ error: 'Saldo insuficiente' });
                return;
            }
            if (withdrawalMethod === 'card') {
                // Lógica para reembolso a tarjeta
                // TODO: Implementar según necesidades
                res.status(501).json({ error: 'Reembolso a tarjeta no implementado' });
                return;
            }
            else if (withdrawalMethod === 'bank') {
                // Crear payout SEPA
                const payout = await this.payoutService.createPayout(userId, amountCents, 'bank', accountInfo);
                res.json({
                    success: true,
                    payoutId: payout.id,
                    status: payout.status,
                    arrivalDate: payout.arrival_date
                });
            }
            else {
                res.status(400).json({ error: 'Método de retiro inválido' });
            }
        }
        catch (error) {
            console.error('Error al retirar fondos:', error);
            res.status(500).json({ error: error.message });
        }
    }
    // src/controllers/WalletController.ts
    async createStripeAccountWithBankInfo(req, res) {
        try {
            const { userId, email, country, bankInfo, personalInfo } = req.body;
            // Crear cuenta Express con información personal
            const account = await this.stripeAccountService.createExpressAccountWithFullInfo({
                email,
                country,
                metadata: { firebaseUserId: userId },
                businessType: 'individual',
                individual: {
                    first_name: personalInfo.firstName,
                    last_name: personalInfo.lastName,
                    dob: {
                        day: parseInt(personalInfo.dob.split('/')[0]),
                        month: parseInt(personalInfo.dob.split('/')[1]),
                        year: parseInt(personalInfo.dob.split('/')[2]),
                    },
                    address: personalInfo.address,
                    id_number: personalInfo.idNumber,
                },
            });
            // Agregar información bancaria si existe
            if (bankInfo) {
                // Usar el método del servicio para agregar la cuenta bancaria
                const bankAccountData = {
                    external_account: {
                        object: 'bank_account',
                        account_holder_name: bankInfo.accountHolder,
                        account_holder_type: 'individual',
                        country: country,
                        currency: bankInfo.iban ? 'eur' : 'usd',
                        ...(bankInfo.iban ? { iban: bankInfo.iban } : {
                            account_number: bankInfo.accountNumber,
                            routing_number: bankInfo.routingNumber,
                        }),
                    },
                };
                // Usar el método del servicio de Stripe
                await this.stripeAccountService.addExternalBankAccount(account.id, bankAccountData);
            }
            // Actualizar usuario en Firebase
            await this.userRepository.updateConnectedAccount(userId, account.id);
            res.json({
                accountId: account.id,
                status: 'created'
            });
        }
        catch (error) {
            console.error('Error al crear cuenta Stripe:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Obtiene el saldo y transacciones de un usuario
     */
    async getWallet(req, res) {
        try {
            const { userId } = req.params;
            if (!userId) {
                res.status(400).json({ error: 'userId es requerido' });
                return;
            }
            // Obtener datos del usuario
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                res.status(404).json({ error: 'Usuario no encontrado' });
                return;
            }
            // Obtener saldo
            const balance = await this.ledgerService.getBalance(userId);
            // Obtener transacciones
            const transactions = await this.ledgerService.getTransactions(userId, 50);
            res.json({
                userId,
                connectAccountId: user.connectAccountId,
                kycCompleted: user.kycCompleted,
                kycStatus: user.kycStatus,
                balance: balance / 100,
                transactions: transactions.map(tx => ({
                    ...tx,
                    amount: tx.amount / 100, // Convertir a euros
                }))
            });
        }
        catch (error) {
            console.error('Error al obtener wallet:', error);
            res.status(500).json({ error: error.message });
        }
    }
}
exports.WalletController = WalletController;
//# sourceMappingURL=walletController.js.map