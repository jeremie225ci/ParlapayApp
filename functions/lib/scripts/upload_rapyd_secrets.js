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
const secret_manager_1 = require("@google-cloud/secret-manager");
const readline = __importStar(require("readline"));
// Crear cliente de Secret Manager
const client = new secret_manager_1.SecretManagerServiceClient();
// Función para crear o actualizar un secreto
async function createOrUpdateSecret(projectId, secretId, secretValue) {
    try {
        // Verificar si el secreto ya existe
        try {
            await client.getSecret({
                name: `projects/${projectId}/secrets/${secretId}`,
            });
            console.log(`El secreto ${secretId} ya existe. Añadiendo nueva versión...`);
        }
        catch (error) {
            // Si el secreto no existe, crearlo
            console.log(`Creando secreto ${secretId}...`);
            await client.createSecret({
                parent: `projects/${projectId}`,
                secretId: secretId,
                secret: {
                    replication: {
                        automatic: {},
                    },
                },
            });
        }
        // Añadir nueva versión del secreto
        const [version] = await client.addSecretVersion({
            parent: `projects/${projectId}/secrets/${secretId}`,
            payload: {
                data: Buffer.from(secretValue),
            },
        });
        console.log(`Secreto ${secretId} creado/actualizado con éxito: ${version.name}`);
    }
    catch (error) {
        console.error(`Error creando/actualizando secreto ${secretId}:`, error);
        throw error;
    }
}
// Función para leer input del usuario
function askQuestion(query) {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });
    return new Promise((resolve) => rl.question(query, (answer) => {
        rl.close();
        resolve(answer);
    }));
}
// Función principal
async function main() {
    try {
        console.log("=== Subir claves de Rapyd a Google Cloud Secret Manager ===");
        // Obtener ID del proyecto
        let projectId = process.env.GOOGLE_CLOUD_PROJECT;
        if (!projectId) {
            projectId = await askQuestion("ID del proyecto de Google Cloud: ");
        }
        // Obtener claves de Rapyd
        const accessKey = await askQuestion("Clave de acceso de Rapyd (RAPYD_ACCESS_KEY): ");
        const secretKey = await askQuestion("Clave secreta de Rapyd (RAPYD_SECRET_KEY): ");
        const baseUrl = await askQuestion("URL base de Rapyd (RAPYD_BASE_URL) [https://sandboxapi.rapyd.net]: ");
        // Usar valor predeterminado para baseUrl si no se proporciona
        const finalBaseUrl = baseUrl || "https://sandboxapi.rapyd.net";
        // Subir secretos
        await createOrUpdateSecret(projectId, "RAPYD_ACCESS_KEY", accessKey);
        await createOrUpdateSecret(projectId, "RAPYD_SECRET_KEY", secretKey);
        await createOrUpdateSecret(projectId, "RAPYD_BASE_URL", finalBaseUrl);
        // Configurar permisos IAM para la función de Cloud
        console.log("\nRecuerda configurar los permisos IAM para que tu función de Cloud pueda acceder a estos secretos:");
        console.log(`1. Ve a la consola de Google Cloud: https://console.cloud.google.com/security/secret-manager?project=${projectId}`);
        console.log("2. Selecciona cada secreto y haz clic en 'Permisos'");
        console.log("3. Añade tu cuenta de servicio de Cloud Functions con el rol 'Secret Manager Secret Accessor'");
        console.log("\n¡Listo! Tus claves de Rapyd ahora están seguras en Secret Manager.");
    }
    catch (error) {
        console.error("Error:", error);
        process.exit(1);
    }
}
// Ejecutar script
main();
//# sourceMappingURL=upload_rapyd_secrets.js.map