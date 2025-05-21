import express from "express"
import { KYCController } from "../controllers/kyc_controller"

const router = express.Router()
const kycController = new KYCController()

// Procesar formulario KYC
router.post("/process", (req, res) => kycController.processKYC(req, res))

// Verificar estado de KYC
router.get("/status/:userId", (req, res) => kycController.checkKYCStatus(req, res))

export default router
