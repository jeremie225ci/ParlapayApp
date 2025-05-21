"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransactionStatus = exports.TransactionType = void 0;
var TransactionType;
(function (TransactionType) {
    TransactionType["TOPUP"] = "topup";
    TransactionType["WITHDRAW"] = "withdraw";
    TransactionType["P2P_SENT"] = "p2p_sent";
    TransactionType["P2P_RECEIVED"] = "p2p_received";
    TransactionType["FEE"] = "fee";
    TransactionType["REFUND"] = "refund";
    TransactionType["OTHER"] = "other"; // Autre
})(TransactionType = exports.TransactionType || (exports.TransactionType = {}));
var TransactionStatus;
(function (TransactionStatus) {
    TransactionStatus["PENDING"] = "pending";
    TransactionStatus["COMPLETED"] = "completed";
    TransactionStatus["FAILED"] = "failed";
    TransactionStatus["CANCELLED"] = "cancelled";
})(TransactionStatus = exports.TransactionStatus || (exports.TransactionStatus = {}));
//# sourceMappingURL=Transaction.js.map