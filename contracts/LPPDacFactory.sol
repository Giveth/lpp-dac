pragma solidity ^0.4.13;

import "./LPPDac.sol";

contract LPPDacFactory {
    function deploy(
        LiquidPledging _liquidPledging,
        string name,
        string url,
        uint64 commitTime,
        string tokenName,
        string tokenSymbol
  ) {
        LPPDac dac = new LPPDac(tokenName, tokenSymbol);
        dac.init(_liquidPledging, name, url, commitTime);
        dac.changeOwnership(msg.sender);
    }
}
