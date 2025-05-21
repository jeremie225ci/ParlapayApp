"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserController = void 0;
const firebase_1 = require("../config/firebase");
class UserController {
    constructor(userRepository, stripeAccountService) {
        this.userRepository = userRepository;
        this.stripeAccountService = stripeAccountService;
    }
    /**
     * Obtiene los detalles de un usuario por ID
     */
    async getUserById(req, res) {
        try {
            const { userId } = req.params;
            if (!userId) {
                res.status(400).json({ error: 'userId es requerido' });
                return;
            }
            const user = await this.userRepository.getUserById(userId);
            if (!user) {
                res.status(404).json({ error: 'Usuario no encontrado' });
                return;
            }
            // Eliminamos información sensible antes de enviarla al cliente
            const sanitizedUser = {
                id: userId,
                email: user.email,
                displayName: user.displayName,
                phoneNumber: user.phoneNumber,
                kycCompleted: user.kycCompleted,
                connectAccountId: user.connectAccountId,
                createdAt: user.createdAt,
            };
            res.json(sanitizedUser);
        }
        catch (error) {
            console.error('Error al obtener usuario:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Crea o actualiza un usuario
     */
    async createOrUpdateUser(req, res) {
        try {
            const { userId, userData } = req.body;
            if (!userId || !userData) {
                res.status(400).json({ error: 'userId y userData son requeridos' });
                return;
            }
            // Verificar si el usuario ya existe
            const existingUser = await this.userRepository.getUserById(userId);
            if (existingUser) {
                // Actualizar usuario existente
                await this.userRepository.updateUser(userId, userData);
                res.json({ success: true, message: 'Usuario actualizado correctamente' });
            }
            else {
                // Crear nuevo usuario
                await this.userRepository.createUser(userId, userData);
                res.json({ success: true, message: 'Usuario creado correctamente' });
            }
        }
        catch (error) {
            console.error('Error al crear/actualizar usuario:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Actualiza la información bancaria de un usuario (IBAN)
     */
    async updateBankInfo(req, res) {
        try {
            const { userId, iban, accountHolder } = req.body;
            if (!userId || !iban || !accountHolder) {
                res.status(400).json({ error: 'userId, iban y accountHolder son requeridos' });
                return;
            }
            // Validar IBAN (formato básico)
            if (!this.validateIBAN(iban)) {
                res.status(400).json({ error: 'Formato de IBAN inválido' });
                return;
            }
            await this.userRepository.updateIban(userId, iban, accountHolder);
            res.json({ success: true, message: 'Información bancaria actualizada correctamente' });
        }
        catch (error) {
            console.error('Error al actualizar información bancaria:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Verifica el estado KYC de un usuario en Stripe
     */
    async checkKycStatus(req, res) {
        try {
            const { userId } = req.params;
            if (!userId) {
                res.status(400).json({ error: 'userId es requerido' });
                return;
            }
            const user = await this.userRepository.getUserById(userId);
            if (!user || !user.connectAccountId) {
                res.status(404).json({
                    error: 'Usuario no encontrado o sin cuenta Stripe Connect',
                    kycCompleted: false
                });
                return;
            }
            // Obtener detalles de la cuenta de Stripe
            const account = await this.stripeAccountService.retrieveAccount(user.connectAccountId);
            // Determinar si KYC está completo
            const kycCompleted = Boolean(account.charges_enabled && account.payouts_enabled);
            // Actualizar el estado KYC en la base de datos si ha cambiado
            if (user.kycCompleted !== kycCompleted) {
                await this.userRepository.updateKycStatus(userId, kycCompleted);
            }
            res.json({
                kycCompleted,
                chargesEnabled: account.charges_enabled,
                payoutsEnabled: account.payouts_enabled,
                requirementsDisabled: account.requirements?.disabled_reason,
                requirementsPending: account.requirements?.pending_verification?.length ?
                    account.requirements.pending_verification : [],
                requirementsCurrentlyDue: account.requirements?.currently_due?.length ?
                    account.requirements.currently_due : []
            });
        }
        catch (error) {
            console.error('Error al verificar estado KYC:', error);
            res.status(500).json({ error: error.message });
        }
    }
    /**
     * Busca usuarios por correo electrónico o número de teléfono
     * para facilitar pagos P2P
     */
    async searchUsers(req, res) {
        try {
            const { query } = req.query;
            const { currentUserId } = req.body;
            if (!query || typeof query !== 'string') {
                res.status(400).json({ error: 'Término de búsqueda requerido' });
                return;
            }
            const db = firebase_1.admin.firestore();
            const usersRef = db.collection('users');
            // Buscar por email
            const emailSnap = await usersRef
                .where('email', '==', query)
                .limit(5)
                .get();
            // Buscar por teléfono
            const phoneSnap = await usersRef
                .where('phoneNumber', '==', query)
                .limit(5)
                .get();
            // Combinar resultados
            const results = [];
            // Añadir resultados por email
            emailSnap.forEach(doc => {
                // No incluir el usuario actual en los resultados
                if (doc.id !== currentUserId) {
                    results.push({
                        id: doc.id,
                        email: doc.data().email,
                        displayName: doc.data().displayName,
                        phoneNumber: doc.data().phoneNumber,
                    });
                }
            });
            // Añadir resultados por teléfono (si no están ya incluidos)
            phoneSnap.forEach(doc => {
                if (doc.id !== currentUserId && !results.some(r => r.id === doc.id)) {
                    results.push({
                        id: doc.id,
                        email: doc.data().email,
                        displayName: doc.data().displayName,
                        phoneNumber: doc.data().phoneNumber,
                    });
                }
            });
            res.json({ users: results });
        }
        catch (error) {
            console.error('Error al buscar usuarios:', error);
            res.status(500).json({ error: error.message });
        }
    }
    // Validación simple de IBAN
    validateIBAN(iban) {
        // Eliminar espacios y convertir a mayúsculas
        const cleanedIBAN = iban.replace(/\s/g, '').toUpperCase();
        // Validación básica: longitud y formato
        // Un IBAN completo tiene entre 15 y 34 caracteres
        if (cleanedIBAN.length < 15 || cleanedIBAN.length > 34) {
            return false;
        }
        // Comprobar que los dos primeros caracteres son letras (código de país)
        if (!/^[A-Z]{2}/.test(cleanedIBAN)) {
            return false;
        }
        // Comprobar que el resto son alfanuméricos
        if (!/^[A-Z]{2}[0-9A-Z]+$/.test(cleanedIBAN)) {
            return false;
        }
        // Nota: Para una validación completa de IBAN, se requeriría un algoritmo
        // más sofisticado que incluya la verificación del dígito de control
        return true;
    }
}
exports.UserController = UserController;
//# sourceMappingURL=UserContoller.js.map