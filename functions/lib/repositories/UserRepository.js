"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserRepository = void 0;
const firebase_1 = require("../config/firebase");
class UserRepository {
    constructor() {
        this.db = firebase_1.admin.firestore();
        this.usersCollection = "users";
    }
    /**
     * Obtiene un usuario por su ID
     */
    async getUserById(userId) {
        try {
            const userDoc = await this.db.collection(this.usersCollection).doc(userId).get();
            if (!userDoc.exists) {
                return null;
            }
            const userData = userDoc.data();
            return {
                id: userDoc.id,
                ...userData,
            };
        }
        catch (error) {
            console.error("Error obteniendo usuario:", error);
            throw error;
        }
    }
    /**
     * Crea un nuevo usuario
     */
    async createUser(userId, userData) {
        try {
            await this.db
                .collection(this.usersCollection)
                .doc(userId)
                .set({
                ...userData,
                createdAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error("Error creando usuario:", error);
            throw error;
        }
    }
    /**
     * Actualiza un usuario existente
     */
    async updateUser(userId, userData) {
        try {
            await this.db
                .collection(this.usersCollection)
                .doc(userId)
                .update({
                ...userData,
                updatedAt: firebase_1.admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
            console.error("Error actualizando usuario:", error);
            throw error;
        }
    }
    /**
     * Busca usuarios por email o teléfono
     */
    async searchUsers(query, limit = 5) {
        try {
            // Buscar por email
            const emailSnapshot = await this.db
                .collection(this.usersCollection)
                .where("email", "==", query)
                .limit(limit)
                .get();
            // Buscar por teléfono
            const phoneSnapshot = await this.db
                .collection(this.usersCollection)
                .where("phoneNumber", "==", query)
                .limit(limit)
                .get();
            // Combinar resultados
            const results = [];
            const processedIds = new Set();
            emailSnapshot.forEach((doc) => {
                const userData = doc.data();
                results.push({
                    id: doc.id,
                    ...userData,
                });
                processedIds.add(doc.id);
            });
            phoneSnapshot.forEach((doc) => {
                // Evitar duplicados
                if (!processedIds.has(doc.id)) {
                    const userData = doc.data();
                    results.push({
                        id: doc.id,
                        ...userData,
                    });
                }
            });
            return results;
        }
        catch (error) {
            console.error("Error buscando usuarios:", error);
            throw error;
        }
    }
    // Añadir el método getAllWithRapydWallet que falta
    async getAllWithRapydWallet() {
        try {
            const snapshot = await this.db.collection(this.usersCollection).where("rapydWalletId", "!=", null).get();
            const users = [];
            snapshot.forEach((doc) => {
                const userData = doc.data();
                users.push({
                    id: doc.id,
                    ...userData,
                });
            });
            return users;
        }
        catch (error) {
            console.error("Error obteniendo usuarios con wallet:", error);
            throw error;
        }
    }
}
exports.UserRepository = UserRepository;
//# sourceMappingURL=UserRepository.js.map