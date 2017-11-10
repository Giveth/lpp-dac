const LPPDacABI = require('../build/LPPDac.sol').LPPDacAbi;
const LPPDacByteCode = require('../build/LPPDac.sol').LPPDacByteCode;
const generateClass = require('eth-contract-class').default;

module.exports = generateClass(LPPDacABI, LPPDacByteCode);
