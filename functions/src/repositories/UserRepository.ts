import { admin } from "../config/firebase"
import type { UserWithRapyd, PartialUserWithRapyd } from "../models/rapyd_models"
import type * as FirebaseFirestore from "@google-cloud/firestore"

export class UserRepository {
  private db: FirebaseFirestore.Firestore
  private usersCollection: string

  constructor() {
    this.db = admin.firestore()
    this.usersCollection = "users"
  }

  /**
   * Obtiene un usuario por su ID
   */
  async getUserById(userId: string): Promise<UserWithRapyd | null> {
    try {
      const userDoc = await this.db.collection(this.usersCollection).doc(userId).get()

      if (!userDoc.exists) {
        return null
      }

      const userData = userDoc.data() as Omit<UserWithRapyd, "id">
      return {
        id: userDoc.id,
        ...userData,
      }
    } catch (error) {
      console.error("Error obteniendo usuario:", error)
      throw error
    }
  }

  /**
   * Crea un nuevo usuario
   */
  async createUser(userId: string, userData: PartialUserWithRapyd): Promise<void> {
    try {
      await this.db
        .collection(this.usersCollection)
        .doc(userId)
        .set({
          ...userData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
    } catch (error) {
      console.error("Error creando usuario:", error)
      throw error
    }
  }

  /**
   * Actualiza un usuario existente
   */
  async updateUser(userId: string, userData: PartialUserWithRapyd): Promise<void> {
    try {
      await this.db
        .collection(this.usersCollection)
        .doc(userId)
        .update({
          ...userData,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
    } catch (error) {
      console.error("Error actualizando usuario:", error)
      throw error
    }
  }

  /**
   * Busca usuarios por email o teléfono
   */
  async searchUsers(query: string, limit = 5): Promise<UserWithRapyd[]> {
    try {
      // Buscar por email
      const emailSnapshot = await this.db
        .collection(this.usersCollection)
        .where("email", "==", query)
        .limit(limit)
        .get()

      // Buscar por teléfono
      const phoneSnapshot = await this.db
        .collection(this.usersCollection)
        .where("phoneNumber", "==", query)
        .limit(limit)
        .get()

      // Combinar resultados
      const results: UserWithRapyd[] = []
      const processedIds = new Set<string>()

      emailSnapshot.forEach((doc) => {
        const userData = doc.data() as Omit<UserWithRapyd, "id">
        results.push({
          id: doc.id,
          ...userData,
        })
        processedIds.add(doc.id)
      })

      phoneSnapshot.forEach((doc) => {
        // Evitar duplicados
        if (!processedIds.has(doc.id)) {
          const userData = doc.data() as Omit<UserWithRapyd, "id">
          results.push({
            id: doc.id,
            ...userData,
          })
        }
      })

      return results
    } catch (error) {
      console.error("Error buscando usuarios:", error)
      throw error
    }
  }

  // Añadir el método getAllWithRapydWallet que falta
  async getAllWithRapydWallet(): Promise<UserWithRapyd[]> {
    try {
      const snapshot = await this.db.collection(this.usersCollection).where("rapydWalletId", "!=", null).get()

      const users: UserWithRapyd[] = []

      snapshot.forEach((doc) => {
        const userData = doc.data() as Omit<UserWithRapyd, "id">
        users.push({
          id: doc.id,
          ...userData,
        })
      })

      return users
    } catch (error) {
      console.error("Error obteniendo usuarios con wallet:", error)
      throw error
    }
  }
}
