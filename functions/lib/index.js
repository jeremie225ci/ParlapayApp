"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.g2 = void 0;
const https_1 = require("firebase-functions/v2/https");
const app_1 = require("firebase-admin/app");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const body_parser_1 = require("body-parser");
const rapyd_routes_1 = __importDefault(require("./routes/rapyd_routes"));
const checkout_routes_1 = __importDefault(require("./routes/checkout_routes"));
// Variable para rastrear el estado de inicialización
const initializationStatus = {
    firebase: false,
    repositories: false,
    rapyd: false,
    controllers: false,
    routes: false,
};
// Inicializar Firebase Admin
console.log("Inicializando Firebase Admin...");
try {
    (0, app_1.initializeApp)();
    console.log("Firebase Admin inicializado correctamente");
    initializationStatus.firebase = true;
}
catch (error) {
    console.error("Error inicializando Firebase Admin:", error);
}
// Configurar Express
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use((0, body_parser_1.json)());
app.use("/webhook", (0, body_parser_1.raw)({ type: "application/json" }));
// Health check
app.get("/healthz", (_req, res) => {
    res.status(200).json({
        status: "ok",
        initialization: initializationStatus,
        timestamp: new Date().toISOString(),
    });
});
// Ruta raíz
app.get("/", (_req, res) => {
    res.json({
        status: "ok",
        version: "1.0.0",
        initialization: initializationStatus,
        timestamp: new Date().toISOString(),
    });
});
// Importar servicios y controladores
const rapyd_init_1 = require("./services/rapyd_init");
const UserRepository_1 = require("./repositories/UserRepository");
const WalletRepository_1 = require("./repositories/WalletRepository");
const rapyd_controller_1 = require("./controllers/rapyd_controller");
const kyc_controller_1 = require("./controllers/kyc_controller");
const rapyd_webhook_service_1 = require("./services/rapyd_webhook_service");
const createCheckout_1 = require("./controllers/payment/createCheckout");
// Variables globales para servicios
let userRepository = null;
let walletRepository = null;
let rapydWebhookService = null;
let rapydController = null;
let kycController = null;
let checkoutController = null;
// Función para configurar rutas (disponibles siempre)
function setupRoutes() {
    // Rapyd
    app.use("/api/rapyd", rapyd_routes_1.default);
    // Checkout (nuevas rutas)
    app.use("/api/checkout", checkout_routes_1.default);
    // Legacy: endpoints de integración directa para Flutter
    app.post("/wallet/add-funds-card", (req, res) => {
        if (!checkoutController) {
            return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
        }
        checkoutController.createCheckout(req, res);
    });
    app.get("/wallet/verify-payment/:checkoutId", (req, res) => {
        if (!checkoutController) {
            return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
        }
        checkoutController.verifyCheckout(req, res);
    });
    // KYC
    app.post("/kyc/process", (req, res) => {
        if (!kycController) {
            return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
        }
        kycController.processKYC(req, res);
    });
    app.get("/kyc/status/:userId", (req, res) => {
        if (!kycController) {
            return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
        }
        kycController.checkKYCStatus(req, res);
    });
    // Wallet
    app.post("/wallet/create", (req, res) => rapydController ? rapydController.createWallet(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    app.get("/wallet/balance/:userId", (req, res) => rapydController ? rapydController.getWalletBalance(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // MODIFICADA: Endpoint para transferencia actualizado para usar el nuevo endpoint de Rapyd
    app.post("/v1/ewallets/transfer", (req, res) => rapydController ? rapydController.transferFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // Mantener también el endpoint antiguo por compatibilidad
    app.post("/wallet/transfer", (req, res) => rapydController ? rapydController.transferFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    app.post("/wallet/add-funds", (req, res) => rapydController ? rapydController.addFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // Withdraw and transactions
    app.post("/wallet/withdraw", (req, res) => rapydController ? rapydController.withdrawFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    app.get("/wallet/transactions/:userId", (req, res) => rapydController ? rapydController.getTransactionHistory(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // Beneficiaries
    app.post("/beneficiary/create", (req, res) => rapydController ? rapydController.createBeneficiary(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // Identity verification
    app.post("/identity/verify", (req, res) => rapydController ? rapydController.verifyIdentity(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    app.get("/identity/status/:userId", (req, res) => rapydController ? rapydController.getIdentityStatus(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // Webhook
    app.post("/webhook", (req, res) => rapydWebhookService ? rapydWebhookService.handleWebhook(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." }));
    // Test connection
    app.get("/testConnection", (_req, res) => res.json({ success: true, initialization: initializationStatus }));
}
// Configurar rutas inmediatamente
setupRoutes();
initializationStatus.routes = true;
// Inicializar servicios en segundo plano
(async () => {
    try {
        userRepository = new UserRepository_1.UserRepository();
        walletRepository = new WalletRepository_1.WalletRepository();
        initializationStatus.repositories = true;
        // Iniciar servicio Rapyd después de crear los repositorios
        await (0, rapyd_init_1.initializeRapyd)();
        initializationStatus.rapyd = true;
        // Crear controladores después de que los servicios estén disponibles
        rapydController = new rapyd_controller_1.RapydController();
        kycController = new kyc_controller_1.KYCController();
        checkoutController = new createCheckout_1.CheckoutController();
        rapydWebhookService = new rapyd_webhook_service_1.RapydWebhookService();
        initializationStatus.controllers = true;
        console.log("Servicios inicializados correctamente");
    }
    catch (error) {
        console.error("Error inicializando servicios:", error);
    }
})();
// Manejo de errores
app.use((err, req, res, next) => {
    console.error("Error no manejado:", err);
    res.status(500).json({ success: false, error: err.message, initialization: initializationStatus });
});
// Exportar función Gen2
exports.g2 = (0, https_1.onRequest)({
    region: "us-central1",
    memory: "512MiB",
    maxInstances: 3,
    timeoutSeconds: 540,
    concurrency: 1,
    cpu: 1,
}, app);
//# sourceMappingURL=index.js.map