"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WebhookController = void 0;
const stripe_1 = __importDefault(require("stripe"));
const firebase_1 = require("../config/firebase");
class WebhookController {
    constructor(stripeAccountService, firestore, webhookSecret, payoutService, ledgerService) {
        this.stripeAccountService = stripeAccountService;
        this.payoutService = payoutService;
        this.ledgerService = ledgerService;
        this.firestore = firestore;
        this.webhookSecret = webhookSecret;
    }
    async handleWebhook(req, res) {
        const sig = req.headers['stripe-signature'];
        if (!sig) {
            console.error('⚠️ Webhook called without Stripe signature');
            res.status(400).send('Webhook Error: No Stripe signature provided');
            return;
        }
        let event;
        try {
            // Vérifier la signature du webhook
            event = stripe_1.default.webhooks.constructEvent(req.body, sig, this.webhookSecret);
        }
        catch (err) {
            console.error('⚠️ Webhook signature verification failed.', err.message);
            res.status(400).send(`Webhook Error: ${err.message}`);
            return;
        }
        // Log pour debug
        console.log(`✅ Webhook event received: ${event.type}`, {
            id: event.id,
            apiVersion: event.api_version
        });
        try {
            // Traiter l'événement en fonction de son type
            await this.processEvent(event);
            // Répondre à Stripe pour confirmer la réception
            res.json({ received: true, id: event.id });
        }
        catch (error) {
            console.error(`❌ Error processing webhook ${event.type}:`, error);
            // Enregistrer l'erreur dans Firestore pour analyse ultérieure
            await this.firestore.collection('webhook_errors').add({
                eventId: event.id,
                eventType: event.type,
                error: error.message,
                stack: error.stack,
                timestamp: firebase_1.admin.firestore.FieldValue.serverTimestamp()
            });
            // Répondre avec une erreur 500 mais indiquer à Stripe que l'événement a été reçu
            // pour éviter les retentatives inutiles si l'erreur est côté serveur
            res.status(500).json({
                received: true,
                error: error.message,
                id: event.id
            });
        }
    }
    /**
     * Traite un événement Stripe en fonction de son type
     * @param event Événement Stripe
     */
    async processEvent(event) {
        switch (event.type) {
            case 'account.updated':
                await this.handleAccountUpdated(event.data.object);
                break;
            case 'payment_intent.succeeded':
                await this.handlePaymentIntentSucceeded(event.data.object);
                break;
            case 'payment_intent.payment_failed':
                await this.handlePaymentIntentFailed(event.data.object);
                break;
            case 'payout.paid':
                await this.handlePayoutPaid(event.data.object);
                break;
            case 'payout.failed':
                await this.handlePayoutFailed(event.data.object);
                break;
            default:
                console.log(`⚠️ Unhandled event type ${event.type}`);
        }
    }
    /**
     * Gère l'événement account.updated
     * Met à jour le statut KYC de l'utilisateur
     * @param account Compte Stripe mis à jour
     */
    async handleAccountUpdated(account) {
        console.log(`📝 Account updated: ${account.id}`);
        // Rechercher les utilisateurs avec ce connectAccountId
        const snaps = await this.firestore
            .collection('users')
            .where('connectAccountId', '==', account.id)
            .get();
        if (snaps.empty) {
            console.warn(`⚠️ No user found with connectAccountId ${account.id}`);
            return;
        }
        // Déterminer si le KYC est complet (charges_enabled ET payouts_enabled)
        const kycDone = Boolean(account.charges_enabled && account.payouts_enabled);
        // Mettre à jour chaque utilisateur trouvé
        let updatedCount = 0;
        for (const doc of snaps.docs) {
            try {
                await doc.ref.update({
                    kycCompleted: kycDone,
                    kycCompletedAt: kycDone
                        ? firebase_1.admin.firestore.FieldValue.serverTimestamp()
                        : null,
                    updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp()
                });
                updatedCount++;
            }
            catch (error) {
                console.error(`❌ Error updating user ${doc.id}:`, error);
            }
        }
        console.log(`✅ Updated KYC status to ${kycDone} for ${updatedCount} users`);
    }
    /**
     * Gère l'événement payment_intent.succeeded
     * @param paymentIntent PaymentIntent réussi
     */
    async handlePaymentIntentSucceeded(paymentIntent) {
        console.log(`💰 Payment succeeded: ${paymentIntent.id}`);
        // Vérifier que nous avons le service de Ledger
        if (!this.ledgerService) {
            console.warn('⚠️ LedgerService not available, skipping payment confirmation');
            return;
        }
        // Extraire l'ID utilisateur des métadonnées
        const userId = paymentIntent.metadata?.firebaseUserId;
        if (!userId) {
            console.warn(`⚠️ No userId in metadata for payment ${paymentIntent.id}`);
            return;
        }
        try {
            // Vérifier si ce paiement a déjà été traité
            const existingTx = await this.firestore
                .collection('transactions')
                .where('metadata.paymentIntentId', '==', paymentIntent.id)
                .limit(1)
                .get();
            if (!existingTx.empty) {
                console.log(`⚠️ Payment ${paymentIntent.id} already processed, skipping`);
                return;
            }
            // Créditer le solde de l'utilisateur
            const amount = paymentIntent.amount;
            const description = `Paiement réussi via ${paymentIntent.payment_method_types?.[0] || 'carte'} (${paymentIntent.id})`;
            await this.ledgerService.credit(userId, amount, description, {
                paymentIntentId: paymentIntent.id,
                paymentMethod: paymentIntent.payment_method_types?.[0],
                status: 'completed'
            });
            console.log(`✅ Credited ${amount} to user ${userId}`);
        }
        catch (error) {
            console.error(`❌ Error processing payment ${paymentIntent.id}:`, error);
            throw error;
        }
    }
    /**
     * Gère l'événement payment_intent.payment_failed
     * @param paymentIntent PaymentIntent échoué
     */
    async handlePaymentIntentFailed(paymentIntent) {
        console.log(`❌ Payment failed: ${paymentIntent.id}`);
        // Extraire l'ID utilisateur des métadonnées
        const userId = paymentIntent.metadata?.firebaseUserId;
        if (!userId) {
            console.warn(`⚠️ No userId in metadata for payment ${paymentIntent.id}`);
            return;
        }
        // Enregistrer l'échec dans Firestore
        await this.firestore.collection('payment_failures').add({
            userId,
            paymentIntentId: paymentIntent.id,
            amount: paymentIntent.amount,
            failureCode: paymentIntent.last_payment_error?.code,
            failureMessage: paymentIntent.last_payment_error?.message,
            timestamp: firebase_1.admin.firestore.FieldValue.serverTimestamp()
        });
    }
    /**
     * Gère l'événement payout.paid
     * @param payout Payout réussi
     */
    async handlePayoutPaid(payout) {
        console.log(`💸 Payout paid: ${payout.id}`);
        if (!this.payoutService) {
            console.warn('⚠️ PayoutService not available, skipping payout status update');
            return;
        }
        await this.payoutService.updatePayoutStatus(payout.id, 'paid');
    }
    /**
     * Gère l'événement payout.failed
     * @param payout Payout échoué
     */
    async handlePayoutFailed(payout) {
        console.log(`❌ Payout failed: ${payout.id}`);
        if (!this.payoutService) {
            console.warn('⚠️ PayoutService not available, skipping payout status update');
            return;
        }
        await this.payoutService.updatePayoutStatus(payout.id, 'failed', payout.failure_message || 'Échec du retrait');
    }
}
exports.WebhookController = WebhookController;
//# sourceMappingURL=webhookController.js.map