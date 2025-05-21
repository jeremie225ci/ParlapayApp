import { onRequest } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import express from "express";
import cors from "cors";
import { json, raw } from "body-parser";
import rapydRoutes from "./routes/rapyd_routes";
import checkoutRoutes from "./routes/checkout_routes";

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
  initializeApp();
  console.log("Firebase Admin inicializado correctamente");
  initializationStatus.firebase = true;
} catch (error) {
  console.error("Error inicializando Firebase Admin:", error);
}

// Configurar Express
const app = express();
app.use(cors({ origin: true }));
app.use(json());
app.use("/webhook", raw({ type: "application/json" }));

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
import { initializeRapyd, getRapyd } from "./services/rapyd_init";
import { UserRepository } from "./repositories/UserRepository";
import { WalletRepository } from "./repositories/WalletRepository";
import { RapydController } from "./controllers/rapyd_controller";
import { KYCController } from "./controllers/kyc_controller";
import { RapydWebhookService } from "./services/rapyd_webhook_service";
import { CheckoutController } from "./controllers/payment/createCheckout";
import type { Request, Response, NextFunction } from "express";

// Variables globales para servicios
let userRepository: UserRepository | null = null;
let walletRepository: WalletRepository | null = null;
let rapydWebhookService: RapydWebhookService | null = null;
let rapydController: RapydController | null = null;
let kycController: KYCController | null = null;
let checkoutController: CheckoutController | null = null;

// Función para configurar rutas (disponibles siempre)
function setupRoutes() {
  // Rapyd
  app.use("/api/rapyd", rapydRoutes);

  // Checkout (nuevas rutas)
  app.use("/api/checkout", checkoutRoutes);

  // Legacy: endpoints de integración directa para Flutter
  app.post("/wallet/add-funds-card", (req: Request, res: Response) => {
    if (!checkoutController) {
      return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
    }
    checkoutController.createCheckout(req, res);
  });
  app.get("/wallet/verify-payment/:checkoutId", (req: Request, res: Response) => {
    if (!checkoutController) {
      return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
    }
    checkoutController.verifyCheckout(req, res);
  });

  // KYC
  app.post("/kyc/process", (req: Request, res: Response) => {
    if (!kycController) {
      return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
    }
    kycController.processKYC(req, res);
  });
  app.get("/kyc/status/:userId", (req: Request, res: Response) => {
    if (!kycController) {
      return res.status(503).json({ success: false, error: "Servicio no disponible.", initialization: initializationStatus });
    }
    kycController.checkKYCStatus(req, res);
  });

  // Wallet
  app.post("/wallet/create", (req, res) =>
    rapydController ? rapydController.createWallet(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );
  app.get("/wallet/balance/:userId", (req, res) =>
    rapydController ? rapydController.getWalletBalance(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );
  
  // MODIFICADA: Endpoint para transferencia actualizado para usar el nuevo endpoint de Rapyd
  app.post("/v1/ewallets/transfer", (req, res) =>
    rapydController ? rapydController.transferFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );
  
  // Mantener también el endpoint antiguo por compatibilidad
  app.post("/wallet/transfer", (req, res) =>
    rapydController ? rapydController.transferFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );
  
  app.post("/wallet/add-funds", (req, res) =>
    rapydController ? rapydController.addFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );

  // Withdraw and transactions
  app.post("/wallet/withdraw", (req, res) =>
    rapydController ? rapydController.withdrawFunds(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );
  app.get("/wallet/transactions/:userId", (req, res) =>
    rapydController ? rapydController.getTransactionHistory(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );

  // Beneficiaries
  app.post("/beneficiary/create", (req, res) =>
    rapydController ? rapydController.createBeneficiary(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );

  // Identity verification
  app.post("/identity/verify", (req, res) =>
    rapydController ? rapydController.verifyIdentity(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );
  app.get("/identity/status/:userId", (req, res) =>
    rapydController ? rapydController.getIdentityStatus(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );

  // Webhook
  app.post("/webhook", (req, res) =>
    rapydWebhookService ? rapydWebhookService.handleWebhook(req, res) : res.status(503).json({ success: false, error: "Servicio no disponible." })
  );

  // Test connection
  app.get("/testConnection", (_req, res) =>
    res.json({ success: true, initialization: initializationStatus })
  );
}

// Configurar rutas inmediatamente
setupRoutes();
initializationStatus.routes = true;

// Inicializar servicios en segundo plano
(async () => {
  try {
    userRepository = new UserRepository();
    walletRepository = new WalletRepository();
    initializationStatus.repositories = true;

    // Iniciar servicio Rapyd después de crear los repositorios
    await initializeRapyd();
    initializationStatus.rapyd = true;

    // Crear controladores después de que los servicios estén disponibles
    rapydController = new RapydController();
    kycController = new KYCController();
    checkoutController = new CheckoutController();
    rapydWebhookService = new RapydWebhookService();
    initializationStatus.controllers = true;

    console.log("Servicios inicializados correctamente");
  } catch (error) {
    console.error("Error inicializando servicios:", error);
  }
})();

// Manejo de errores
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error("Error no manejado:", err);
  res.status(500).json({ success: false, error: err.message, initialization: initializationStatus });
});

// Exportar función Gen2
export const g2 = onRequest(
  {
    region: "us-central1",
    memory: "512MiB",
    maxInstances: 3,
    timeoutSeconds: 540,
    concurrency: 1,
    cpu: 1,
  },
  app
);