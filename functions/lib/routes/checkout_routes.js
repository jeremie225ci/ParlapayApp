"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
// src/routes/checkout.routes.ts
const express_1 = require("express");
const createCheckout_1 = require("../controllers/payment/createCheckout");
const router = (0, express_1.Router)();
const checkoutController = new createCheckout_1.CheckoutController();
/**
 * POST /api/checkout/create
 * Crea la página de checkout en Rapyd y devuelve { checkoutUrl, checkoutId, ... }
 */
router.post('/create', (req, res) => checkoutController.createCheckout(req, res));
/**
 * GET /api/checkout/:checkoutId
 * Verifica el estado de un checkout existente
 */
router.get('/:checkoutId', (req, res) => checkoutController.verifyCheckout(req, res));
/**
 * GET /api/checkout/init-balances
 * Inicializa el campo balance en todas las wallets existentes
 * IMPORTANTE: Esta ruta debe ir ANTES de /:checkoutId para que no sea interpretada como un ID
 */
router.get('/init-balances', (req, res) => checkoutController.initializeWalletBalances(req, res));
/**
 * GET /api/checkout/wallet/balance/:userId
 * Obtiene el balance actual de la wallet de un usuario desde Firestore
 */
router.get('/wallet/balance/:userId', (req, res) => checkoutController.getBalance(req, res));
/**
 * GET /api/checkout/wallet/get-balance
 * Obtiene el balance desde Rapyd y actualiza Firestore
 */
router.get('/wallet/get-balance', (req, res) => checkoutController.getBalanceFromRapyd(req, res));
/**
 * GET /api/checkout/wallet/refresh-balance/:userId
 * Actualiza el balance desde Rapyd para un usuario específico y devuelve el nuevo balance
 */
router.get('/wallet/refresh-balance/:userId', (req, res) => checkoutController.getBalanceFromRapyd(req, res));
/**
 * GET /api/checkout/wallet/sync-balance/:userId
 * Sincroniza el balance del usuario con más robustez, intentando multiples métodos
 * si el principal falla
 */
router.get('/wallet/sync-balance/:userId', (req, res) => checkoutController.syncWalletBalance(req, res));
exports.default = router;
//# sourceMappingURL=checkout_routes.js.map