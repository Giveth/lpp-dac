const contractInfo = require('./build/LPPDacFactory.sol'); // const LPPDacsByteCode = require('../build/LPPDacs.sol').LPPDacsByteCode;
const generateClass = require('eth-contract-class').default;

module.exports = {
  LPPDac: generateClass(contractInfo.LPPDacABI, contractInfo.LPPDacByteCode),
  LPPDacFactory: generateClass(contractInfo.LPPDacFactoryABI, contractInfo.LPPDacFactoryByteCode),
};