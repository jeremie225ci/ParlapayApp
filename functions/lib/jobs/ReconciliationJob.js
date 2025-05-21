"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReconciliationJob = void 0;
// src/jobs/ReconciliationJob.ts
const stripe_1 = require("../config/stripe");
const firebase_1 = require("../config/firebase");
class ReconciliationJob {
    constructor(ledgerService, userRepository) {
        this.db = firebase_1.admin.firestore();
        this.ledgerService = ledgerService;
        this.userRepository = userRepository;
    }
    /**
     * Exécute la tâche de réconciliation
     * Compare la somme des soldes internes avec les balances Stripe
     * @returns Rapport de réconciliation
     */
    async run() {
        console.log('⚙️ Démarrage de la tâche de réconciliation...');
        try {
            // 1. Obtenir la somme des soldes dans le ledger interne
            const internalBalance = await this.ledgerService.sumAllBalances();
            console.log(`💰 Solde interne total: ${internalBalance} centimes`);
            // 2. Obtenir la balance Stripe de la plateforme
            const platformBalance = await this.getPlatformBalance();
            console.log(`💳 Balance Stripe de la plateforme: ${platformBalance} centimes`);
            // 3. Obtenir la somme des balances des comptes connectés
            const connectedAccountsResult = await this.getConnectedAccountsBalance();
            console.log(`👥 Balance des comptes connectés: ${connectedAccountsResult.balance} centimes`);
            // 4. Calculer la différence
            const connectedAccountsBalance = connectedAccountsResult.balance;
            const totalStripeBalance = platformBalance + connectedAccountsBalance;
            const discrepancy = internalBalance - totalStripeBalance;
            // 5. Préparer le rapport
            const report = {
                timestamp: new Date(),
                internalBalance,
                platformBalance,
                connectedAccountsBalance,
                totalStripeBalance,
                discrepancy,
                isBalanced: Math.abs(discrepancy) < 100,
                details: {
                    accountsChecked: connectedAccountsResult.accountsChecked,
                    errorAccounts: connectedAccountsResult.errorAccounts
                }
            };
            // 6. Alerter si nécessaire
            if (Math.abs(discrepancy) >= 100) {
                await this.sendAlert(report);
            }
            else {
                console.log('✅ Réconciliation réussie: les balances correspondent');
            }
            // 7. Enregistrer le rapport dans Firestore
            await this.saveReport(report);
            return report;
        }
        catch (error) {
            console.error('❌ Échec de la tâche de réconciliation:', error);
            // Enregistrer l'erreur
            await this.db.collection('reconciliation_errors').add({
                timestamp: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                error: error.message,
                stack: error.stack
            });
            throw error;
        }
    }
    /**
     * Récupère la balance disponible du compte Stripe principal
     * @returns Balance en centimes
     */
    async getPlatformBalance() {
        try {
            const balance = await (0, stripe_1.getStripe)().balance.retrieve();
            // Additionner toutes les balances disponibles en EUR
            let sum = 0;
            // Usamos type casting explícito para resolver el problema de tipos
            for (const bal of balance.available) {
                if (bal.currency === 'eur') {
                    sum += bal.amount;
                }
            }
            return sum;
        }
        catch (error) {
            console.error('Erreur lors de la récupération de la balance plateforme:', error);
            throw new Error(`Impossible de récupérer la balance Stripe: ${error.message}`);
        }
    }
    /**
     * Récupère la somme des balances des comptes Stripe Connect
     * @returns Balance totale en centimes et détails
     */
    async getConnectedAccountsBalance() {
        // 1. Récupérer tous les utilisateurs avec un compte Stripe Connect
        const users = await this.userRepository.getAllWithConnectAccount();
        // 2. Pour chaque compte, récupérer la balance disponible
        let totalBalance = 0;
        let accountsChecked = 0;
        const errorAccounts = [];
        for (const user of users) {
            try {
                if (!user.connectAccountId)
                    continue;
                const accountBalance = await (0, stripe_1.getStripe)().balance.retrieve({
                    stripeAccount: user.connectAccountId,
                });
                // Additionner les balances disponibles en EUR
                let accountTotal = 0;
                for (const bal of accountBalance.available) {
                    if (bal.currency === 'eur') {
                        accountTotal += bal.amount;
                    }
                }
                totalBalance += accountTotal;
                accountsChecked++;
            }
            catch (error) {
                console.error(`Erreur récupération balance pour compte ${user.connectAccountId}:`, error);
                errorAccounts.push(user.connectAccountId || 'unknown');
                // Continuer avec le prochain compte
            }
        }
        return {
            balance: totalBalance,
            accountsChecked,
            errorAccounts: errorAccounts.length > 0 ? errorAccounts : undefined
        };
    }
    /**
     * Envoie une alerte en cas d'écart de réconciliation
     * @param report Rapport de réconciliation
     */
    async sendAlert(report) {
        console.warn(`⚠️ ALERTE: Écart de réconciliation de ${report.discrepancy} centimes détecté`);
        // Enregistrer l'alerte dans Firestore
        await this.db.collection('reconciliation_alerts').add({
            ...report,
            createdAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            acknowledged: false
        });
        // Ici, vous pourriez implémenter l'envoi d'alertes par:
        // - Email (SendGrid, Mailgun, etc.)
        // - SMS (Twilio, etc.)
        // - Slack/Discord
        // - Notification push aux administrateurs
    }
    /**
     * Sauvegarde le rapport de réconciliation dans Firestore
     * @param report Rapport de réconciliation
     */
    async saveReport(report) {
        await this.db.collection('reconciliation_reports').add({
            ...report,
            createdAt: firebase_1.admin.firestore.FieldValue.serverTimestamp()
        });
    }
}
exports.ReconciliationJob = ReconciliationJob;
//# sourceMappingURL=ReconciliationJob.js.map