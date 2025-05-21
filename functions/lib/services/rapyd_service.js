"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RapydService = void 0;
const axios_1 = __importDefault(require("axios"));
const crypto_1 = __importDefault(require("crypto"));
const secret_manager_1 = require("@google-cloud/secret-manager");
class RapydService {
    constructor() {
        this.accessKey = "";
        this.secretKey = "";
        this.baseUrl = "https://sandboxapi.rapyd.net";
        this.secretsInitialized = false;
        this.secretManagerClient = new secret_manager_1.SecretManagerServiceClient();
        // Las claves se inicializarán bajo demanda
    }
    /**
     * Inicializa las claves de API desde Google Cloud Secret Manager
     */
    async initializeSecrets() {
        if (this.secretsInitialized)
            return;
        try {
            // Obtener el ID del proyecto de Google Cloud
            const projectId = process.env.GOOGLE_CLOUD_PROJECT || "";
            // Obtener la clave de acceso
            const [accessKeyVersion] = await this.secretManagerClient.accessSecretVersion({
                name: `projects/${projectId}/secrets/RAPYD_ACCESS_KEY/versions/latest`,
            });
            this.accessKey = accessKeyVersion.payload?.data?.toString() || "";
            // Obtener la clave secreta
            const [secretKeyVersion] = await this.secretManagerClient.accessSecretVersion({
                name: `projects/${projectId}/secrets/RAPYD_SECRET_KEY/versions/latest`,
            });
            this.secretKey = secretKeyVersion.payload?.data?.toString() || "";
            // Obtener la URL base (opcional, podría tener un valor predeterminado)
            try {
                const [baseUrlVersion] = await this.secretManagerClient.accessSecretVersion({
                    name: `projects/${projectId}/secrets/RAPYD_BASE_URL/versions/latest`,
                });
                this.baseUrl = baseUrlVersion.payload?.data?.toString() || this.baseUrl;
            }
            catch (error) {
                console.log("Usando URL base predeterminada:", this.baseUrl);
            }
            this.secretsInitialized = true;
            console.log("Claves de Rapyd inicializadas desde Secret Manager");
        }
        catch (error) {
            console.error("Error inicializando claves desde Secret Manager:", error);
            // Fallback a variables de entorno si hay un error
            this.accessKey = process.env.RAPYD_ACCESS_KEY || "";
            this.secretKey = process.env.RAPYD_SECRET_KEY || "";
            this.baseUrl = process.env.RAPYD_BASE_URL || this.baseUrl;
            if (this.accessKey && this.secretKey) {
                console.log("Usando claves de Rapyd desde variables de entorno");
                this.secretsInitialized = true;
            }
            else {
                throw new Error("No se pudieron inicializar las claves de Rapyd");
            }
        }
    }
    /**
     * Genera string aleatorio para el salt
     */
    generateRandomString(length) {
        const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
        let result = '';
        const charactersLength = characters.length;
        for (let i = 0; i < length; i++) {
            result += characters.charAt(Math.floor(Math.random() * charactersLength));
        }
        return result;
    }
    /**
     * Método para calcular la firma HMAC SHA256
     */
    calculateHMACSignature(toSign) {
        const hmac = crypto_1.default.createHmac('sha256', this.secretKey);
        hmac.update(toSign);
        const hash = hmac.digest('hex');
        return Buffer.from(hash).toString('base64');
    }
    /**
     * Genera la firma para las solicitudes a la API de Rapyd según la documentación oficial
     */
    generateSignature(httpMethod, path, salt, timestamp, body) {
        try {
            // Procesar los datos del body para asegurar formato correcto de números
            const processedBody = body ? this.processRequestData(body) : null;
            // Convertir el body a string JSON sin espacios en blanco si existe
            let bodyString = "";
            if (processedBody) {
                bodyString = JSON.stringify(processedBody);
                // Si el body es un objeto vacío, tratar como string vacío según documentación
                bodyString = bodyString === "{}" ? "" : bodyString;
            }
            // Construir la cadena para firmar
            const toSign = httpMethod.toLowerCase() + path + salt + timestamp.toString() + this.accessKey + this.secretKey + bodyString;
            // Calcular HMAC-SHA256
            const hmac = crypto_1.default.createHmac("sha256", this.secretKey);
            hmac.update(toSign);
            // Convertir el hash a hexadecimal y luego a base64
            const signature = Buffer.from(hmac.digest("hex")).toString("base64");
            return signature;
        }
        catch (error) {
            console.error("Error generando firma Rapyd:", error);
            throw error;
        }
    }
    /**
     * Procesa los datos de la solicitud para manejar correctamente los números
     */
    processRequestData(data) {
        if (data === null || data === undefined) {
            return data;
        }
        if (Array.isArray(data)) {
            return data.map(item => this.processRequestData(item));
        }
        if (typeof data === 'object') {
            const result = {};
            for (const key in data) {
                if (Object.prototype.hasOwnProperty.call(data, key)) {
                    const value = data[key];
                    if (typeof value === 'number') {
                        // Convertir números a strings para evitar problemas con decimales
                        result[key] = value.toString();
                    }
                    else if (typeof value === 'object') {
                        result[key] = this.processRequestData(value);
                    }
                    else {
                        result[key] = value;
                    }
                }
            }
            return result;
        }
        return data;
    }
    /**
     * Realiza una solicitud a la API de Rapyd
     */
    async makeRequest(method, path, body) {
        // Asegurarse de que las claves estén inicializadas
        if (!this.secretsInitialized) {
            await this.initializeSecrets();
        }
        try {
            const salt = crypto_1.default.randomBytes(12).toString("hex");
            const timestamp = Math.floor(Date.now() / 1000);
            // Procesar el cuerpo para asegurar formato correcto
            const processedBody = body ? this.processRequestData(body) : null;
            // Generar la firma correcta
            const signature = this.generateSignature(method, path, salt, timestamp, processedBody);
            // Generar idempotency key 
            const idempotency = new Date().getTime().toString();
            // Configurar y realizar la solicitud
            const response = await (0, axios_1.default)({
                method,
                url: `${this.baseUrl}${path}`,
                data: processedBody,
                headers: {
                    "Content-Type": "application/json",
                    "access_key": this.accessKey,
                    "salt": salt,
                    "timestamp": timestamp.toString(),
                    "signature": signature,
                    "idempotency": idempotency
                },
            });
            return response.data;
        }
        catch (error) {
            console.error("Error en solicitud a Rapyd:", error);
            if (axios_1.default.isAxiosError(error) && error.response) {
                console.error("Detalles del error:", {
                    status: error.response.status,
                    data: JSON.stringify(error.response.data)
                });
                throw new Error(`Error de Rapyd: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
            }
            throw error;
        }
    }
    /**
     * Crea un wallet para un usuario
     */
    async createWallet(userData) {
        try {
            // Endpoint correcto según la documentación de Rapyd
            const response = await this.makeRequest("POST", "/v1/user", userData);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error creando wallet: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en createWallet:", error);
            throw error;
        }
    }
    /**
     * Obtiene el saldo de un wallet - MÉTODO REQUERIDO POR wallet_service.ts
     */
    async getWalletBalance(walletId) {
        try {
            const response = await this.makeRequest("GET", `/v1/user/${walletId}/accounts`);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error obteniendo saldo: ${response.status.message}`);
            }
            return {
                balance: response.data.accounts.reduce((total, account) => {
                    if (account.currency === "EUR") {
                        return total + account.balance;
                    }
                    return total;
                }, 0),
                currency: "EUR",
                accounts: response.data.accounts,
            };
        }
        catch (error) {
            console.error("Error en getWalletBalance:", error);
            throw error;
        }
    }
    /**
    * Transfiere fondos entre wallets
    */
    async transferFunds(sourceWalletId, destinationWalletId, amount, currency = "EUR") {
        try {
            // CORREGIDO: Usar el nuevo endpoint según la documentación
            const path = "/v1/ewallets/transfer";
            // Convertir el monto a string para evitar problemas con decimales
            // Si amount es un string, usarlo tal cual
            const amountStr = typeof amount === 'string' ? amount : amount.toString();
            // Crear el cuerpo de la solicitud usando exactamente los nombres de campo que espera Rapyd
            const body = {
                source_ewallet: sourceWalletId,
                destination_ewallet: destinationWalletId,
                amount: amountStr,
                currency: currency
            };
            console.log("Payload para transferencia Rapyd:", JSON.stringify(body));
            // Utilizar directamente makeRequest que ya maneja correctamente la firma
            const response = await this.makeRequest("POST", path, body);
            console.log("Respuesta de transferencia Rapyd:", JSON.stringify(response));
            return response;
        }
        catch (error) {
            console.error("Error en transferFunds:", error);
            throw error;
        }
    }
    /**
     * Añade fondos a un wallet (simula un pago con tarjeta) - MÉTODO REQUERIDO POR wallet_service.ts
     */
    async addFunds(walletId, amount, currency, paymentMethod) {
        try {
            // En un entorno real, esto usaría la API de pagos de Rapyd
            // Aquí simulamos un pago exitoso
            const body = {
                ewallet: walletId,
                amount,
                currency,
                payment_method: paymentMethod,
            };
            const response = await this.makeRequest("POST", "/v1/account/deposit", body);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error añadiendo fondos: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en addFunds:", error);
            throw error;
        }
    }
    /**
     * Retira fondos de un wallet - MÉTODO REQUERIDO POR wallet_service.ts
     */
    async withdrawFunds(walletId, amount, currency, beneficiaryId) {
        try {
            const body = {
                ewallet: walletId,
                amount,
                currency,
                beneficiary: beneficiaryId,
            };
            const response = await this.makeRequest("POST", "/v1/account/withdraw", body);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error retirando fondos: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en withdrawFunds:", error);
            throw error;
        }
    }
    /**
     * Crea un beneficiario para pagos
     */
    async createBeneficiary(walletId, bankDetails) {
        try {
            const body = {
                ewallet: walletId,
                ...bankDetails,
            };
            const response = await this.makeRequest("POST", "/v1/payouts/beneficiary", body);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error creando beneficiario: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en createBeneficiary:", error);
            throw error;
        }
    }
    /**
     * Obtiene el historial de transacciones
     */
    async getTransactionHistory(walletId, page, pageSize) {
        try {
            const response = await this.makeRequest("GET", `/v1/user/${walletId}/transactions?page=${page}&page_size=${pageSize}`);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error obteniendo historial: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en getTransactionHistory:", error);
            throw error;
        }
    }
    /**
     * Verifica la identidad de un usuario
     */
    async verifyIdentity(walletId, verificationData) {
        try {
            const body = {
                ewallet: walletId,
                ...verificationData,
            };
            const response = await this.makeRequest("POST", "/v1/identities/verification", body);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error verificando identidad: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en verifyIdentity:", error);
            throw error;
        }
    }
    /**
     * Obtiene el estado de verificación de identidad
     */
    async getIdentityStatus(identityId) {
        try {
            const response = await this.makeRequest("GET", `/v1/identities/verification/${identityId}`);
            if (response.status.status !== "SUCCESS") {
                throw new Error(`Error obteniendo estado de verificación: ${response.status.message}`);
            }
            return response.data;
        }
        catch (error) {
            console.error("Error en getIdentityStatus:", error);
            throw error;
        }
    }
    /**
     * Crea una página de checkout para procesar pagos
     */
    async createCheckout(data) {
        try {
            return await this.makeRequest('post', '/v1/checkout', data);
        }
        catch (error) {
            console.error('Error en createCheckout:', error);
            throw error;
        }
    }
    /**
     * Obtiene el estado de un checkout
     */
    async getCheckoutStatus(checkoutId) {
        try {
            return await this.makeRequest('get', `/v1/checkout/${checkoutId}`, null);
        }
        catch (error) {
            console.error('Error en getCheckoutStatus:', error);
            throw error;
        }
    }
    /**
     * Prueba la conexión con Rapyd
     */
    async testConnection() {
        try {
            // Intentar inicializar las claves
            if (!this.secretsInitialized) {
                await this.initializeSecrets();
            }
            // Hacer una solicitud simple para verificar la conexión
            const response = await this.makeRequest("GET", "/v1/data/countries");
            return response.status.status === "SUCCESS";
        }
        catch (error) {
            console.error("Error en testConnection:", error);
            return false;
        }
    }
    /**
     * Obtiene detalles completos de un wallet
     */
    async getWalletDetails(walletId) {
        try {
            console.log(`Obteniendo detalles completos de wallet ${walletId}`);
            // Usar el método makeRequest que ya incluye toda la lógica de firma
            return await this.makeRequest("GET", `/v1/user/${walletId}`);
        }
        catch (error) {
            console.error(`Error en getWalletDetails para wallet ${walletId}:`, error);
            // Si tenemos una respuesta de error de la API, devolvemos esa información
            if (error.response) {
                console.error(`Respuesta de error de API: ${error.response.status}`, error.response.data);
                throw new Error(`Error API Rapyd: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
            }
            // Error genérico
            throw new Error(`Error al obtener detalles de wallet: ${error.message}`);
        }
    }
}
exports.RapydService = RapydService;
//# sourceMappingURL=rapyd_service.js.map