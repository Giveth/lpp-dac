pragma solidity ^0.4.18;

import "./LPPDac.sol";
import "minimetoken/contracts/MiniMeToken.sol";
import "@aragon/os/contracts/factory/AppProxyFactory.sol";
import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/acl/ACL.sol";
import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/LPConstants.sol";


contract LPPDacFactory is LPConstants, VaultRecoverable, AppProxyFactory {
    Kernel public kernel;
    MiniMeTokenFactory public tokenFactory;

    bytes32 constant public DAC_APP_ID = keccak256("lpp-dac");
    bytes32 constant public DAC_APP = keccak256(APP_BASES_NAMESPACE, DAC_APP_ID);
    bytes32 constant public LP_APP_INSTANCE = keccak256(APP_ADDR_NAMESPACE, LP_APP_ID);

    event DeployDac(address dac);

    function LPPDacFactory(address _kernel, address _tokenFactory) public 
    {
        // note: this contract will need CREATE_PERMISSIONS_ROLE on the ACL
        // and the PLUGIN_MANAGER_ROLE on liquidPledging,
        // the DAC_APP and LP_APP_INSTANCE need to be registered with the kernel

        require(_kernel != 0x0);
        require(_tokenFactory != 0x0);
        kernel = Kernel(_kernel);
        tokenFactory = MiniMeTokenFactory(_tokenFactory);
    }

    function newDac(
        string name,
        string url,
        uint64 commitTime,
        string tokenName,
        string tokenSymbol
    ) public
    { 
        // TODO: could make MiniMeToken an AragonApp to save gas by deploying a proxy
        MiniMeToken token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);
        newDac(name, url, commitTime, token);
    }

    /**
    * @param token The token this dac will mint. This contract must be the TokenController
    */
    function newDac(
        string name,
        string url,
        uint64 commitTime,
        MiniMeToken token
    ) public
    {
        address dacBase = kernel.getApp(DAC_APP);
        require(dacBase != 0);
        address liquidPledging = kernel.getApp(LP_APP_INSTANCE);
        require(liquidPledging != 0);

        LPPDac dac = LPPDac(newAppProxy(kernel, DAC_APP_ID));

        LiquidPledging(liquidPledging).addValidPluginInstance(address(dac));

        dac.initialize(liquidPledging, token, name, url, commitTime);
        token.changeController(address(dac));

        ACL acl = ACL(kernel.acl());
        bytes32 adminRole = dac.ADMIN_ROLE();

        // this permission is managed by msg.sender
        acl.createPermission(msg.sender, address(dac), adminRole, msg.sender);

        DeployDac(address(dac));
    }

    function getRecoveryVault() public view returns (address) {
        return kernel.getRecoveryVault();
    }
}
