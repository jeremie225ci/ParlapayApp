import type { Request, Response } from "express"
import crypto from "crypto"
import { admin } from "../config/firebase"
import { UserRepository } from "../repositories/UserRepository"
import { WalletRepository } from "../repositories/WalletRepository"
import { KYCService } from "./kyc-service"
import { generateRapydSignature } from "../rapyd-auth"

export class RapydWebhookService {
  private userRepository: UserRepository
  private walletRepository: WalletRepository
  private kycService: KYCService

  constructor() {
    this.userRepository = new UserRepository()
    this.walletRepository = new WalletRepository()
    this.kycService = new KYCService()
  }

  /**
   * Procesa los webhooks de Rapyd
   */
  async handleWebhook(req: Request, res: Response): Promise<void> {
    try {
      // Verificar firma del webhook
      const signature = req.headers["signature"] as string
      const salt = req.headers["salt"] as string
      const timestamp = req.headers["timestamp"] as string
      const url = req.originalUrl || req.url // Obtener la URL completa del webhook

      if (!signature || !salt || !timestamp || !this.verifySignature(req.body, signature, salt, timestamp, url)) {
        console.error("Firma de webhook inválida")
        res.status(401).json({ error: "Firma inválida" })
        return
      }

      const event = req.body
      console.log(`Webhook recibido: ${event.type}`, {
        id: event.id,
        data: event.data,
      })

      // Procesar según el tipo de evento
      switch (event.type) {
        // Eventos de KYC
        case "IDVERIFICATION_RESPONSE_RECEIVED":
          await this.handleIdentityVerificationCompleted(event.data)
          break

        // Eventos de Wallet
        case "WALLET_CREATED":
          await this.handleWalletCreated(event.data)
          break

        // Eventos de Pagos
        case "PAYMENT_COMPLETED":
          await this.handlePaymentCompleted(event.data)
          break

        case "PAYMENT_FAILED":
          await this.handlePaymentFailed(event.data)
          break

        // Eventos de Retiros
        case "PAYOUT_COMPLETED":
          await this.handlePayoutCompleted(event.data)
          break

        case "PAYOUT_FAILED":
          await this.handlePayoutFailed(event.data)
          break

        // Otros eventos...
        default:
          console.log(`Evento no manejado: ${event.type}`)
      }

      res.json({ received: true })
    } catch (error) {
      console.error("Error procesando webhook:", error)
      res.status(500).json({ error: (error as Error).message })
    }
  }

  /**
   * Verifica la firma del webhook
   */
// En rapyd_webhook_service.ts, modifica el método verifySignature así:
private verifySignature(payload: any, signature: string, salt: string, timestamp: string, url: string): boolean {
  try {
    // Obtener las claves de acceso y secreto directamente de las variables de entorno
    const accessKey = process.env.RAPYD_ACCESS_KEY || '';
    const secretKey = process.env.RAPYD_SECRET_KEY || '';

    if (!accessKey || !secretKey) {
      console.error("Claves de API no disponibles para verificar firma")
      return false
    }

    // Usar el método original de verificación para evitar dependencias nuevas
    const payloadString = JSON.stringify(payload)
    const toSign = `${url}${salt}${timestamp}${accessKey}${secretKey}${payloadString}`
    const calculatedSignature = crypto.createHmac("sha256", secretKey).update(toSign).digest("base64")

    return calculatedSignature === signature
  } catch (error) {
    console.error("Error verificando firma:", error)
    return false
  }
}

  /**
   * Maneja evento de verificación de identidad completada
   */
  private async handleIdentityVerificationCompleted(data: any): Promise<void> {
    try {
      // Usar el servicio KYC para manejar la verificación
      await this.kycService.handleIdentityVerificationCompleted(data.id, data.status)
    } catch (error) {
      console.error("Error procesando IDVERIFICATION_RESPONSE_RECEIVED:", error)
      throw error
    }
  }

