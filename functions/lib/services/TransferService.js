"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransferService = void 0;
const stripe_1 = require("../config/stripe");
class TransferService {
    constructor(ledgerService, userRepository) {
        this.ledgerService = ledgerService;
        this.userRepository = userRepository;
    }
    /**
     * Transfère des fonds de la plateforme vers un compte Connect
     * Utilisé généralement pour des paiements manuels ou des bonus
     * @param amount Montant en centimes
     * @param destinationAccountId ID du compte Stripe Connect destinataire
     * @param description Description du transfert
     * @returns Objet Transfer Stripe
     */
    async transferToConnectedAccount(amount, destinationAccountId, description = 'Transfert depuis la plateforme') {
        if (amount <= 0)
            throw new Error('Le montant doit être positif');
        try {
            // 1. Créer le transfert Stripe
            const transfer = await (0, stripe_1.getStripe)().transfers.create({
                amount,
                currency: 'eur',
                destination: destinationAccountId,
                description,
            });
            // 2. Trouver l'utilisateur correspondant
            const users = await this.userRepository.findByConnectAccountId(destinationAccountId);
            if (users.length > 0) {
                const userId = users[0].id;
                // 3. Mettre à jour le ledger (optionnel, selon votre logique)
                await this.ledgerService.credit(userId, amount, `Transfert reçu de la plateforme: ${description}`, { transferId: transfer.id });
            }
            return transfer;
        }
        catch (error) {
            console.error('Erreur lors du transfert vers le compte connecté:', error);
            throw new Error(`Erreur lors du transfert: ${error.message}`);
        }
    }
    /**
     * Transfère des fonds entre deux comptes Connect
     * Ceci est différent du P2P interne car il utilise l'API Stripe
     * @param amount Montant en centimes
     * @param sourceAccountId ID du compte Stripe Connect source
     * @param destinationAccountId ID du compte Stripe Connect destinataire
     * @param description Description du transfert
     * @returns Objet Transfer Stripe
     */
    async transferBetweenConnectedAccounts(amount, sourceAccountId, destinationAccountId, description = 'Transfert entre comptes') {
        if (amount <= 0)
            throw new Error('Le montant doit être positif');
        try {
            // Créer le transfert Stripe (depuis le compte source)
            const transfer = await (0, stripe_1.getStripe)().transfers.create({
                amount,
                currency: 'eur',
                destination: destinationAccountId,
                description,
            }, {
                stripeAccount: sourceAccountId, // Exécuté depuis le compte source
            });
            // Note: Vous pourriez mettre à jour le ledger ici si nécessaire
            return transfer;
        }
        catch (error) {
            console.error('Erreur lors du transfert entre comptes:', error);
            throw new Error(`Erreur lors du transfert: ${error.message}`);
        }
    }
}
exports.TransferService = TransferService;
//# sourceMappingURL=TransferService.js.map