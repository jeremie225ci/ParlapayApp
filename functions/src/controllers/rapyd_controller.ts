import { Request, Response } from 'express';
import { getRapyd } from '../services/rapyd_init';
import { getFirestore } from 'firebase-admin/firestore';

const db = getFirestore();

export class RapydController {
  async createWallet(req: Request, res: Response): Promise<void> {
    try {
      const { userId, userData } = req.body;
      console.log(`Creando wallet para usuario: ${userId}`);
      
      if (!userId) {
        res.status(400).json({ error: "UserId es requerido" });
        return;
      }
      
      // Obtener datos actuales de wallet
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists) {
        res.status(404).json({ error: "Datos de wallet no encontrados" });
        return;
      }
      
      const walletData = walletDoc.data() as any;
      
      // Preparar datos para Rapyd
      const rapydBody = {
        first_name: walletData.firstName || userData?.firstName || "",
        last_name: walletData.lastName || userData?.lastName || "",
        ewallet_reference_id: userId,
        type: "person",
        contact: {
          phone_number: walletData.phoneNumber || userData?.phoneNumber || "",
          email: walletData.email || userData?.email || "",
          first_name: walletData.firstName || userData?.firstName || "",
          last_name: walletData.lastName || userData?.lastName || "",
          contact_type: "personal",
          address: {
            name: `${walletData.firstName || ""} ${walletData.lastName || ""}`,
            line_1: walletData.address || userData?.address || "",
            city: walletData.city || userData?.city || "",
            state: "",
            country: walletData.country || userData?.country || "ES",
            zip: walletData.postalCode || userData?.postalCode || "",
            phone_number: walletData.phoneNumber || userData?.phoneNumber || ""
          },
          identification_type: walletData.identificationType || userData?.identificationType || "passport",
          identification_number: walletData.identificationNumber || userData?.identificationNumber || "",
          date_of_birth: walletData.birthDate ? walletData.birthDate.split('T')[0] : "",
          country: walletData.country || userData?.country || "ES",
          nationality: walletData.nationality || userData?.nationality || walletData.country || "ES"
        },
        metadata: {
          iban: walletData.iban || userData?.iban || "",
          gender: walletData.gender || userData?.gender || "male",
          userId: userId
        }
      };
      
      console.log("Datos preparados para crear wallet:", JSON.stringify(rapydBody));
      
      // Obtener la instancia de Rapyd y crear el wallet
      const rapydService = getRapyd();
      const rapydResponse = await rapydService.createWallet(rapydBody);
      
      console.log("Respuesta recibida de Rapyd:", rapydResponse);
      
      if (rapydResponse && rapydResponse.status && rapydResponse.status.status === 'SUCCESS') {
        // Actualizar en Firestore
        await walletRef.update({
          walletId: rapydResponse.data.id,
          kycStatus: 'processing',
          accountStatus: 'pending',
          pendingSyncWithRapyd: false,
          updatedAt: new Date()
        });
        
        res.status(200).json({
          success: true,
          message: "Wallet creada correctamente",
          walletId: rapydResponse.data.id,
          kycStatus: 'processing'
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(rapydResponse)}`);
      }
    } catch (error: any) {
      console.error("Error en RapydController.createWallet:", error);
      res.status(500).json({
        error: `Error creando wallet: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }

  async getWalletBalance(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.params.userId;
      console.log(`Obteniendo balance para usuario: ${userId}`);
      
      // Obtener datos de wallet de Firestore
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists) {
        res.status(404).json({ error: "Wallet no encontrada" });
        return;
      }
      
      const walletData = walletDoc.data() as any;
      
      if (!walletData.walletId) {
        res.status(200).json({
          success: true,
          balance: 0.0,
          offline: true,
          message: "Wallet aún no creada en Rapyd"
        });
        return;
      }
      
      // Consultar balance en Rapyd
      const rapydService = getRapyd();
      const accounts = await rapydService.getWalletBalance(walletData.walletId);
      
      // Encontrar la cuenta en EUR
      let eurAccount = accounts.find((acc: any) => acc.currency === 'EUR');
      
      if (!eurAccount && accounts.length > 0) {
        eurAccount = accounts[0]; // Si no hay cuenta en EUR, usar la primera
      }
      
      const balance = eurAccount ? parseFloat(eurAccount.balance) : 0.0;
      
      // Actualizar balance en Firestore
      await walletRef.update({
        balance: balance,
        lastBalanceUpdate: new Date()
      });
      
      res.status(200).json({
        success: true,
        balance: balance,
        currency: eurAccount ? eurAccount.currency : 'EUR',
        accounts: accounts
      });
    } catch (error: any) {
      console.error("Error en RapydController.getWalletBalance:", error);
      res.status(500).json({
        error: `Error obteniendo balance: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }

  async transferFunds(req: Request, res: Response): Promise<void> {
    try {
      console.log("Recibida solicitud de transferencia:", JSON.stringify(req.body));
      
      // Extraer parámetros, aceptando tanto el formato original como el de Flutter
      const sender = req.body.sender || req.body.source_ewallet;
      const receiver = req.body.receiver || req.body.destination_ewallet;
      const amount = req.body.amount;
      const currency = req.body.currency || 'EUR';
      
      if (!sender || !receiver || !amount) {
        res.status(400).json({ 
          success: false,
          error: "Se requieren sender/source_ewallet, receiver/destination_ewallet y amount" 
        });
        return;
      }
      
      try {
        // Obtener datos de wallet del remitente
        const senderWalletRef = db.collection('wallets').doc(sender);
        const senderWalletDoc = await senderWalletRef.get();
        
        if (!senderWalletDoc.exists || !senderWalletDoc.data()?.walletId) {
          res.status(404).json({ 
            success: false,
            error: "Wallet del remitente no encontrada o incompleta" 
          });
          return;
        }
        
        // Obtener datos de wallet del destinatario
        const receiverWalletRef = db.collection('wallets').doc(receiver);
        const receiverWalletDoc = await receiverWalletRef.get();
        
        if (!receiverWalletDoc.exists || !receiverWalletDoc.data()?.walletId) {
          res.status(404).json({ 
            success: false,
            error: "Wallet del destinatario no encontrada o incompleta" 
          });
          return;
        }
        
        const senderWalletId = senderWalletDoc.data()?.walletId;
        const receiverWalletId = receiverWalletDoc.data()?.walletId;
        
        console.log(`Realizando transferencia de ${senderWalletId} a ${receiverWalletId} por ${amount} ${currency}`);
        
        // Realizar transferencia en Rapyd
        const rapydService = getRapyd();
        const transferResponse = await rapydService.transferFunds(
          senderWalletId,
          receiverWalletId,
          parseFloat(amount.toString()),
          currency
        );
        
        console.log("Respuesta de transferencia:", JSON.stringify(transferResponse));
        
        if (transferResponse && transferResponse.status && transferResponse.status.status === 'SUCCESS') {
          // Actualizar balances en Firestore
          await Promise.all([
            this.updateUserBalanceAfterTransfer(sender),
            this.updateUserBalanceAfterTransfer(receiver)
          ]);
          
          // Registrar transacción
          const transactionId = `transfer_${Date.now()}_${sender.substring(0, 4)}_${receiver.substring(0, 4)}`;
          
          await db.collection('transactions').add({
            id: transactionId,
            sender,
            receiver,
            amount: parseFloat(amount.toString()),
            currency,
            status: 'completed',
            type: 'transfer',
            createdAt: new Date(),
            rapydTransactionId: transferResponse.data.id
          });
          
          res.status(200).json({
            success: true,
            message: "Transferencia realizada correctamente",
            transactionId: transferResponse.data.id,
            data: transferResponse.data
          });
        } else {
          throw new Error(`Error de Rapyd: ${JSON.stringify(transferResponse)}`);
        }
      } catch (error) {
        console.error("Error verificando wallets o realizando transferencia:", error);
        throw error; // Re-lanzar para que se maneje en el bloque catch exterior
      }
    } catch (error: any) {
      console.error("Error en RapydController.transferFunds:", error);
      
      let errorMessage = "Error desconocido";
      let statusCode = 500;
      
      if (error.response) {
        // Error de Rapyd API
        console.error("Error de Rapyd API:", JSON.stringify(error.response.data));
        errorMessage = JSON.stringify(error.response.data);
        statusCode = error.response.status;
      } else if (error.request) {
        // Error de red
        console.error("Error de red:", error.request);
        errorMessage = "Error de red: no se recibió respuesta";
      } else {
        // Otro tipo de error
        console.error("Error general:", error.message);
        errorMessage = error.message;
      }
      
      res.status(statusCode).json({
        success: false,
        error: `Error en transferencia: ${statusCode} - ${errorMessage}`
      });
    }
  }

  private async updateUserBalanceAfterTransfer(userId: string): Promise<void> {
    try {
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists) return;
      
      const walletData = walletDoc.data() as any;
      if (!walletData.walletId) return;
      
      // Consultar nuevo balance en Rapyd
      const rapydService = getRapyd();
      const accounts = await rapydService.getWalletBalance(walletData.walletId);
      
      // Encontrar la cuenta en EUR
      let eurAccount = accounts.find((acc: any) => acc.currency === 'EUR');
      
      if (!eurAccount && accounts.length > 0) {
        eurAccount = accounts[0];
      }
      
      const balance = eurAccount ? parseFloat(eurAccount.balance) : 0.0;
      
      // Actualizar balance en Firestore
      await walletRef.update({
        balance: balance,
        lastBalanceUpdate: new Date()
      });
    } catch (error) {
      console.error(`Error actualizando balance para usuario ${userId}:`, error);
    }
  }

  async addFunds(req: Request, res: Response): Promise<void> {
    try {
      const { userId, amount, currency = 'EUR' } = req.body;
      console.log(`Añadiendo fondos para usuario ${userId}: ${amount} ${currency}`);
      
      if (!userId || !amount) {
        res.status(400).json({ error: "Se requieren userId y amount" });
        return;
      }
      
      // Obtener datos de wallet
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists || !walletDoc.data()?.walletId) {
        res.status(404).json({ error: "Wallet no encontrada o incompleta" });
        return;
      }
      
      const walletId = walletDoc.data()?.walletId;
      
      // Crear checkout en Rapyd
      const rapydService = getRapyd();
      const checkoutResponse = await rapydService.createCheckout(
        walletId,
        parseFloat(amount),
        currency
      );
      
      console.log("Respuesta de checkout:", checkoutResponse);
      
      if (checkoutResponse && checkoutResponse.status && checkoutResponse.status.status === 'SUCCESS') {
        // Registrar intención de pago
        await db.collection('payments').add({
          userId,
          amount: parseFloat(amount),
          currency,
          status: 'pending',
          type: 'deposit',
          createdAt: new Date(),
          rapydCheckoutId: checkoutResponse.data.id,
          rapydRedirectUrl: checkoutResponse.data.redirect_url,
          rapydCheckoutPage: checkoutResponse.data.checkout_page
        });
        
        res.status(200).json({
          success: true,
          message: "Checkout creado correctamente",
          checkoutId: checkoutResponse.data.id,
          redirectUrl: checkoutResponse.data.redirect_url,
          checkoutPage: checkoutResponse.data.checkout_page
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(checkoutResponse)}`);
      }
    } catch (error: any) {
      console.error("Error en RapydController.addFunds:", error);
      res.status(500).json({
        error: `Error añadiendo fondos: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }

  async withdrawFunds(req: Request, res: Response): Promise<void> {
    try {
      const { userId, amount, currency = 'EUR', beneficiaryId } = req.body;
      console.log(`Retirando fondos para usuario ${userId}: ${amount} ${currency}`);
      
      if (!userId || !amount || !beneficiaryId) {
        res.status(400).json({ error: "Se requieren userId, amount y beneficiaryId" });
        return;
      }
      
      // Obtener datos de wallet
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists || !walletDoc.data()?.walletId) {
        res.status(404).json({ error: "Wallet no encontrada o incompleta" });
        return;
      }
      
      const walletId = walletDoc.data()?.walletId;
      
      // Verificar balance
      const rapydService = getRapyd();
      const accounts = await rapydService.getWalletBalance(walletId);
      
      let eurAccount = accounts.find((acc: any) => acc.currency === 'EUR');
      if (!eurAccount && accounts.length > 0) {
        eurAccount = accounts[0];
      }
      
      const balance = eurAccount ? parseFloat(eurAccount.balance) : 0.0;
      
      if (balance < parseFloat(amount)) {
        res.status(400).json({ 
          error: "Balance insuficiente", 
          balance, 
          requestedAmount: parseFloat(amount) 
        });
        return;
      }
      
      // Realizar payout en Rapyd
      const payoutResponse = await rapydService.withdrawFunds(
        walletId,
        parseFloat(amount),
        currency,
        beneficiaryId
      );
      
      console.log("Respuesta de payout:", payoutResponse);
      
      if (payoutResponse && payoutResponse.status && payoutResponse.status.status === 'SUCCESS') {
        // Registrar transacción
        await db.collection('transactions').add({
          userId,
          amount: parseFloat(amount),
          currency,
          status: 'pending',
          type: 'withdrawal',
          createdAt: new Date(),
          rapydPayoutId: payoutResponse.data.id,
          beneficiaryId
        });
        
        // Actualizar balance
        await this.updateUserBalanceAfterTransfer(userId);
        
        res.status(200).json({
          success: true,
          message: "Retiro iniciado correctamente",
          payoutId: payoutResponse.data.id,
          status: payoutResponse.data.status
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(payoutResponse)}`);
      }
    } catch (error: any) {
      console.error("Error en RapydController.withdrawFunds:", error);
      res.status(500).json({
        error: `Error retirando fondos: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }

  async getTransactionHistory(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.params.userId;
      console.log(`Obteniendo historial de transacciones para usuario: ${userId}`);
      
      if (!userId) {
        res.status(400).json({ error: "UserId es requerido" });
        return;
      }
      
      // Obtener transacciones desde Firestore
      const transactionsSnapshot = await db
        .collection('transactions')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .get();
      
      const transactions = transactionsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      
      res.status(200).json({
        success: true,
        transactions
      });
    } catch (error: any) {
      console.error("Error en RapydController.getTransactionHistory:", error);
      res.status(500).json({ 
        error: error.message
      });
    }
  }

  async createBeneficiary(req: Request, res: Response): Promise<void> {
    try {
      const { userId, bankDetails } = req.body;
      console.log(`Creando beneficiario para usuario: ${userId}`);
      
      if (!userId || !bankDetails) {
        res.status(400).json({ error: "UserId y bankDetails son requeridos" });
        return;
      }
      
      // Obtener datos de wallet
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists || !walletDoc.data()?.walletId) {
        res.status(404).json({ error: "Wallet no encontrada o incompleta" });
        return;
      }
      
      const walletId = walletDoc.data()?.walletId;
      
      // Crear beneficiario en Rapyd
      const rapydService = getRapyd();
      const beneficiaryResponse = await rapydService.createBeneficiary(walletId, bankDetails);
      
      console.log("Respuesta de creación de beneficiario:", beneficiaryResponse);
      
      if (beneficiaryResponse && beneficiaryResponse.status && beneficiaryResponse.status.status === 'SUCCESS') {
        // Guardar beneficiario en Firestore
        await db.collection('beneficiaries').add({
          userId,
          walletId,
          bankDetails,
          rapydBeneficiaryId: beneficiaryResponse.data.id,
          status: beneficiaryResponse.data.status,
          createdAt: new Date()
        });
        
        res.status(200).json({
          success: true,
          message: "Beneficiario creado correctamente",
          beneficiaryId: beneficiaryResponse.data.id
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(beneficiaryResponse)}`);
      }
    } catch (error: any) {
      console.error("Error en RapydController.createBeneficiary:", error);
      res.status(500).json({
        error: `Error creando beneficiario: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }

  async verifyIdentity(req: Request, res: Response): Promise<void> {
    try {
      const { userId, verificationData } = req.body;
      console.log(`Verificando identidad para usuario: ${userId}`);
      
      if (!userId || !verificationData) {
        res.status(400).json({ error: "UserId y verificationData son requeridos" });
        return;
      }
      
      // Obtener datos de wallet
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists || !walletDoc.data()?.walletId) {
        res.status(404).json({ error: "Wallet no encontrada o incompleta" });
        return;
      }
      
      const walletId = walletDoc.data()?.walletId;
      
      // Verificar identidad en Rapyd
      const rapydService = getRapyd();
      const identityResponse = await rapydService.verifyIdentity(walletId, verificationData);
      
      console.log("Respuesta de verificación de identidad:", identityResponse);
      
      if (identityResponse && identityResponse.status && identityResponse.status.status === 'SUCCESS') {
        // Actualizar estado en Firestore
        await walletRef.update({
          identityVerificationId: identityResponse.data.id,
          identityVerificationStatus: 'pending',
          identityVerificationSubmittedAt: new Date()
        });
        
        res.status(200).json({
          success: true,
          message: "Verificación de identidad iniciada correctamente",
          verificationId: identityResponse.data.id
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(identityResponse)}`);
      }
    } catch (error: any) {
      console.error("Error en RapydController.verifyIdentity:", error);
      res.status(500).json({
        error: `Error verificando identidad: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }

  async getIdentityStatus(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.params.userId;
      console.log(`Obteniendo estado de verificación de identidad para usuario: ${userId}`);
      
      if (!userId) {
        res.status(400).json({ error: "UserId es requerido" });
        return;
      }
      
      // Obtener datos de wallet
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists) {
        res.status(404).json({ error: "Wallet no encontrada" });
        return;
      }
      
      const walletData = walletDoc.data() as any;
      
      if (!walletData.identityVerificationId) {
        res.status(200).json({
          success: true,
          identityVerificationStatus: 'not_started',
          message: "Verificación de identidad no iniciada"
        });
        return;
      }
      
      // Consultar estado en Rapyd
      const rapydService = getRapyd();
      const identityStatusResponse = await rapydService.getIdentityStatus(walletData.identityVerificationId);
      
      console.log("Respuesta de estado de verificación:", identityStatusResponse);
      
      if (identityStatusResponse && identityStatusResponse.status && identityStatusResponse.status.status === 'SUCCESS') {
        // Actualizar estado en Firestore si ha cambiado
        const rapydStatus = identityStatusResponse.data.status.toLowerCase();
        
        if (rapydStatus !== walletData.identityVerificationStatus) {
          await walletRef.update({
            identityVerificationStatus: rapydStatus,
            identityVerificationUpdatedAt: new Date()
          });
        }
        
        res.status(200).json({
          success: true,
          identityVerificationStatus: rapydStatus,
          details: identityStatusResponse.data
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(identityStatusResponse)}`);
      }
    } catch (error: any) {
      console.error("Error en RapydController.getIdentityStatus:", error);
      res.status(500).json({
        error: `Error obteniendo estado: ${error.response ? error.response.status : ''} - ${
          error.response ? JSON.stringify(error.response.data) : error.message
        }`
      });
    }
  }
}