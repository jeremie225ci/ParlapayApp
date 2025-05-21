"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SimpleKYCController = void 0;
class SimpleKYCController {
    constructor(simpleKYCService, userRepository) {
        this.simpleKYCService = simpleKYCService;
        this.userRepository = userRepository;
    }
    /**
     * Inicia el proceso de KYC con datos personales
     */
    async initiateKYC(req, res) {
        try {
            console.log("Iniciando KYC con datos:", req.body);
            const { userId, personalData } = req.body;
            if (!userId || !personalData) {
                res.status(400).json({ error: "userId y personalData son requeridos" });
                return;
            }
            // Validar campos mínimos
            const requiredFields = ["firstName", "lastName", "email", "birthDate", "address", "city", "postalCode", "country"];
            const missingFields = requiredFields.filter((field) => !personalData[field]);
            if (missingFields.length > 0) {
                res.status(400).json({
                    error: `Faltan campos obligatorios: ${missingFields.join(", ")}`,
                });
                return;
            }
            // Iniciar KYC
            const result = await this.simpleKYCService.initiateKYC(userId, personalData);
            res.json(result);
        }
        catch (error) {
            console.error("Error iniciando KYC:", error);
            res.status(500).json({ error: error.message, success: false });
        }
    }
    /**
     * Valida el KYC y crea la cuenta Stripe
     */
    async validateKYC(req, res) {
        try {
            console.log("Validando KYC con datos:", req.body);
            const { userId, userData } = req.body;
            if (!userId) {
                res.status(400).json({ error: "userId es requerido", success: false });
                return;
            }
            // Validar KYC y crear cuenta Stripe
            const result = await this.simpleKYCService.validateKYC(userId, userData);
            res.json(result);
        }
        catch (error) {
            console.error("Error validando KYC:", error);
            res.status(500).json({ error: error.message, success: false });
        }
    }
    /**
     * Obtiene el estado del KYC
     */
    async getKYCStatus(req, res) {
        try {
            const { userId } = req.params;
            if (!userId) {
                res.status(400).json({ error: "userId es requerido", success: false });
                return;
            }
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                res.status(404).json({ error: "Usuario no encontrado", success: false });
                return;
            }
            res.json({
                success: true,
                kycStatus: user.kycStatus || "not_started",
                kycCompleted: user.kycCompleted || false,
                connectAccountId: user.connectAccountId,
            });
        }
        catch (error) {
            console.error("Error obteniendo estado KYC:", error);
            res.status(500).json({ error: error.message, success: false });
        }
    }
    /**
     * Completa manualmente los requisitos pendientes de una cuenta
     */
    async completeAccountRequirements(req, res) {
        try {
            const { userId } = req.params;
            if (!userId) {
                res.status(400).json({ error: "userId es requerido", success: false });
                return;
            }
            const user = await this.userRepository.getUserById(userId);
            if (!user || !user.connectAccountId) {
                res.status(404).json({ error: "Usuario no encontrado o sin cuenta Stripe", success: false });
                return;
            }
            // Aceptar términos de servicio
            await this.simpleKYCService.acceptTermsOfService(user.connectAccountId);
            // Si hay IBAN, añadir cuenta bancaria
            if (user.iban) {
                await this.simpleKYCService.addExternalBankAccount(user.connectAccountId, {
                    external_account: {
                        object: "bank_account",
                        account_holder_name: `${user.firstName} ${user.lastName}`,
                        account_holder_type: "individual",
                        country: user.country || "ES",
                        currency: "eur",
                        iban: user.iban,
                    },
                });
            }
            // Verificar estado actualizado
            const status = await this.simpleKYCService.checkAccountStatus(user.connectAccountId);
            res.json({
                success: true,
                message: "Requisitos de cuenta completados",
                status: status,
            });
        }
        catch (error) {
            console.error("Error completando requisitos de cuenta:", error);
            res.status(500).json({ error: error.message, success: false });
        }
    }
}
exports.SimpleKYCController = SimpleKYCController;
//# sourceMappingURL=SimpleKYCController.js.map