import * as crypto from "crypto";

/**
 * Genera una cadena aleatoria para usar como salt
 */
function generateRandomString(size: number): string {
  return crypto.randomBytes(size).toString('hex');
}

/**
 * Genera la firma para la API de Rapyd siguiendo exactamente la documentación oficial
 */
export function generateRapydSignature(
  method: string,
  urlPath: string,
  salt: string,
  timestamp: string,
  accessKey: string,
  secretKey: string,
  body: any = null
): string {
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
  } catch (error) {
    console.error("Error generando firma Rapyd:", error);
    throw error;
  }
}

/**
 * Procesa los números en el body para evitar problemas con decimales
 */
function processBodyForSignature(body: any): any {
  if (body === null || body === undefined) {
    return body;
  }
  
  if (Array.isArray(body)) {
    return body.map(item => processBodyForSignature(item));
  }
  
  if (typeof body === 'object') {
    const result: any = {};
    for (const key in body) {
      if (Object.prototype.hasOwnProperty.call(body, key)) {
        const value = body[key];
        
        if (typeof value === 'number') {
          // Convertir números a strings para evitar truncamiento de ceros
          result[key] = value.toString();
        } else if (value === null || value === undefined) {
          // Omitir propiedades nulas o indefinidas
          continue;
        } else if (typeof value === 'object') {
          result[key] = processBodyForSignature(value);
        } else {
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
export function generateRapydHeaders(method: string, path: string, body: any = null): Record<string, string> {
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
    const signature = generateRapydSignature(
      method,
      path,
      salt,
      timestamp,
      accessKey,
      secretKey,
      body
    );

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
  } catch (error) {
    console.error("Error generando headers Rapyd:", error);
    throw error;
  }
}