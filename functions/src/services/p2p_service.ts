import { admin } from "../config/firebase"
import { RapydService } from "./rapyd_service"
import { UserRepository } from "../repositories/UserRepository"
import { WalletRepository } from "../repositories/WalletRepository"

export class P2PService {
  private rapydService: RapydService
  private userRepository: UserRepository
  private walletRepository: WalletRepository

  constructor() {
    this.rapydService = new RapydService()
    this.userRepository = new UserRepository()
    this.walletRepository = new WalletRepository()
  }

  /**
   * Realiza una transferencia P2P entre usuarios
   */
  async sendP2P(senderId: string, receiverId: string, amount: number, currency = "EUR"): Promise<string> {
    try {
      // Verificar que ambos usuarios existen
      const [sender, receiver] = await Promise.all([
        this.userRepository.getUserById(senderId),
        this.userRepository.getUserById(receiverId),
      ])

      if (!sender) {
        throw new Error(`Remitente ${senderId} no encontrado`)
      }

      if (!receiver) {
        throw new Error(`Destinatario ${receiverId} no encontrado`)
      }

      // Verificar que ambos tienen wallet Rapyd
      if (!sender.rapydWalletId) {
        throw new Error(`Remitente ${senderId} no tiene wallet Rapyd`)
      }

      if (!receiver.rapydWalletId) {
        throw new Error(`Destinatario ${receiverId} no tiene wallet Rapyd`)
      }

      // Verificar saldo del remitente
      const senderWallet = await this.walletRepository.getWallet(senderId)
      if (!senderWallet || senderWallet.balance < amount) {
        throw new Error("Saldo insuficiente")
      }

      // Crear transferencia en Rapyd
      const transfer = await this.rapydService.transferFunds(
        sender.rapydWalletId,
        receiver.rapydWalletId,
        amount,
        currency,
      )

      // Actualizar saldos en Firestore
      const db = admin.firestore()
      const batch = db.batch()
      const timestamp = Date.now()

      // Actualizar saldo del remitente
      const senderWalletRef = db.collection("wallets").doc(senderId)
      batch.update(senderWalletRef, {
        balance: admin.firestore.FieldValue.increment(-amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactions: admin.firestore.FieldValue.arrayUnion({
          id: transfer.id,
          amount: -amount,
          type: "debit",
          description: "Transferencia enviada",
          receiverId,
          timestamp,
          rapydTransactionId: transfer.id,
          status: "completed",
        }),
      })

      // Actualizar o crear wallet del destinatario
      const receiverWalletRef = db.collection("wallets").doc(receiverId)
      const receiverWalletDoc = await receiverWalletRef.get()

      if (receiverWalletDoc.exists) {
        batch.update(receiverWalletRef, {
          balance: admin.firestore.FieldValue.increment(amount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactions: admin.firestore.FieldValue.arrayUnion({
            id: transfer.id,
            amount,
            type: "credit",
            description: "Transferencia recibida",
            senderId,
            timestamp,
            rapydTransactionId: transfer.id,
            status: "completed",
          }),
        })
      } else {
        batch.set(receiverWalletRef, {
          userId: receiverId,
          rapydWalletId: receiver.rapydWalletId,
          balance: amount,
          transactions: [
            {
              id: transfer.id,
              amount,
              type: "credit",
              description: "Transferencia recibida",
              senderId,
              timestamp,
              rapydTransactionId: transfer.id,
              status: "completed",
            },
          ],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
      }

      // Ejecutar batch
      await batch.commit()

      return transfer.id
    } catch (error) {
      console.error("Error en transferencia P2P:", error)
      throw error
    }
  }
}
