"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.KYCService = void 0;
const firebase_1 = require("../config/firebase");
const rapyd_service_1 = require("./rapyd_service");
const UserRepository_1 = require("../repositories/UserRepository");
const WalletRepository_1 = require("../repositories/WalletRepository");
class KYCService {
    constructor() {
        this.rapydService = new rapyd_service_1.RapydService();
        this.userRepository = new UserRepository_1.UserRepository();
        this.walletRepository = new WalletRepository_1.WalletRepository();
    }
    /**
     * Procesa el KYC y crea un wallet en Rapyd
     */
    async processKYC(userId, userData) {
        try {
            console.log(`Procesando KYC para usuario ${userId}`);
            // Verificar si el usuario ya tiene un wallet
            const user = await this.userRepository.getUserById(userId);
            if (user && user.rapydWalletId) {
                console.log(`Usuario ${userId} ya tiene wallet Rapyd: ${user.rapydWalletId}`);
                return {
                    success: false,
                    error: "El usuario ya tiene un wallet Rapyd",
                    walletId: user.rapydWalletId,
                };
            }
            // Crear wallet en Rapyd
            console.log(`Creando wallet en Rapyd para usuario ${userId}`);
            // Preparar datos para Rapyd según la documentación
            const rapydUserData = {
                first_name: userData.firstName,
                last_name: userData.lastName,
                email: userData.email,
                phone_number: userData.phoneNumber || "",
                type: "person",
                ewallet_reference_id: userId, // ID de referencia único
            };
            // Llamar a la API de Rapyd para crear el wallet
            const wallet = await this.rapydService.createWallet(rapydUserData);
            console.log(`Wallet creado en Rapyd: ${wallet.id}`);
            // Actualizar usuario en Firebase con el ID del wallet
            const updateData = {
                rapydWalletId: wallet.id,
                firstName: userData.firstName,
                lastName: userData.lastName,
                email: userData.email,
                phoneNumber: userData.phoneNumber || "",
                kycStatus: "approved",
                kycCompleted: true,
                rapydCreatedAt: new Date(),
            };
            // Añadir campos adicionales si existen
            if (userData.birthDate)
                updateData.birthDate = userData.birthDate;
            if (userData.address)
                updateData.address = userData.address;
            if (userData.city)
                updateData.city = userData.city;
            if (userData.postalCode)
                updateData.postalCode = userData.postalCode;
            if (userData.country)
                updateData.country = userData.country;
            await this.userRepository.updateUser(userId, updateData);
            console.log(`Usuario ${userId} actualizado con wallet ${wallet.id}`);
            // Crear wallet en Firestore
            await this.walletRepository.createWallet(userId, wallet.id);
            console.log(`Wallet creado en Firestore para usuario ${userId}`);
            return {
                success: true,
                walletId: wallet.id,
            };
        }
        catch (error) {
            console.error(`Error procesando KYC para usuario ${userId}:`, error);
            return {
                success: false,
                error: error instanceof Error ? error.message : "Error desconocido",
            };
        }
    }
    /**
     * Maneja el evento de verificación de identidad completada
     */
    async handleIdentityVerificationCompleted(identityId, status) {
        try {
            console.log(`Procesando verificación de identidad ${identityId} con estado ${status}`);
            // Buscar usuario con este ID de verificación
            const snapshot = await firebase_1.admin
                .firestore()
                .collection("users")
                .where("rapydIdentityId", "==", identityId)
                .limit(1)
                .get();
            if (snapshot.empty) {
                console.warn(`No se encontró usuario con identityId ${identityId}`);
                return;
            }
            const userId = snapshot.docs[0].id;
            const userData = snapshot.docs[0].data();
            const kycStatus = status === "KYC_APPROVED" ? "approved" : "rejected";
            console.log(`Usuario ${userId} encontrado, estado KYC: ${kycStatus}`);
            // Actualizar estado KYC
            const updateData = {
                kycStatus,
                kycCompleted: kycStatus === "approved",
                kycUpdatedAt: new Date(),
            };
            if (kycStatus === "rejected") {
                updateData.kycRejectionReason = "Verificación rechazada";
            }
            else {
                updateData.kycRejectionReason = null;
            }
            await this.userRepository.updateUser(userId, updateData);
            // Si la verificación fue aprobada y el usuario no tiene wallet, crear uno
            if (kycStatus === "approved" && !userData.rapydWalletId) {
                console.log(`Creando wallet para usuario ${userId} después de KYC aprobado`);
                // Obtener datos completos del usuario
                const user = await this.userRepository.getUserById(userId);
                if (user && user.firstName && user.lastName && user.email) {
                    const result = await this.processKYC(userId, {
                        firstName: user.firstName,
                        lastName: user.lastName,
                        email: user.email,
                        phoneNumber: user.phoneNumber,
                        birthDate: user.birthDate,
                        address: user.address,
                        city: user.city,
                        postalCode: user.postalCode,
                        country: user.country,
                    });
                    if (result.success) {
                        console.log(`Wallet creado automáticamente después de KYC: ${result.walletId}`);
                    }
                    else {
                        console.error(`Error creando wallet después de KYC: ${result.error}`);
                    }
                }
                else {
                    console.error(`Datos insuficientes para crear wallet para usuario ${userId}`);
                }
            }
            // Enviar notificación al usuario
            await this.sendNotification(userId, {
                title: kycStatus === "approved" ? "Verificación Aprobada" : "Verificación Rechazada",
                body: kycStatus === "approved"
                    ? "Tu identidad ha sido verificada correctamente. Ya puedes usar todas las funciones de la app."
                    : "Tu verificación de identidad ha sido rechazada. Por favor, revisa los detalles en la app.",
            });
        }
        catch (error) {
            console.error("Error procesando verificación de identidad:", error);
            throw error;
        }
    }
    /**
     * Envía una notificación push al usuario
     */
    async sendNotification(userId, notification) {
        try {
            // Obtener tokens de FCM del usuario
            const userDoc = await firebase_1.admin.firestore().collection("users").doc(userId).get();
            const fcmTokens = userDoc.data()?.fcmTokens || [];
            if (fcmTokens.length === 0) {
                console.log(`No hay tokens FCM para el usuario ${userId}`);
                return;
            }
            // Enviar notificación
            if (fcmTokens.length > 0) {
                const message = {
                    notification: {
                        title: notification.title,
                        body: notification.body,
                    },
                    data: {
                        type: "kyc_update",
                    },
                    tokens: fcmTokens,
                };
                await firebase_1.admin.messaging().sendEachForMulticast(message);
                console.log(`Notificación enviada a ${userId}`);
            }
        }
        catch (error) {
            console.error("Error enviando notificación:", error);
            // No lanzar error para no interrumpir el flujo principal
        }
    }
}
exports.KYCService = KYCService;
//# sourceMappingURL=kyc-service.js.map