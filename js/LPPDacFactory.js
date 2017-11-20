const LPPDacFactoryABI = require('../build/LPPDacFactory.sol').LPPDacFactoryAbi;
const LPPDacFactoryByteCode = require('../build/LPPDacFactory.sol').LPPDacFactoryByteCode;
const generateClass = require('eth-contract-class').default;

module.exports = generateClass(LPPDacFactoryABI, LPPDacFactoryByteCode);
