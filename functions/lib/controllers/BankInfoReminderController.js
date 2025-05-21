"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BankInfoReminderController = void 0;
const firebase_1 = require("../config/firebase");
class BankInfoReminderController {
    constructor(userRepository, stripeAccountService) {
        this.userRepository = userRepository;
        this.stripeAccountService = stripeAccountService;
    }
    /**
     * Verifica cuentas incompletas y envía recordatorios
     */
    async checkAndRemindIncompleteAccounts() {
        try {
            // Obtener usuarios con cuentas Stripe
            const usersWithAccounts = await this.userRepository.getAllWithConnectAccount();
            for (const user of usersWithAccounts) {
                if (!user.connectAccountId)
                    continue;
                // Verificar estado de la cuenta
                const status = await this.stripeAccountService.checkAccountStatus(user.connectAccountId);
                if (!status.isComplete || status.restricted) {
                    // Enviar notificación al usuario
                    await this.sendMissingInfoNotification(user, status.missingFields);
                }
            }
        }
        catch (error) {
            console.error('Error verificando cuentas incompletas:', error);
        }
    }
    /**
     * Actualiza información bancaria faltante
     */
    async updateMissingBankInfo(req, res) {
        try {
            const { userId, bankInfo } = req.body;
            const user = await this.userRepository.getUserById(userId);
            if (!user || !user.connectAccountId) {
                res.status(400).json({ error: 'Usuario sin cuenta Stripe' });
                return;
            }
            // Añadir información bancaria
            await this.stripeAccountService.addExternalBankAccount(user.connectAccountId, {
                external_account: {
                    object: 'bank_account',
                    account_holder_name: `${user.firstName || ''} ${user.lastName || ''}`.trim() || 'Account Holder',
                    account_holder_type: 'individual',
                    country: bankInfo.country || 'ES',
                    currency: bankInfo.currency || 'eur',
                    iban: bankInfo.iban,
                },
            });
            // Actualizar usuario
            await this.userRepository.updateUser(userId, {
                iban: bankInfo.iban,
                accountHolder: `${user.firstName || ''} ${user.lastName || ''}`.trim() || 'Account Holder',
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
            res.json({ success: true, message: 'Información bancaria actualizada' });
        }
        catch (error) {
            console.error('Error actualizando información bancaria:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Envía notificación al usuario para completar información bancaria
     */
    async sendMissingInfoNotification(user, missingFields) {
        // Implementar notificación push o email
        console.log(`Notificando a ${user.email} sobre campos faltantes:`, missingFields);
        // Ejemplo de estructura para notificación
        const notification = {
            title: 'Completa tu información bancaria',
            body: 'Para poder usar tu billetera, necesitamos que completes tu información bancaria.',
            data: {
                type: 'missing_bank_info',
                userId: user.id,
                missingFields: missingFields.join(','),
            },
        };
        // Aquí iría la lógica para enviar la notificación
        // Por ejemplo, usando Firebase Cloud Messaging (FCM)
        // await admin.messaging().sendToDevice(user.fcmToken, notification);
    }
}
exports.BankInfoReminderController = BankInfoReminderController;
//# sourceMappingURL=BankInfoReminderController.js.map