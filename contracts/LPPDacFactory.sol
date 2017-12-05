pragma solidity ^0.4.13;

import "./LPPDac.sol";

contract LPPDacFactory is Escapable {

    function LPPDacFactory(address _escapeHatchCaller, address _escapeHatchDestination)
        Escapable(_escapeHatchCaller, _escapeHatchDestination)
    {
    }

    function deploy(
        LiquidPledging _liquidPledging,
        string name,
        string url,
        uint64 commitTime,
        string tokenName,
        string tokenSymbol,
        address _escapeHatchCaller,
        address _escapeHatchDestination
    ) public
    {
        LPPDac dac = new LPPDac(
            _liquidPledging,
            tokenName,
            tokenSymbol,
            _escapeHatchCaller,
            _escapeHatchDestination
        );
        dac.init(name, url, commitTime);
        dac.changeOwnership(msg.sender);
    }
}
