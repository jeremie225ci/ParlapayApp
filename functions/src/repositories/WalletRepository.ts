import { admin } from "../config/firebase"
import type { WalletModel, TransactionModel, PartialWalletModel } from "../models/rapyd_models"
import type * as FirebaseFirestore from "@google-cloud/firestore"

export class WalletRepository {
  private db: FirebaseFirestore.Firestore
  private walletsCollection: string

  constructor() {
    this.db = admin.firestore()
    this.walletsCollection = "wallets"
  }

  /**
   * Obtiene el wallet de un usuario
   */
  async getWallet(userId: string): Promise<WalletModel | null> {
    try {
      const walletDoc = await this.db.collection(this.walletsCollection).doc(userId).get()

      if (!walletDoc.exists) {
        return null
      }

      const wallet = walletDoc.data() as Omit<WalletModel, "id">
      return {
        id: walletDoc.id,
        ...wallet,
      }
    } catch (error) {
      console.error("Error obteniendo wallet:", error)
      throw error
    }
  }

  /**
   * Crea un nuevo wallet
   */
  async createWallet(userId: string, rapydWalletId: string): Promise<void> {
    try {
      await this.db.collection(this.walletsCollection).doc(userId).set({
        userId,
        rapydWalletId,
        balance: 0,
        currency: "EUR",
        accountStatus: "active",
        transactions: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      })
    } catch (error) {
      console.error("Error creando wallet:", error)
      throw error
    }
  }

  /**
   * Actualiza un wallet existente
   */
  async updateWallet(userId: string, walletData: PartialWalletModel): Promise<void> {
    try {
      await this.db
        .collection(this.walletsCollection)
        .doc(userId)
        .update({
          ...walletData,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
    } catch (error) {
      console.error("Error actualizando wallet:", error)
      throw error
    }
  }

  /**
   * Actualiza el saldo de un wallet
   */
  async updateBalance(userId: string, amount: number): Promise<void> {
    try {
      await this.db
        .collection(this.walletsCollection)
        .doc(userId)
        .update({
          balance: admin.firestore.FieldValue.increment(amount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
    } catch (error) {
      console.error("Error actualizando saldo:", error)
      throw error
    }
  }

  /**
   * Añade una transacción al wallet
   */
  async addTransaction(userId: string, transaction: TransactionModel): Promise<void> {
    try {
      await this.db
        .collection(this.walletsCollection)
        .doc(userId)
        .update({
          transactions: admin.firestore.FieldValue.arrayUnion(transaction),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
    } catch (error) {
      console.error("Error añadiendo transacción:", error)
      throw error
    }
  }

  /**
   * Obtiene las transacciones de un wallet
   */
  async getTransactions(userId: string, limit = 20): Promise<TransactionModel[]> {
    try {
      const walletDoc = await this.db.collection(this.walletsCollection).doc(userId).get()

      if (!walletDoc.exists) {
        return []
      }

      const wallet = walletDoc.data() as WalletModel

      // Asegurarse de que transactions existe y es un array
      const transactions = wallet.transactions || []

      // Ordenar transacciones por timestamp descendente y limitar
      return [...transactions]
        .sort((a, b) => {
          const aTime = a.timestamp instanceof Date ? a.timestamp.getTime() : a.timestamp
          const bTime = b.timestamp instanceof Date ? b.timestamp.getTime() : b.timestamp
          return bTime - aTime
        })
        .slice(0, limit)
    } catch (error) {
      console.error("Error obteniendo transacciones:", error)
      throw error
    }
  }

  /**
   * Observa cambios en un wallet
   */
  watchWallet(userId: string, callback: (snapshot: FirebaseFirestore.DocumentSnapshot) => void): () => void {
    return this.db
      .collection(this.walletsCollection)
      .doc(userId)
      .onSnapshot(
        (snapshot) => {
          callback(snapshot)
        },
        (error) => {
          console.error("Error observando wallet:", error)
        },
      )
  }
}