  /**
   * Maneja evento de wallet creado
   */
  private async handleWalletCreated(data: any): Promise<void> {
    try {
      console.log(`Wallet creado: ${data.id}`)

      // Buscar usuario por ewallet_reference_id
      const referenceId = data.ewallet_reference_id
      if (!referenceId) {
        console.warn("Wallet creado sin ewallet_reference_id")
        return
      }

      const snapshot = await admin.firestore().collection("users").doc(referenceId).get()

      if (!snapshot.exists) {
        console.warn(`No se encontró usuario con ID ${referenceId}`)
        return
      }

      const userId = snapshot.id

      // Actualizar usuario en Firebase con el ID del wallet
      await this.userRepository.updateUser(userId, {
        rapydWalletId: data.id,
        walletStatus: "active",
        walletCreatedAt: new Date(),
      })

      console.log(`Usuario ${userId} actualizado con wallet ${data.id}`)

      // Actualizar o crear wallet en Firestore
      const walletDoc = await admin.firestore().collection("wallets").doc(userId).get()

      if (walletDoc.exists) {
        await this.walletRepository.updateWallet(userId, {
          rapydWalletId: data.id,
          accountStatus: "active",
        })
      } else {
        await this.walletRepository.createWallet(userId, data.id)
      }

      console.log(`Wallet en Firestore actualizado para usuario ${userId}`)

      // Enviar notificación al usuario
      await this.sendNotification(userId, {
        title: "Wallet Activado",
        body: "Tu wallet ha sido creado y está listo para usar.",
      })
    } catch (error) {
      console.error("Error procesando WALLET_CREATED:", error)
      throw error
    }
  }

  /**
   * Maneja evento de pago completado
   */
  private async handlePaymentCompleted(data: any): Promise<void> {
    try {
      // Implementar lógica para manejar pagos completados
      console.log(`Pago completado: ${data.id}`)
    } catch (error) {
      console.error("Error procesando PAYMENT_COMPLETED:", error)
      throw error
    }
  }

  /**
   * Maneja evento de pago fallido
   */
  private async handlePaymentFailed(data: any): Promise<void> {
    try {
      // Implementar lógica para manejar pagos fallidos
      console.log(`Pago fallido: ${data.id}`)
    } catch (error) {
      console.error("Error procesando PAYMENT_FAILED:", error)
      throw error
    }
  }

  /**
   * Maneja evento de retiro completado
   */
  private async handlePayoutCompleted(data: any): Promise<void> {
    try {
      // Implementar lógica para manejar retiros completados
      console.log(`Retiro completado: ${data.id}`)
    } catch (error) {
      console.error("Error procesando PAYOUT_COMPLETED:", error)
      throw error
    }
  }

  /**
   * Maneja evento de retiro fallido
   */
  private async handlePayoutFailed(data: any): Promise<void> {
    try {
      // Implementar lógica para manejar retiros fallidos
      console.log(`Retiro fallido: ${data.id}`)
    } catch (error) {
      console.error("Error procesando PAYOUT_FAILED:", error)
      throw error
    }
  }

  /**
   * Envía una notificación push al usuario
   */
  private async sendNotification(userId: string, notification: { title: string; body: string }): Promise<void> {
    try {
      // Obtener tokens de FCM del usuario
      const userDoc = await admin.firestore().collection("users").doc(userId).get()
      const fcmTokens = userDoc.data()?.fcmTokens || []

      if (fcmTokens.length === 0) {
        console.log(`No hay tokens FCM para el usuario ${userId}`)
        return
      }

      // Enviar notificación
      if (fcmTokens.length > 0) {
        const message = {
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            type: "wallet_update",
          },
          tokens: fcmTokens,
        }

        await admin.messaging().sendEachForMulticast(message)
        console.log(`Notificación enviada a ${userId}`)
      }
    } catch (error) {
      console.error("Error enviando notificación:", error)
      // No lanzar error para no interrumpir el flujo principal
    }
  }
}