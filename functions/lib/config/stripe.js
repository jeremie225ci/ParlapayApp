"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getWebhookSecret = exports.getStripe = exports.initializeStripe = void 0;
const stripe_1 = __importDefault(require("stripe"));
const secret_manager_1 = require("@google-cloud/secret-manager");
// Cliente de Secret Manager
const secretClient = new secret_manager_1.SecretManagerServiceClient();
// Variables para almacenar las instancias inicializadas
let stripeInstance = null;
let webhookSecretValue = "";
let initialized = false;
/**
 * Función para acceder a secretos en Google Cloud Secret Manager
 */
async function getSecret(secretName) {
    try {
        // Primero verificar si existe como variable de entorno
        const envVarName = secretName === "stripe-secret-key"
            ? "STRIPE_SECRET_KEY"
            : secretName === "stripe-webhook-secret"
                ? "STRIPE_WEBHOOK_SECRET"
                : "";
        if (envVarName && process.env[envVarName]) {
            console.log(`Usando variable de entorno ${envVarName}`);
            return process.env[envVarName];
        }
        const projectId = process.env.GOOGLE_CLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || "mk-mensenger";
        if (!projectId) {
            console.warn(`No se encontró ID de proyecto, verificando variables de entorno`);
            throw new Error("No se encontró ID de proyecto");
        }
        const name = `projects/${projectId}/secrets/${secretName}/versions/latest`;
        console.log(`Intentando acceder al secreto: ${name}`);
        const [version] = await secretClient.accessSecretVersion({ name });
        if (!version.payload?.data) {
            console.warn(`Secreto ${secretName} no encontrado o vacío, verificando variables de entorno`);
            throw new Error(`Secreto ${secretName} no encontrado o vacío`);
        }
        return version.payload.data.toString();
    }
    catch (error) {
        console.error(`Error al acceder al secreto ${secretName}:`, error);
        // Verificar variables de entorno como fallback
        const envVarName = secretName === "stripe-secret-key"
            ? "STRIPE_SECRET_KEY"
            : secretName === "stripe-webhook-secret"
                ? "STRIPE_WEBHOOK_SECRET"
                : "";
        if (envVarName && process.env[envVarName]) {
            console.log(`Usando variable de entorno ${envVarName} como fallback`);
            return process.env[envVarName];
        }
        console.warn(`No se encontró valor para ${secretName} en variables de entorno`);
        throw error;
    }
}
/**
 * Inicializa Stripe con los secretos de Google Cloud o variables de entorno
 * Debe ser llamada antes de usar cualquier función de este módulo
 */
async function initializeStripe() {
    try {
        if (initialized)
            return;
        console.log("Inicializando Stripe...");
        let secretKey;
        let webhookSecret;
        // Intentar obtener claves de variables de entorno primero
        if (process.env.STRIPE_SECRET_KEY) {
            console.log("Usando STRIPE_SECRET_KEY de variables de entorno");
            secretKey = process.env.STRIPE_SECRET_KEY;
        }
        else {
            // Intentar obtener de Secret Manager como fallback
            secretKey = await getSecret("stripe-secret-key");
        }
        if (process.env.STRIPE_WEBHOOK_SECRET) {
            console.log("Usando STRIPE_WEBHOOK_SECRET de variables de entorno");
            webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
        }
        else {
            // Intentar obtener de Secret Manager como fallback
            webhookSecret = await getSecret("stripe-webhook-secret");
        }
        webhookSecretValue = webhookSecret;
        console.log("Configuración de Stripe cargada correctamente");
        // Inicializar el cliente de Stripe
        stripeInstance = new stripe_1.default(secretKey, {
            apiVersion: "2024-04-10",
        });
        initialized = true;
        console.log("Stripe inicializado correctamente");
    }
    catch (error) {
        console.error("Error al inicializar Stripe:", error);
        throw new Error("No se pudo inicializar Stripe: " + error);
    }
}
exports.initializeStripe = initializeStripe;
/**
 * Retorna la instancia de Stripe inicializada
 * Intenta inicializar si aún no se ha hecho
 */
function getStripe() {
    if (!stripeInstance) {
        console.warn("Stripe no inicializado, intentando inicializar ahora");
        // Verificar si tenemos la clave en variables de entorno
        if (process.env.STRIPE_SECRET_KEY) {
            console.log("Inicializando Stripe con STRIPE_SECRET_KEY de variables de entorno");
            stripeInstance = new stripe_1.default(process.env.STRIPE_SECRET_KEY, {
                apiVersion: "2024-04-10",
            });
            initialized = true;
        }
        else {
            throw new Error("No se puede inicializar Stripe: STRIPE_SECRET_KEY no está disponible");
        }
    }
    return stripeInstance;
}
exports.getStripe = getStripe;
/**
 * Retorna el secreto del webhook
 * Intenta inicializar si aún no se ha hecho
 */
function getWebhookSecret() {
    if (!webhookSecretValue) {
        console.warn("Secreto de webhook no inicializado, verificando variables de entorno");
        if (process.env.STRIPE_WEBHOOK_SECRET) {
            webhookSecretValue = process.env.STRIPE_WEBHOOK_SECRET;
        }
        else {
            throw new Error("No se puede obtener el secreto del webhook: STRIPE_WEBHOOK_SECRET no está disponible");
        }
    }
    return webhookSecretValue;
}
exports.getWebhookSecret = getWebhookSecret;
//# sourceMappingURL=stripe.js.map