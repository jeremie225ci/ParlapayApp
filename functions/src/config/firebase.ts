import * as admin from 'firebase-admin';

// Inicializar Firebase Admin si no está ya inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

export { admin };