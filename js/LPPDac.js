const LPPCampaignABI = require('../build/LPPDac.sol').LPPCampaignAbi;
const LPPCampaignByteCode = require('../build/LPPDac.sol').LPPCampaignByteCode;
const generateClass = require('eth-contract-class').default;

const LPPCampaign = generateClass(LPPCampaignABI, LPPCampaignByteCode);

LPPCampaign.prototype.getState = function () {
  return Promise.all([
    this.liquidPledging(),
    this.idProject(),
    this.reviewer(),
    this.newReviewer(),
    this.isCanceled(),
  ])
  .then(results => ({
    liquidPledging: results[0],
    idProject: results[1],
    reviewer: results[2],
    newReviewer: results[3],
    canceled: results[4],
  }));
};

module.exports = LPPCampaign;
