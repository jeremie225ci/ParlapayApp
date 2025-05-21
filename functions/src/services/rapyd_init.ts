import axios from "axios"
import { generateRapydHeaders } from "../rapyd-auth"

// Clase para encapsular la funcionalidad de Rapyd
class RapydService {
  private baseUrl: string
  private initialized = false

  constructor() {
    this.baseUrl = process.env.RAPYD_BASE_URL || "https://sandboxapi.rapyd.net"
    console.log("RapydService inicializado con URL:", this.baseUrl)
  }

  // Test connection method
  async testConnection(): Promise<boolean> {
    try {
      const path = "/v1/data/countries"
      const headers = generateRapydHeaders("get", path)

      console.log(`Testing connection to ${this.baseUrl}${path}`)
      const response = await axios.get(
        `${this.baseUrl}${path}`,
        { headers, timeout: 10000 }, // Add timeout to prevent hanging
      )

      this.initialized = response.data && response.data.status && response.data.status.status === "SUCCESS"

      return this.initialized
    } catch (error: any) {
      console.error("Error testing Rapyd connection:", error.response?.data || error.message)
      return false
    }
  }

  // Método para crear un wallet
  async createWallet(userData: any): Promise<any> {
    const path = "/v1/user"
    const headers = generateRapydHeaders("post", path, userData)

    try {
      console.log(`Enviando solicitud a ${this.baseUrl}${path}`)
      const response = await axios.post(`${this.baseUrl}${path}`, userData, { headers, timeout: 15000 })

      return response.data
    } catch (error: any) {
      console.error("Error creando wallet en Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para obtener información de un wallet
  async getWallet(walletId: string): Promise<any> {
    const path = `/v1/user/${walletId}`
    const headers = generateRapydHeaders("get", path)

    try {
      const response = await axios.get(`${this.baseUrl}${path}`, { headers, timeout: 10000 })
      return response.data
    } catch (error: any) {
      console.error("Error obteniendo wallet de Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para obtener el balance de un wallet
  async getWalletBalance(walletId: string): Promise<any> {
    const path = `/v1/user/${walletId}/accounts`
    const headers = generateRapydHeaders("get", path)

    try {
      const response = await axios.get(`${this.baseUrl}${path}`, { headers, timeout: 10000 })
      return response.data.data
    } catch (error: any) {
      console.error("Error obteniendo balance de Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para transferir fondos entre wallets
  async transferFunds(
    sourceWalletId: string,
    destinationWalletId: string,
    amount: number,
    currency = "EUR",
  ): Promise<any> {
    const path = "/v1/account/transfer"
    const body = {
      source_ewallet: sourceWalletId,
      destination_ewallet: destinationWalletId,
      amount,
      currency,
    }

    const headers = generateRapydHeaders("post", path, body)

    try {
      const response = await axios.post(`${this.baseUrl}${path}`, body, { headers, timeout: 15000 })
      return response.data
    } catch (error: any) {
      console.error("Error transfiriendo fondos en Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para añadir fondos a un wallet (checkout)
  async createCheckout(walletId: string, amount: number, currency = "EUR"): Promise<any> {
    const path = "/v1/checkout"
    const body = {
      amount,
      currency,
      ewallet: walletId,
      country: "ES",
      complete_payment_url: process.env.PAYMENT_SUCCESS_URL || "https://example.com/success",
      error_payment_url: process.env.PAYMENT_ERROR_URL || "https://example.com/error",
      complete_checkout_url: process.env.CHECKOUT_SUCCESS_URL || "https://example.com/success",
      cancel_checkout_url: process.env.CHECKOUT_CANCEL_URL || "https://example.com/cancel",
      language: "es",
    }

    const headers = generateRapydHeaders("post", path, body)

    try {
      const response = await axios.post(`${this.baseUrl}${path}`, body, { headers, timeout: 15000 })
      return response.data
    } catch (error: any) {
      console.error("Error creando checkout en Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para retirar fondos
  async withdrawFunds(walletId: string, amount: number, currency = "EUR", beneficiaryId: string): Promise<any> {
    const path = "/v1/payouts"
    const body = {
      ewallet: walletId,
      payout_amount: amount,
      payout_currency: currency,
      beneficiary: beneficiaryId,
      payout_method_type: "eu_bank_transfer",
      sender: {
        name: "Wallet Withdrawal",
        email: "",
        phone_number: "",
      },
      description: "Withdrawal to bank account",
    }

    const headers = generateRapydHeaders("post", path, body)

    try {
      const response = await axios.post(`${this.baseUrl}${path}`, body, { headers, timeout: 15000 })
      return response.data
    } catch (error: any) {
      console.error("Error retirando fondos en Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para crear un beneficiario
  async createBeneficiary(walletId: string, bankDetails: any): Promise<any> {
    const path = "/v1/payouts/beneficiary"
    const body = {
      category: "bank",
      business_details: {},
      ...bankDetails,
      ewallet: walletId,
    }

    const headers = generateRapydHeaders("post", path, body)

    try {
      const response = await axios.post(`${this.baseUrl}${path}`, body, { headers, timeout: 15000 })
      return response.data
    } catch (error: any) {
      console.error("Error creando beneficiario en Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para verificar la identidad
  async verifyIdentity(walletId: string, verificationData: any): Promise<any> {
    const path = "/v1/identities"
    const body = {
      reference_id: walletId,
      ewallet: walletId,
      ...verificationData,
    }

    const headers = generateRapydHeaders("post", path, body)

    try {
      const response = await axios.post(`${this.baseUrl}${path}`, body, { headers, timeout: 15000 })
      return response.data
    } catch (error: any) {
      console.error("Error verificando identidad en Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  // Método para obtener el estado de verificación de identidad
  async getIdentityStatus(referenceId: string): Promise<any> {
    const path = `/v1/identities/${referenceId}`
    const headers = generateRapydHeaders("get", path)

    try {
      const response = await axios.get(`${this.baseUrl}${path}`, { headers, timeout: 10000 })
      return response.data
    } catch (error: any) {
      console.error("Error obteniendo estado de identidad de Rapyd:", error.response?.data || error.message)
      throw error
    }
  }

  isInitialized(): boolean {
    return this.initialized
  }
}

// Singleton para RapydService
let rapydInstance: RapydService | null = null

// Función para inicializar el servicio de Rapyd
export async function initializeRapyd(): Promise<boolean> {
  try {
    console.log("Inicializando servicio de Rapyd...")
    rapydInstance = new RapydService()

    // Test the connection
    const success = await rapydInstance.testConnection()

    if (success) {
      console.log("✅ Conexión con Rapyd establecida correctamente")
    } else {
      console.warn("⚠️ Test de conexión con Rapyd falló, pero continuando de todos modos")
    }

    return true
  } catch (error) {
    console.error("Error inicializando Rapyd:", error)
    // Create the instance anyway to avoid null references
    if (!rapydInstance) {
      rapydInstance = new RapydService()
    }
    return false
  }
}

// Función para obtener la instancia de Rapyd
export function getRapyd(): RapydService {
  if (!rapydInstance) {
    console.warn("⚠️ getRapyd() llamado antes de la inicialización, creando instancia ahora")
    rapydInstance = new RapydService()
  }
  return rapydInstance
}
