"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.environment = void 0;
// src/config/environment.ts
exports.environment = {
    // Configuración de Node.js
    node_env: process.env.NODE_ENV || 'development',
    port: parseInt(process.env.PORT || '5000', 10),
    // Configuración de Stripe
    stripe: {
        secretKey: process.env.STRIPE_SECRET_KEY || '',
        webhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
        refreshUrl: process.env.STRIPE_REFRESH_URL || 'https://votreapp.com/kyc/refresh',
        returnUrl: process.env.STRIPE_RETURN_URL || 'https://votreapp.com/kyc/return',
    },
    // Configuración de Onfido
    onfido: {
        apiToken: process.env.ONFIDO_API_TOKEN || '',
        webhookToken: process.env.ONFIDO_WEBHOOK_TOKEN || '',
        region: process.env.ONFIDO_REGION || 'EU', // EU o US
    },
    // Configuración de Firebase
    firebase: {
        projectId: process.env.FIREBASE_PROJECT_ID || '',
        privateKey: process.env.FIREBASE_PRIVATE_KEY
            ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
            : '',
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
        databaseURL: process.env.FIREBASE_DATABASE_URL || '',
    },
    // Otras configuraciones
    appName: process.env.APP_NAME || 'Wallet App',
    appUrl: process.env.APP_URL || 'https://votreapp.com',
    // Validar la configuración
    validate: () => {
        const requiredVars = [
            'STRIPE_SECRET_KEY',
            'STRIPE_WEBHOOK_SECRET',
            'ONFIDO_API_TOKEN',
            'ONFIDO_WEBHOOK_TOKEN',
            'FIREBASE_PROJECT_ID',
            'FIREBASE_PRIVATE_KEY',
            'FIREBASE_CLIENT_EMAIL',
        ];
        const missingVars = requiredVars.filter(varName => !process.env[varName]);
        if (missingVars.length > 0) {
            throw new Error(`Variables de entorno faltantes: ${missingVars.join(', ')}. ` +
                `Defínelas en la configuración de entorno de Firebase.`);
        }
        return true;
    }
};
//# sourceMappingURL=environment.js.map