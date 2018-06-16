const factoryArtifact = require('./build/LPPDacFactory.json');
const dacArtifact = require('./build/LPPDac.json');
const generateClass = require('eth-contract-class').default;

module.exports = {
  LPPDac: generateClass(
    dacArtifact.compilerOutput.abi,
    dacArtifact.compilerOutput.evm.bytecode.object,
  ),
  LPPDacFactory: generateClass(
    factoryArtifact.compilerOutput.abi,
    factoryArtifact.compilerOutput.evm.bytecode.object,
  ),
};
