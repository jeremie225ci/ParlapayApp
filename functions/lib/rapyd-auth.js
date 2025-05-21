"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateRapydHeaders = exports.generateRapydSignature = void 0;
const crypto = __importStar(require("crypto"));
/**
 * Genera una cadena aleatoria para usar como salt
 */
function generateRandomString(size) {
    return crypto.randomBytes(size).toString('hex');
}
/**
 * Genera la firma para la API de Rapyd siguiendo exactamente la documentación oficial
 */
function generateRapydSignature(method, urlPath, salt, timestamp, accessKey, secretKey, body = null) {
    try {
        // Convertir el body a string JSON sin espacios en blanco
        let bodyString = "";
        if (body) {
            // Procesar números para evitar problemas de truncamiento
            const processedBody = processBodyForSignature(body);
            bodyString = JSON.stringify(processedBody);
            // Si el body es un objeto vacío, tratar como string vacío
            bodyString = bodyString === "{}" ? "" : bodyString;
        }
        // Construir la cadena para firmar exactamente como en la documentación
        const toSign = method.toLowerCase() + urlPath + salt + timestamp + accessKey + secretKey + bodyString;
        // Calcular el hash HMAC con SHA256
        const hash = crypto.createHmac('sha256', secretKey);
        hash.update(toSign);
        // Convertir el hash a hexadecimal y luego a base64
        const signature = Buffer.from(hash.digest("hex")).toString("base64");
        return signature;
    }
    catch (error) {
        console.error("Error generando firma Rapyd:", error);
        throw error;
    }
}
exports.generateRapydSignature = generateRapydSignature;
/**
 * Procesa los números en el body para evitar problemas con decimales
 */
function processBodyForSignature(body) {
    if (body === null || body === undefined) {
        return body;
    }
    if (Array.isArray(body)) {
        return body.map(item => processBodyForSignature(item));
    }
    if (typeof body === 'object') {
        const result = {};
        for (const key in body) {
            if (Object.prototype.hasOwnProperty.call(body, key)) {
                const value = body[key];
                if (typeof value === 'number') {
                    // Convertir números a strings para evitar truncamiento de ceros
                    result[key] = value.toString();
                }
                else if (value === null || value === undefined) {
                    // Omitir propiedades nulas o indefinidas
                    continue;
                }
                else if (typeof value === 'object') {
                    result[key] = processBodyForSignature(value);
                }
                else {
                    result[key] = value;
                }
            }
        }
        return result;
    }
    return body;
}
/**
 * Genera los encabezados de autenticación para Rapyd API
 */
function generateRapydHeaders(method, path, body = null) {
    try {
        // Obtener las claves de API
        const accessKey = process.env.RAPYD_ACCESS_KEY || "";
        const secretKey = process.env.RAPYD_SECRET_KEY || "";
        if (!accessKey || !secretKey) {
            console.error("Claves de API de Rapyd no configuradas");
            throw new Error("Claves de API de Rapyd no configuradas correctamente");
        }
        // Generar salt aleatorio
        const salt = generateRandomString(8);
        // Timestamp actual en segundos (Unix time)
        const timestamp = Math.floor(Date.now() / 1000).toString();
        // Generar signature
        const signature = generateRapydSignature(method, path, salt, timestamp, accessKey, secretKey, body);
        // Generar idempotency key
        const idempotency = new Date().getTime().toString();
        // Construir headers según la documentación
        return {
            "Content-Type": "application/json",
            "access_key": accessKey,
            "salt": salt,
            "timestamp": timestamp,
            "signature": signature,
            "idempotency": idempotency
        };
    }
    catch (error) {
        console.error("Error generando headers Rapyd:", error);
        throw error;
    }
}
exports.generateRapydHeaders = generateRapydHeaders;
//# sourceMappingURL=rapyd-auth.js.map