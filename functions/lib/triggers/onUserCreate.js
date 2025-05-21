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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserCreate = void 0;
// src/triggers/onUserCreate.ts
const functions = __importStar(require("firebase-functions/v1"));
const stripe_1 = __importDefault(require("stripe"));
const firebase_1 = require("../config/firebase");
const stripe = new stripe_1.default(process.env.STRIPE_SECRET, { apiVersion: '2024-04-10' });
/**
 * Trigger v1 para creación de usuarios (Auth) en Firebase.
 * Usa "firebase-functions/v1" para mantener soporte de triggers de Auth
 */
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    // 1) Crear cuenta Express en Stripe
    const account = await stripe.accounts.create({
        type: 'express',
        country: 'ES',
        email: user.email,
        metadata: { firebaseUserId: user.uid },
        capabilities: {
            card_payments: { requested: true },
            transfers: { requested: true }
        }
    });
    // 2) Guardar connectAccountId en Firestore
    await firebase_1.admin.firestore()
        .collection('users')
        .doc(user.uid)
        .set({ connectAccountId: account.id, kycCompleted: false }, { merge: true });
});
//# sourceMappingURL=onUserCreate.js.map