const LPPDacsABI = require('../build/LPPDacs.sol').LPPDacsAbi;
const LPPDacsByteCode = require('../build/LPPDacs.sol').LPPDacsByteCode;
const generateClass = require('eth-contract-class').default;

const LPPDacs = generateClass(LPPDacsABI, LPPDacsByteCode);

module.exports = LPPDacs;
