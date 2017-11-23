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
  ) public {
        LPPDac dac = new LPPDac(_liquidPledging, tokenName, tokenSymbol);
        dac.init(name, url, commitTime);
        dac.changeOwnership(msg.sender);
    }
}
