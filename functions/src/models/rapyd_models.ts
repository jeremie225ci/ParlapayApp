// Modelos para la API de Rapyd

// Asegurarse de que PartialUserWithRapyd incluye updatedAt
export interface UserWithRapyd {
  id: string // Añadido para compatibilidad con Firestore
  userId: string
  firstName?: string
  lastName?: string
  email?: string
  phoneNumber?: string
  rapydWalletId?: string
  rapydIdentityId?: string
  rapydBeneficiaryId?: string
  kycStatus?: string
  kycCompleted?: boolean
  birthDate?: string
  address?: string
  city?: string
  postalCode?: string
  country?: string
  walletStatus?: string
  walletCreatedAt?: Date
  rapydCreatedAt?: Date // Añadido para compatibilidad
  kycUpdatedAt?: Date
  kycRejectionReason?: string | null
  kycInitiatedAt?: Date // Añadido para compatibilidad
  bankDetails?: any // Añadido para compatibilidad
  updatedAt?: Date // Añadido para compatibilidad
}

// Tipo parcial para actualizaciones
export type PartialUserWithRapyd = Partial<UserWithRapyd>

// Modelo para transacciones
export interface TransactionModel {
  id: string
  amount: number
  currency?: string
  senderId: string
  receiverId: string
  timestamp: Date | any
  description?: string
  type?: string
  status?: string
  rapydTransactionId?: string
}

// Modelo para wallet
export interface WalletModel {
  id: string // Añadido para compatibilidad con Firestore
  userId: string
  rapydWalletId?: string
  balance: number
  currency?: string
  accountStatus?: string
  transactions?: TransactionModel[]
  lastBalanceUpdate?: Date
  iban?: string
  bankAccountNumber?: string
  routingNumber?: string
  updatedAt?: Date // Añadido para compatibilidad
}

// Tipo parcial para actualizaciones de wallet
export type PartialWalletModel = Partial<WalletModel>

// Modelo para datos de usuario en Rapyd
export interface RapydUserData {
  first_name: string
  last_name: string
  email: string
  phone_number?: string
  type: string
  ewallet_reference_id: string
}

// Modelo para respuesta de Rapyd
export interface RapydResponse {
  status: {
    status: string
    message: string
    response_code: string
    operation_id: string
  }
  data: any
}
