"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const kyc_service_1 = require("../services/kyc-service");
const UserRepository_1 = require("../repositories/UserRepository");
const WalletRepository_1 = require("../repositories/WalletRepository");
const rapyd_init_1 = require("../services/rapyd_init");
const router = express_1.default.Router();
// Instanciar repositorios y servicios directamente
const userRepository = new UserRepository_1.UserRepository();
const walletRepository = new WalletRepository_1.WalletRepository();
const rapydService = (0, rapyd_init_1.getRapyd)();
const kycService = new kyc_service_1.KYCService();
// Ruta para validar KYC
router.post("/validate", async (req, res) => {
    try {
        const { userId, userData } = req.body;
        if (!userId || !userData) {
            return res.status(400).json({
                success: false,
                message: "Se requieren userId y userData",
            });
        }
        console.log(`Procesando validación KYC para usuario ${userId}`);
        console.log("Datos recibidos:", userData);
        // Procesar KYC utilizando el servicio existente
        const result = await kycService.processKYC(userId, {
            firstName: userData.firstName,
            lastName: userData.lastName,
            email: userData.email,
            phoneNumber: userData.phoneNumber,
            birthDate: userData.birthDate,
            address: userData.address,
            city: userData.city,
            postalCode: userData.postalCode,
            country: userData.country,
        });
        if (result.success) {
            return res.status(200).json({
                success: true,
                message: "KYC procesado correctamente",
                walletId: result.walletId,
                kycStatus: "approved",
            });
        }
        else {
            // Si ya tiene wallet, no es un error crítico
            if (result.walletId) {
                return res.status(200).json({
                    success: true,
                    message: "El usuario ya tiene un wallet",
                    walletId: result.walletId,
                    kycStatus: "approved",
                });
            }
            return res.status(400).json({
                success: false,
                message: result.error || "Error procesando KYC",
            });
        }
    }
    catch (error) {
        console.error("Error en validación KYC:", error);
        return res.status(500).json({
            success: false,
            message: error instanceof Error ? error.message : "Error interno del servidor",
        });
    }
});
// Ruta para obtener el estado KYC
router.get("/kyc-status/:userId", async (req, res) => {
    try {
        const { userId } = req.params;
        if (!userId) {
            return res.status(400).json({
                success: false,
                message: "Se requiere userId",
            });
        }
        // Obtener usuario
        const user = await userRepository.getUserById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: "Usuario no encontrado",
            });
        }
        return res.status(200).json({
            success: true,
            kycStatus: user.kycStatus || "pending",
            kycCompleted: user.kycCompleted || false,
            rapydWalletId: user.rapydWalletId,
            rapydIdentityId: user.rapydIdentityId,
        });
    }
    catch (error) {
        console.error("Error obteniendo estado KYC:", error);
        return res.status(500).json({
            success: false,
            message: error instanceof Error ? error.message : "Error interno del servidor",
        });
    }
});
// Ruta para obtener el balance del wallet
router.get("/balance/:userId", async (req, res) => {
    try {
        const { userId } = req.params;
        if (!userId) {
            return res.status(400).json({
                success: false,
                message: "Se requiere userId",
            });
        }
        // Obtener wallet
        const wallet = await walletRepository.getWallet(userId);
        if (!wallet) {
            return res.status(404).json({
                success: false,
                message: "Wallet no encontrado",
            });
        }
        // Si tiene wallet en Rapyd, sincronizar balance
        const user = await userRepository.getUserById(userId);
        if (user && user.rapydWalletId) {
            try {
                const balanceData = await rapydService.getWalletBalance(user.rapydWalletId);
                // Actualizar balance en Firestore
                await walletRepository.updateWallet(userId, {
                    balance: balanceData.balance,
                    updatedAt: new Date(),
                });
                return res.status(200).json({
                    success: true,
                    balance: balanceData.balance,
                    currency: balanceData.currency || "EUR",
                    accounts: balanceData.accounts,
                });
            }
            catch (error) {
                console.error("Error sincronizando balance:", error);
                // Devolver el balance almacenado en caso de error
                return res.status(200).json({
                    success: true,
                    balance: wallet.balance,
                    currency: wallet.currency || "EUR",
                    syncError: "No se pudo sincronizar con Rapyd",
                });
            }
        }
        // Si no tiene wallet en Rapyd, devolver el balance almacenado
        return res.status(200).json({
            success: true,
            balance: wallet.balance,
            currency: wallet.currency || "EUR",
        });
    }
    catch (error) {
        console.error("Error obteniendo balance:", error);
        return res.status(500).json({
            success: false,
            message: error instanceof Error ? error.message : "Error interno del servidor",
        });
    }
});
// Exportar router
exports.default = router;
//# sourceMappingURL=rapyd_routes.js.map