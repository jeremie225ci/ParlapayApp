import { Request, Response } from 'express';
import { getRapyd } from '../services/rapyd_init';
import { getFirestore } from 'firebase-admin/firestore';

const db = getFirestore();

export class KYCController {
  async processKYC(req: Request, res: Response): Promise<void> {
    try {
      console.log("Iniciando procesamiento de KYC:", req.body);
      const { userId, firstName, lastName, email, birthDate, address, city, postalCode, country } = req.body;
      
      if (!userId) {
        res.status(400).json({ error: "UserId es requerido" });
        return;
      }
      
      // NUEVO: Verificar primero si el usuario ya tiene una wallet en Rapyd
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      const walletData = walletDoc.exists ? walletDoc.data() as any : null;
      
      if (walletData && walletData.walletId) {
        console.log(`El usuario ${userId} ya tiene una wallet con ID ${walletData.walletId}`);
        
        // Solo actualizar el estado KYC
        await walletRef.update({
          kycStatus: 'approved',
          kycApprovedAt: new Date(),
          kycCompleted: true,
          firstName: firstName,
          lastName: lastName,
          email: email,
          birthDate: birthDate,
          address: address,
          city: city,
          postalCode: postalCode,
          country: country,
          pendingSyncWithRapyd: false
        });
        
        res.status(200).json({
          success: true,
          message: 'KYC aprobado y wallet existente conectada',
          kycStatus: 'approved',
          walletId: walletData.walletId
        });
        return;
      }
      
      // Preparar el cuerpo de la solicitud para Rapyd (formato wallet)
      const rapydBody = {
        first_name: firstName,
        last_name: lastName,
        ewallet_reference_id: userId,
        type: "person",
        contact: {
          phone_number: req.body.phoneNumber || "",
          email: email,
          first_name: firstName,
          last_name: lastName,
          contact_type: "personal",
          address: {
            name: `${firstName} ${lastName}`,
            line_1: address || "",
            city: city || "",
            state: "",
            country: country || "ES",
            zip: postalCode || "",
            phone_number: req.body.phoneNumber || ""
          },
          identification_type: req.body.identificationType || "passport",
          identification_number: req.body.identificationNumber || "",
          date_of_birth: birthDate ? birthDate.split('T')[0] : "",
          country: country || "ES",
          nationality: req.body.nationality || country || "ES"
        },
        metadata: {
          iban: req.body.iban || "",
          gender: req.body.gender || "male",
          userId: userId
        }
      };
      
      console.log("Datos preparados para Rapyd:", JSON.stringify(rapydBody));
      
      // Obtener la instancia de Rapyd y crear el wallet
      const rapydService = getRapyd();
      const rapydResponse = await rapydService.createWallet(rapydBody);
      
      console.log("Respuesta recibida de Rapyd:", rapydResponse);
      
      if (rapydResponse && rapydResponse.status && rapydResponse.status.status === 'SUCCESS') {
        // Actualizar en Firestore
        if (walletDoc.exists) {
          await walletRef.update({
            kycStatus: 'processing',
            kycInitiatedAt: new Date(),
            firstName: firstName,
            lastName: lastName,
            email: email,
            birthDate: birthDate,
            address: address,
            city: city,
            postalCode: postalCode,
            country: country,
            walletId: rapydResponse.data.id || null,
            pendingSyncWithRapyd: false
          });
        } else {
          // Si no existe, crear un nuevo documento
          await walletRef.set({
            userId: userId,
            kycStatus: 'processing',
            kycInitiatedAt: new Date(),
            firstName: firstName,
            lastName: lastName,
            email: email,
            birthDate: birthDate,
            address: address,
            city: city,
            postalCode: postalCode,
            country: country,
            walletId: rapydResponse.data.id || null,
            pendingSyncWithRapyd: false,
            balance: 0.0,
            createdAt: new Date()
          });
        }
        
        console.log(`Wallet actualizada para usuario ${userId}`);
        
        res.status(200).json({
          success: true,
          message: 'KYC iniciado correctamente',
          kycStatus: 'processing',
          walletId: rapydResponse.data.id || null
        });
      } else {
        throw new Error(`Error de Rapyd: ${JSON.stringify(rapydResponse)}`);
      }
    } catch (error: any) {
      console.error('Error en KYCController.processKYC:', error);
      
      // Manejo especial para el error de referencia duplicada
      if (error.message && error.message.includes('ERROR_CREATE_USER_EWALLET_REFERENCE_ID_ALREADY_EXISTS')) {
        // Intentar obtener la wallet actual desde Rapyd
        try {
          const { userId } = req.body;
          const rapydService = getRapyd();
          
          // Obtener todas las wallets del usuario (esto es una adaptación - en un entorno real
          // necesitarías una API de Rapyd para obtener wallet por reference_id)
          console.log("Intentando recuperar la wallet existente para el usuario:", userId);
          
          // En este punto, no tenemos la wallet ID directamente
          // Actualizamos el estado en Firestore para indicar que necesita sincronización
          const walletRef = db.collection('wallets').doc(userId);
          const walletDoc = await walletRef.get();
          
          if (walletDoc.exists) {
            await walletRef.update({
              kycStatus: 'processing',
              kycInitiatedAt: new Date(),
              firstName: req.body.firstName,
              lastName: req.body.lastName,
              email: req.body.email,
              birthDate: req.body.birthDate,
              address: req.body.address,
              city: req.body.city,
              postalCode: req.body.postalCode,
              country: req.body.country,
              // No podemos establecer walletId aquí porque no lo sabemos
              pendingSyncWithRapyd: true
            });
          } else {
            await walletRef.set({
              userId: userId,
              kycStatus: 'processing',
              kycInitiatedAt: new Date(),
              firstName: req.body.firstName,
              lastName: req.body.lastName,
              email: req.body.email,
              birthDate: req.body.birthDate,
              address: req.body.address,
              city: req.body.city,
              postalCode: req.body.postalCode,
              country: req.body.country,
              pendingSyncWithRapyd: true,
              balance: 0.0,
              createdAt: new Date()
            });
          }
          
          // Responder que necesita sincronización
          res.status(200).json({
            success: true,
            message: 'Wallet ya existe en Rapyd. Debe sincronizarse para obtener el ID.',
            kycStatus: 'processing',
            needsSync: true
          });
          
        } catch (syncError) {
          console.error("Error al intentar recuperar wallet existente:", syncError);
          res.status(500).json({
            error: "La wallet ya existe pero no se pudo recuperar. Contacte al soporte."
          });
        }
      } else {
        // Otros errores
        res.status(500).json({
          error: `Error de Rapyd: ${error.response ? error.response.status : ''} - ${
            error.response ? JSON.stringify(error.response.data) : error.message
          }`
        });
      }
    }
  }
  async checkKYCStatus(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.params.userId;
      console.log(`Obteniendo estado KYC para usuario: ${userId}`);
      
      // Obtener datos de wallet de Firestore
      const walletRef = db.collection('wallets').doc(userId);
      const walletDoc = await walletRef.get();
      
      if (!walletDoc.exists) {
        res.status(404).json({ error: "Wallet no encontrada" });
        return;
      }
      
      const walletData = walletDoc.data() as any;
      
      // Si tenemos un walletId, obtener info de Rapyd
      if (walletData.walletId) {
        const rapydService = getRapyd();
        
        console.log(`Consultando wallet en Rapyd: ${walletData.walletId}`);
        
        try {
          const rapydData = await rapydService.getWallet(walletData.walletId);
          
          console.log("Respuesta de Rapyd:", rapydData);
          
          // Actualizar status si es necesario basado en respuesta de Rapyd
          let kycStatus = walletData.kycStatus;
          if (rapydData && rapydData.data && rapydData.data.status) {
            const rapydStatus = rapydData.data.status.toLowerCase();
            
            if (rapydStatus === 'act') {
              kycStatus = 'approved';
              // Actualizar en Firestore
              await walletRef.update({
                kycStatus: 'approved',
                kycApprovedAt: new Date(),
                kycCompleted: true,
                accountStatus: 'active'
              });
            } else if (rapydStatus === 'rej') {
              kycStatus = 'rejected';
              await walletRef.update({
                kycStatus: 'rejected'
              });
            }
          }
          
          res.status(200).json({
            success: true,
            kycStatus: kycStatus,
            walletId: walletData.walletId,
            rapydStatus: rapydData.data.status || 'unknown'
          });
        } catch (rapydError: any) {
          console.error("Error consultando Rapyd:", rapydError);
          // Si hay error con Rapyd, devolvemos lo que tenemos en Firestore
          res.status(200).json({
            success: true,
            kycStatus: walletData.kycStatus,
            walletId: walletData.walletId,
            offline: true,
            error: rapydError.message
          });
        }
      } else {
        // Si no hay walletId, solo devolvemos el estado local
        res.status(200).json({
          success: true,
          kycStatus: walletData.kycStatus,
          pendingSyncWithRapyd: walletData.pendingSyncWithRapyd || true
        });
      }
    } catch (error: any) {
      console.error("Error en KYCController.checkKYCStatus:", error);
      res.status(500).json({ 
        error: error.message,
        stack: error.stack
      });
    }
  }
}