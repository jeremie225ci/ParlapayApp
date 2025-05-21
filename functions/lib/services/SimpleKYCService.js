"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SimpleKYCService = void 0;
const firebase_1 = require("../config/firebase");
// Mapa de nombres de países comunes a códigos ISO
const COUNTRY_NAME_TO_CODE = {
    España: "ES",
    Spain: "ES",
    "Estados Unidos": "US",
    "United States": "US",
    "Reino Unido": "GB",
    "United Kingdom": "GB",
    Francia: "FR",
    France: "FR",
    Alemania: "DE",
    Germany: "DE",
    Italia: "IT",
    Italy: "IT",
    Portugal: "PT",
    // Añadir más países según sea necesario
};
class SimpleKYCService {
    constructor(userRepository, stripeAccountService) {
        this.userRepository = userRepository;
        this.stripeAccountService = stripeAccountService;
    }
    /**
     * Inicia el proceso de KYC simple
     */
    async initiateKYC(userId, personalData) {
        try {
            // Convertir país a código ISO si es necesario
            if (personalData.country && COUNTRY_NAME_TO_CODE[personalData.country]) {
                console.log(`Convirtiendo país '${personalData.country}' a código ISO '${COUNTRY_NAME_TO_CODE[personalData.country]}'`);
                personalData.country = COUNTRY_NAME_TO_CODE[personalData.country];
            }
            // Actualizar usuario con datos personales
            await this.userRepository.updateUser(userId, {
                ...personalData,
                kycStatus: "initiated",
                kycInitiatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
            return {
                success: true,
                message: "KYC iniciado correctamente",
                kycStatus: "initiated",
            };
        }
        catch (error) {
            console.error("Error iniciando KYC:", error);
            throw error;
        }
    }
    /**
     * Valida los datos del KYC y crea la cuenta de Stripe
     */
    async validateKYC(userId, additionalData) {
        try {
            console.log(`Validando KYC para usuario: ${userId}`);
            // Obtener datos del usuario
            const user = await this.userRepository.getUserById(userId);
            if (!user)
                throw new Error("Usuario no encontrado");
            // Convertir país a código ISO si es necesario
            if (user.country && COUNTRY_NAME_TO_CODE[user.country]) {
                console.log(`Convirtiendo país '${user.country}' a código ISO '${COUNTRY_NAME_TO_CODE[user.country]}'`);
                user.country = COUNTRY_NAME_TO_CODE[user.country];
            }
            // Verificar que tenga todos los datos necesarios
            this.verifyUserData(user);
            // Crear cuenta Stripe con la información validada
            const stripeAccount = await this.createStripeAccount(user);
            // Aceptar términos de servicio automáticamente
            await this.stripeAccountService.acceptTermsOfService(stripeAccount.id);
            // Actualizar estado KYC
            await this.userRepository.updateUser(userId, {
                kycStatus: "approved",
                kycCompleted: true,
                kycApprovedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                connectAccountId: stripeAccount.id,
                chargesEnabled: stripeAccount.charges_enabled,
                payoutsEnabled: stripeAccount.payouts_enabled,
                detailsSubmitted: stripeAccount.details_submitted,
                stripeRequirements: stripeAccount.requirements,
            });
            // Crear wallet si no existe
            await this.createUserWallet(userId);
            return {
                success: true,
                message: "KYC validado y cuenta Stripe creada",
                accountId: stripeAccount.id,
            };
        }
        catch (error) {
            console.error("Error validando KYC:", error);
            // Registrar el rechazo
            await this.userRepository.updateUser(userId, {
                kycStatus: "rejected",
                kycCompleted: false,
                kycRejectedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                kycRejectionReason: error.message,
            });
            throw error;
        }
    }
    /**
     * Método público para aceptar términos de servicio
     */
    async acceptTermsOfService(accountId) {
        return await this.stripeAccountService.acceptTermsOfService(accountId);
    }
    /**
     * Método público para añadir cuenta bancaria
     */
    async addExternalBankAccount(accountId, bankAccountData) {
        return await this.stripeAccountService.addExternalBankAccount(accountId, bankAccountData);
    }
    /**
     * Método público para verificar estado de cuenta
     */
    async checkAccountStatus(accountId) {
        return await this.stripeAccountService.checkAccountStatus(accountId);
    }
    /**
     * Verifica que el usuario tenga todos los datos necesarios
     */
    verifyUserData(user) {
        // Lista de campos requeridos - sin passportPhotoUrl
        const requiredFields = ["firstName", "lastName", "email", "birthDate", "address", "city", "postalCode", "country"];
        console.log("Verificando campos requeridos:", requiredFields);
        console.log("Datos del usuario disponibles:", Object.keys(user));
        const missingFields = requiredFields.filter((field) => !user[field]);
        if (missingFields.length > 0) {
            console.error(`Faltan campos obligatorios: ${missingFields.join(", ")}`);
            throw new Error(`Faltan campos obligatorios: ${missingFields.join(", ")}`);
        }
        // Verificar formato de la fecha de nacimiento (dd/mm/yyyy)
        if (!/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(user.birthDate)) {
            console.error("Formato de fecha de nacimiento inválido");
            throw new Error("Formato de fecha de nacimiento inválido");
        }
        // Verificar mayoría de edad (18 años)
        const parts = user.birthDate.split("/");
        const birthDate = new Date(Number.parseInt(parts[2]), Number.parseInt(parts[1]) - 1, Number.parseInt(parts[0]));
        const today = new Date();
        const age = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        if (age < 18 || (age === 18 && monthDiff < 0)) {
            console.error("El usuario debe ser mayor de 18 años");
            throw new Error("El usuario debe ser mayor de 18 años");
        }
        // Verificar que el país sea un código ISO válido
        if (user.country && user.country.length !== 2) {
            console.error(`Código de país inválido: ${user.country}. Debe ser un código ISO de 2 letras.`);
            throw new Error(`Código de país inválido: ${user.country}. Debe ser un código ISO de 2 letras.`);
        }
        console.log("Verificación de datos completada con éxito");
    }
    /**
     * Crea una cuenta Stripe con los datos del usuario
     */
    async createStripeAccount(user) {
        console.log("Creando cuenta Stripe para usuario:", user.id);
        const dobParts = user.birthDate.split("/");
        // Añadir las capacidades necesarias para transferencias y pagos
        const stripeAccount = await this.stripeAccountService.createExpressAccountWithFullInfo({
            email: user.email,
            country: user.country || "ES",
            metadata: { firebaseUserId: user.id },
            business_type: "individual",
            capabilities: {
                transfers: { requested: true },
                card_payments: { requested: true },
                sepa_debit_payments: { requested: true },
            },
            individual: {
                first_name: user.firstName,
                last_name: user.lastName,
                email: user.email,
                address: {
                    line1: user.address,
                    city: user.city,
                    postal_code: user.postalCode,
                    country: user.country || "ES", // Usar ES (España) como valor predeterminado
                },
                dob: {
                    day: Number.parseInt(dobParts[0], 10),
                    month: Number.parseInt(dobParts[1], 10),
                    year: Number.parseInt(dobParts[2], 10),
                },
            },
        });
        console.log("Cuenta Stripe creada con ID:", stripeAccount.id);
        // Añadir cuenta bancaria si existe IBAN
        if (user.iban) {
            try {
                console.log("Añadiendo cuenta bancaria con IBAN:", user.iban);
                await this.stripeAccountService.addExternalBankAccount(stripeAccount.id, {
                    external_account: {
                        object: "bank_account",
                        account_holder_name: `${user.firstName} ${user.lastName}`,
                        account_holder_type: "individual",
                        country: user.country || "ES",
                        currency: "eur",
                        iban: user.iban,
                    },
                });
                console.log("Cuenta bancaria añadida correctamente");
            }
            catch (bankError) {
                // Si falla la adición de la cuenta bancaria, registramos el error pero continuamos
                console.error("Error al añadir cuenta bancaria:", bankError);
                console.log("Continuando con el proceso de KYC sin cuenta bancaria");
            }
        }
        return stripeAccount;
    }
    /**
     * Crea una wallet para el usuario si no existe
     */
    async createUserWallet(userId) {
        console.log("Verificando/creando wallet para usuario:", userId);
        const db = firebase_1.admin.firestore();
        const walletRef = db.collection("wallets").doc(userId);
        const walletDoc = await walletRef.get();
        if (!walletDoc.exists) {
            console.log("Wallet no existe, creando nueva");
            await walletRef.set({
                userId,
                balance: 0,
                transactions: [],
                kycCompleted: true,
                createdAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log("Wallet creada correctamente");
        }
        else {
            console.log("Wallet ya existe, actualizando");
            await walletRef.update({
                kycCompleted: true,
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log("Wallet actualizada correctamente");
        }
    }
}
exports.SimpleKYCService = SimpleKYCService;
//# sourceMappingURL=SimpleKYCService.js.map