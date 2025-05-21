"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const kyc_controller_1 = require("../controllers/kyc_controller");
const router = express_1.default.Router();
const kycController = new kyc_controller_1.KYCController();
// Procesar formulario KYC
router.post("/process", (req, res) => kycController.processKYC(req, res));
// Verificar estado de KYC
router.get("/status/:userId", (req, res) => kycController.checkKYCStatus(req, res));
exports.default = router;
//# sourceMappingURL=kyc_routes.js.map