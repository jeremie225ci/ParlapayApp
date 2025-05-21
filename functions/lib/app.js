"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const body_parser_1 = require("body-parser");
const node_cron_1 = __importDefault(require("node-cron"));
const firebase_1 = require("./config/firebase");
const stripe_1 = require("./config/stripe");
const UserRepository_1 = require("./repositories/UserRepository");
const LedgerService_1 = require("./services/LedgerService");
const P2PService_1 = require("./services/P2PService");
const PayoutService_1 = require("./services/PayoutService");
const StripeAccountService_1 = require("./services/StripeAccountService");
const PaymentIntentService_1 = require("./services/PaymentIntentService");
const TransferService_1 = require("./services/TransferService");
const ReconciliationJob_1 = require("./jobs/ReconciliationJob");
const walletController_1 = require("./controllers/walletController");
const webhookController_1 = require("./controllers/webhookController");
const SimpleKYCService_1 = require("./services/SimpleKYCService");
const SimpleKYCController_1 = require("./controllers/SimpleKYCController");
const BankInfoReminderController_1 = require("./controllers/BankInfoReminderController");
// 0) Inicializar Stripe
(0, stripe_1.initializeStripe)().then(() => {
    console.log('✅ Stripe inicializado correctamente');
}).catch(error => {
    console.error('❌ Error al inicializar Stripe:', error);
    process.exit(1);
});
// 1) Inicializar Express
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use((0, body_parser_1.json)());
// Para webhook de Stripe, usamos raw
app.use('/api/webhook', (0, body_parser_1.raw)({ type: 'application/json' }));
// 2) Instanciar repositorios y servicios
const userRepo = new UserRepository_1.UserRepository();
const ledgerSvc = new LedgerService_1.LedgerService();
const p2pSvc = new P2PService_1.P2PService(ledgerSvc, userRepo);
const payoutSvc = new PayoutService_1.PayoutService(ledgerSvc, userRepo);
const stripeAcctSvc = new StripeAccountService_1.StripeAccountService((0, stripe_1.getStripe)());
const paymentIntentSvc = new PaymentIntentService_1.PaymentIntentService((0, stripe_1.getStripe)());
const transferSvc = new TransferService_1.TransferService(ledgerSvc, userRepo);
const simpleKYCService = new SimpleKYCService_1.SimpleKYCService(userRepo, stripeAcctSvc);
// 3) Instanciar controladores
const walletCtrl = new walletController_1.WalletController(ledgerSvc, p2pSvc, payoutSvc, stripeAcctSvc, paymentIntentSvc, userRepo);
const webhookCtrl = new webhookController_1.WebhookController(stripeAcctSvc, firebase_1.admin.firestore(), (0, stripe_1.getWebhookSecret)(), payoutSvc, ledgerSvc);
const simpleKYCController = new SimpleKYCController_1.SimpleKYCController(simpleKYCService, userRepo);
const bankInfoReminderCtrl = new BankInfoReminderController_1.BankInfoReminderController(userRepo, stripeAcctSvc);
// 4) Middleware de logging
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});
// 5) Definir rutas
// Health check
app.get('/api/healthz', (_req, res) => res.json({
    status: 'ok',
    version: process.env.npm_package_version || '1.0.0',
    timestamp: new Date().toISOString(),
}));
// Wallet y pagos
app.post('/api/createPaymentIntent', (req, res) => walletCtrl.createPaymentIntent(req, res));
app.post('/api/confirmPayment', (req, res) => walletCtrl.confirmPayment(req, res));
app.post('/api/transferFunds', (req, res) => walletCtrl.transferFunds(req, res));
app.post('/api/withdrawFunds', (req, res) => walletCtrl.withdrawFunds(req, res));
app.get('/api/wallet/:userId', (req, res) => walletCtrl.getWallet(req, res));
// Simple KYC endpoints
app.post('/api/initiateKYC', (req, res) => simpleKYCController.initiateKYC(req, res));
app.post('/api/validateKYC', (req, res) => simpleKYCController.validateKYC(req, res));
app.get('/api/kycStatus/:userId', (req, res) => simpleKYCController.getKYCStatus(req, res));
// Información bancaria
app.post('/api/updateBankInfo', (req, res) => bankInfoReminderCtrl.updateMissingBankInfo(req, res));
// Webhook de Stripe
app.post('/api/webhook', (req, res) => webhookCtrl.handleWebhook(req, res));
// 6) Error handler
app.use((err, req, res, next) => {
    console.error(`[${new Date().toISOString()}] ❌ Error:`, err);
    res.status(500).json({
        status: 'error',
        timestamp: new Date().toISOString(),
        error: err.message,
    });
});
// 7) Programar tareas
// Reconciliación diaria
node_cron_1.default.schedule('0 0 * * *', async () => {
    console.log('🔄 Ejecutando job de reconciliación');
    try {
        await new ReconciliationJob_1.ReconciliationJob(ledgerSvc, userRepo).run();
    }
    catch (err) {
        console.error('❌ Error en reconciliación:', err);
    }
});
// Recordatorios de información bancaria
node_cron_1.default.schedule('0 10 * * *', async () => {
    console.log('📧 Ejecutando job de recordatorios bancarios');
    try {
        await bankInfoReminderCtrl.checkAndRemindIncompleteAccounts();
    }
    catch (err) {
        console.error('❌ Error en recordatorios:', err);
    }
});
exports.default = app;
//# sourceMappingURL=app.js.map