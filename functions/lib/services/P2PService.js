"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.P2PService = void 0;
const firebase_1 = require("../config/firebase");
const uuid_1 = require("uuid");
class P2PService {
    constructor(ledgerService, userRepository) {
        this.ledgerService = ledgerService;
        this.userRepository = userRepository;
        this.db = firebase_1.admin.firestore();
    }
    async sendP2P(fromUserId, toUserId, amount, description = 'Transfert P2P') {
        if (amount <= 0)
            throw new Error('Le montant doit être positif');
        if (fromUserId === toUserId)
            throw new Error('Impossible d\'envoyer à soi-même');
        // Vérifier que les deux utilisateurs existent
        const [sender, receiver] = await Promise.all([
            this.userRepository.getUserById(fromUserId),
            this.userRepository.getUserById(toUserId),
        ]);
        if (!sender)
            throw new Error('Expéditeur introuvable');
        if (!receiver)
            throw new Error('Destinataire introuvable');
        const p2pId = (0, uuid_1.v4)();
        const now = firebase_1.admin.firestore.FieldValue.serverTimestamp();
        await this.db.runTransaction(async (tx) => {
            // 1) Vérifier solde
            const sRef = this.db.collection('wallets').doc(fromUserId);
            const sDoc = await tx.get(sRef);
            if (!sDoc.exists)
                throw new Error('Wallet expéditeur introuvable');
            const sBal = sDoc.data()?.balance || 0;
            if (sBal < amount)
                throw new Error('Solde insuffisant');
            // 2) Débit expéditeur
            tx.update(sRef, { balance: sBal - amount, updatedAt: now });
            // 3) Crédit destinataire
            const rRef = this.db.collection('wallets').doc(toUserId);
            const rDoc = await tx.get(rRef);
            if (!rDoc.exists) {
                tx.set(rRef, { balance: amount, updatedAt: now });
            }
            else {
                const rBal = rDoc.data()?.balance || 0;
                tx.update(rRef, { balance: rBal + amount, updatedAt: now });
            }
            // 4) Enregistrer les deux transactions
            const meta = { p2pId, partnerId: toUserId };
            const tx1 = { id: (0, uuid_1.v4)(), userId: fromUserId, amount: -amount, type: 'debit', description: `Envoi à ${receiver.email ?? toUserId}: ${description}`, metadata: meta, timestamp: now };
            const tx2 = { id: (0, uuid_1.v4)(), userId: toUserId, amount: amount, type: 'credit', description: `Reçu de ${sender.email ?? fromUserId}: ${description}`, metadata: { p2pId, partnerId: fromUserId }, timestamp: now };
            tx.set(this.db.collection('transactions').doc(tx1.id), tx1);
            tx.set(this.db.collection('transactions').doc(tx2.id), tx2);
        });
        return p2pId;
    }
    async getP2PTransactions(userId, limit = 50) {
        const snap = await this.db
            .collection('transactions')
            .where('userId', '==', userId)
            .where('metadata.p2pId', '!=', null)
            .orderBy('metadata.p2pId')
            .orderBy('timestamp', 'desc')
            .limit(limit)
            .get();
        return snap.docs.map(d => d.data());
    }
}
exports.P2PService = P2PService;
//# sourceMappingURL=P2PService.js.map