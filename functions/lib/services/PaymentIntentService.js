"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentIntentService = void 0;
class PaymentIntentService {
    constructor(stripe) {
        this.stripe = stripe;
    }
    async createPaymentIntent(params) {
        return this.stripe.paymentIntents.create({
            amount: params.amount,
            currency: params.currency ?? 'eur',
            description: params.description,
            payment_method_types: ['card'],
            transfer_data: { destination: params.destinationAccountId },
            metadata: params.metadata,
        });
    }
    async retrievePaymentIntent(id) {
        return this.stripe.paymentIntents.retrieve(id);
    }
}
exports.PaymentIntentService = PaymentIntentService;
//# sourceMappingURL=PaymentIntentService.js.map