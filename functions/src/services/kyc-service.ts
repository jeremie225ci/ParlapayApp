import { admin } from "../config/firebase"
import { RapydService } from "./rapyd_service"
import { UserRepository } from "../repositories/UserRepository"
import { WalletRepository } from "../repositories/WalletRepository"
import type { UserWithRapyd, RapydUserData, PartialUserWithRapyd } from "../models/rapyd_models"

export class KYCService {
  private rapydService: RapydService
  private userRepository: UserRepository
  private walletRepository: WalletRepository

  constructor() {
    this.rapydService = new RapydService()
    this.userRepository = new UserRepository()
    this.walletRepository = new WalletRepository()
  }

  /**
   * Procesa el KYC y crea un wallet en Rapyd
   */
  async processKYC(
    userId: string,
    userData: {
      firstName: string
      lastName: string
      email: string
      phoneNumber?: string
      birthDate?: string
      address?: string
      city?: string
      postalCode?: string
      country?: string
      identificationType?: string
      identificationNumber?: string
    },
  ): Promise<{ success: boolean; walletId?: string; error?: string }> {
    try {
      console.log(`Procesando KYC para usuario ${userId}`)

      // Verificar si el usuario ya tiene un wallet
      const user = await this.userRepository.getUserById(userId)
      if (user && user.rapydWalletId) {
        console.log(`Usuario ${userId} ya tiene wallet Rapyd: ${user.rapydWalletId}`)
        return {
          success: false,
          error: "El usuario ya tiene un wallet Rapyd",
          walletId: user.rapydWalletId,
        }
      }

      // Crear wallet en Rapyd
      console.log(`Creando wallet en Rapyd para usuario ${userId}`)

      // Preparar datos para Rapyd según la documentación
      const rapydUserData: RapydUserData = {
        first_name: userData.firstName,
        last_name: userData.lastName,
        email: userData.email,
        phone_number: userData.phoneNumber || "",
        type: "person", // Tipo de wallet: person
        ewallet_reference_id: userId, // ID de referencia único
      }

      // Llamar a la API de Rapyd para crear el wallet
      const wallet = await this.rapydService.createWallet(rapydUserData)
      console.log(`Wallet creado en Rapyd: ${wallet.id}`)

      // Actualizar usuario en Firebase con el ID del wallet
      const updateData: PartialUserWithRapyd = {
        rapydWalletId: wallet.id,
        firstName: userData.firstName,
        lastName: userData.lastName,
        email: userData.email,
        phoneNumber: userData.phoneNumber || "",
        kycStatus: "approved",
        kycCompleted: true,
        rapydCreatedAt: new Date(),
      }

      // Añadir campos adicionales si existen
      if (userData.birthDate) updateData.birthDate = userData.birthDate
      if (userData.address) updateData.address = userData.address
      if (userData.city) updateData.city = userData.city
      if (userData.postalCode) updateData.postalCode = userData.postalCode
      if (userData.country) updateData.country = userData.country

      await this.userRepository.updateUser(userId, updateData)
      console.log(`Usuario ${userId} actualizado con wallet ${wallet.id}`)

      // Crear wallet en Firestore
      await this.walletRepository.createWallet(userId, wallet.id)
      console.log(`Wallet creado en Firestore para usuario ${userId}`)

      return {
        success: true,
        walletId: wallet.id,
      }
    } catch (error) {
      console.error(`Error procesando KYC para usuario ${userId}:`, error)
      return {
        success: false,
        error: error instanceof Error ? error.message : "Error desconocido",
      }
    }
  }

  /**
   * Maneja el evento de verificación de identidad completada
   */
  async handleIdentityVerificationCompleted(identityId: string, status: string): Promise<void> {
    try {
      console.log(`Procesando verificación de identidad ${identityId} con estado ${status}`)

      // Buscar usuario con este ID de verificación
      const snapshot = await admin
        .firestore()
        .collection("users")
        .where("rapydIdentityId", "==", identityId)
        .limit(1)
        .get()

      if (snapshot.empty) {
        console.warn(`No se encontró usuario con identityId ${identityId}`)
        return
      }

      const userId = snapshot.docs[0].id
      const userData = snapshot.docs[0].data() as UserWithRapyd
      const kycStatus = status === "KYC_APPROVED" ? "approved" : "rejected"

      console.log(`Usuario ${userId} encontrado, estado KYC: ${kycStatus}`)

      // Actualizar estado KYC
      const updateData: PartialUserWithRapyd = {
        kycStatus,
        kycCompleted: kycStatus === "approved",
        kycUpdatedAt: new Date(),
      }

      if (kycStatus === "rejected") {
        updateData.kycRejectionReason = "Verificación rechazada"
      } else {
        updateData.kycRejectionReason = null
      }

      await this.userRepository.updateUser(userId, updateData)

      // Si la verificación fue aprobada y el usuario no tiene wallet, crear uno
      if (kycStatus === "approved" && !userData.rapydWalletId) {
        console.log(`Creando wallet para usuario ${userId} después de KYC aprobado`)

        // Obtener datos completos del usuario
        const user = await this.userRepository.getUserById(userId)

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
          })

          if (result.success) {
            console.log(`Wallet creado automáticamente después de KYC: ${result.walletId}`)
          } else {
            console.error(`Error creando wallet después de KYC: ${result.error}`)
          }
        } else {
          console.error(`Datos insuficientes para crear wallet para usuario ${userId}`)
        }
      }

      // Enviar notificación al usuario
      await this.sendNotification(userId, {
        title: kycStatus === "approved" ? "Verificación Aprobada" : "Verificación Rechazada",
        body:
          kycStatus === "approved"
            ? "Tu identidad ha sido verificada correctamente. Ya puedes usar todas las funciones de la app."
            : "Tu verificación de identidad ha sido rechazada. Por favor, revisa los detalles en la app.",
      })
    } catch (error) {
      console.error("Error procesando verificación de identidad:", error)
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
            type: "kyc_update",
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
