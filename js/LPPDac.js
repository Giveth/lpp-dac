const LPPDacABI = require('../build/LPPDac.sol').LPPDacAbi;
const LPPDacByteCode = require('../build/LPPDac.sol').LPPDacByteCode;
const generateClass = require('eth-contract-class').default;

const LPPDac = generateClass(LPPDacABI, LPPDacByteCode);
// need to deploy via factory contract
delete LPPDac.new;

module.exports = LPPDac;
