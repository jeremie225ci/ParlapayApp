"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.StripeAccountService = void 0;
const stripe_1 = require("../config/stripe");
class StripeAccountService {
    constructor(stripe) {
        // Si se proporciona una instancia de Stripe, la usamos; de lo contrario, obtenemos una nueva
        this.stripe = stripe || (0, stripe_1.getStripe)();
    }
    /**
     * Crea una cuenta Express con información completa
     */
    async createExpressAccountWithFullInfo(accountData) {
        try {
            console.log("Creando cuenta Express con datos completos:", JSON.stringify(accountData, null, 2));
            const account = await this.stripe.accounts.create({
                type: "express",
                ...accountData,
            });
            console.log("Cuenta Express creada:", account.id);
            return account;
        }
        catch (error) {
            console.error("Error creando cuenta Express:", error);
            throw error;
        }
    }
    /**
     * Añade una cuenta bancaria externa a una cuenta Stripe
     */
    async addExternalBankAccount(accountId, bankAccountData) {
        try {
            console.log(`Añadiendo cuenta bancaria a cuenta ${accountId}:`, JSON.stringify(bankAccountData, null, 2));
            // Stripe espera que external_account sea un string (token) o un objeto con formato específico
            // Para IBAN, necesitamos usar un formato específico como string
            const externalAccount = {
                object: "bank_account",
                country: bankAccountData.external_account.country,
                currency: bankAccountData.external_account.currency,
                account_holder_name: bankAccountData.external_account.account_holder_name,
                account_holder_type: bankAccountData.external_account.account_holder_type,
                account_number: bankAccountData.external_account.iban, // Usar el IBAN como account_number
            };
            console.log("Datos de cuenta bancaria formateados:", JSON.stringify(externalAccount, null, 2));
            // Usar el formato correcto para createExternalAccount
            const bankAccount = await this.stripe.accounts.createExternalAccount(accountId, {
                external_account: externalAccount,
            });
            console.log("Cuenta bancaria añadida:", bankAccount.id);
            return bankAccount;
        }
        catch (error) {
            console.error("Error añadiendo cuenta bancaria:", error);
            throw error;
        }
    }
    /**
     * Acepta los términos de servicio de Stripe para una cuenta
     */
    async acceptTermsOfService(accountId) {
        try {
            console.log(`Aceptando términos de servicio para cuenta ${accountId}`);
            const account = await this.stripe.accounts.update(accountId, {
                tos_acceptance: {
                    date: Math.floor(Date.now() / 1000),
                    ip: "127.0.0.1", // IP desde donde se acepta (usamos localhost para pruebas)
                },
            });
            console.log("Términos de servicio aceptados para cuenta:", accountId);
            return account;
        }
        catch (error) {
            console.error(`Error aceptando términos de servicio para cuenta ${accountId}:`, error);
            throw error;
        }
    }
    /**
     * Crea un link de onboarding para una cuenta Stripe
     */
    async createAccountLink(accountId, refreshUrl, returnUrl) {
        try {
            console.log(`Creando link de onboarding para cuenta ${accountId}`);
            const accountLink = await this.stripe.accountLinks.create({
                account: accountId,
                refresh_url: refreshUrl,
                return_url: returnUrl,
                type: "account_onboarding",
            });
            console.log("Link de onboarding creado:", accountLink.url);
            return accountLink;
        }
        catch (error) {
            console.error("Error creando link de onboarding:", error);
            throw error;
        }
    }
    /**
     * Verifica el estado de una cuenta Stripe
     */
    async checkAccountStatus(accountId) {
        try {
            console.log(`Verificando estado de cuenta ${accountId}`);
            const account = await this.stripe.accounts.retrieve(accountId);
            // Determinar si hay campos faltantes o restricciones
            const isComplete = account.charges_enabled && account.payouts_enabled && account.details_submitted;
            const restricted = Boolean(account.requirements?.disabled_reason);
            const missingFields = account.requirements?.currently_due || [];
            return {
                id: account.id,
                charges_enabled: account.charges_enabled,
                payouts_enabled: account.payouts_enabled,
                details_submitted: account.details_submitted,
                requirements: account.requirements,
                isComplete,
                restricted,
                missingFields,
            };
        }
        catch (error) {
            console.error(`Error verificando estado de cuenta ${accountId}:`, error);
            throw error;
        }
    }
    /**
     * Recupera una cuenta Stripe
     */
    async retrieveAccount(accountId) {
        try {
            console.log(`Recuperando cuenta ${accountId}`);
            const account = await this.stripe.accounts.retrieve(accountId);
            return account;
        }
        catch (error) {
            console.error(`Error recuperando cuenta ${accountId}:`, error);
            throw error;
        }
    }
}
exports.StripeAccountService = StripeAccountService;
//# sourceMappingURL=StripeAccountService.js.map