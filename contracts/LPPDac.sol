pragma solidity ^0.4.13;

import "../node_modules/liquidpledging/contracts/LiquidPledging.sol";
import "../node_modules/giveth-common-contracts/contracts/Owned.sol";
import "../node_modules/minimetoken/contracts/MiniMeToken.sol";

/// @title LPPDac
/// @author perissology <perissology@protonmail.com>
/// @notice The LPPDac contract is a plugin contract for liquidPledging,
///  extending the functionality of a liquidPledging delegate. This contract
///  mints tokens for the giver when the pledge is committed to a project and
///  this contract is the first delegate in the delegateChain
contract LPPDac is Owned, TokenController {
    uint constant FROM_FIRST_DELEGATE = 1;
    uint constant TO_FIRST_DELEGATE = 257;


    LiquidPledging public liquidPledging;
    MiniMeToken public token;
    uint64 public idProject;

    event GenerateTokens(address indexed liquidPledging, address addr, uint amount);

    function LPPDac(
        LiquidPledging _liquidPledging,
        string name,
        string url,
        uint64 commitTime,
        string tokenName,
        string tokenSymbol
    ) {
        liquidPledging = _liquidPledging;
        MiniMeTokenFactory tokenFactory = new MiniMeTokenFactory();
        token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);
        idProject = liquidPledging.addDelegate(name, url, commitTime, ILiquidPledgingPlugin(this));
    }

    function beforeTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        uint amount
    ) external returns (uint maxAllowed) {
        require(msg.sender == address(liquidPledging));
        return amount;
    }

    function afterTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        uint amount
    ) external {
        require(msg.sender == address(liquidPledging));
        var (, toOwner, , toIntendedProject, , , toPaymentState ) = liquidPledging.getPledge(pledgeTo);
        var (, fromOwner, , , , , ) = liquidPledging.getPledge(pledgeFrom);
        var (toAdminType, toAddr, , , , , , ) = liquidPledging.getPledgeAdmin(toOwner);

        // only issue tokens when pledge is committed to a project and this contract is the first delegate
        if ( (context == FROM_FIRST_DELEGATE) &&
                ( toIntendedProject == 0 ) &&
                ( toAdminType == LiquidPledgingBase.PledgeAdminType.Project ) &&
                ( toOwner != fromOwner ) &&
                ( toPaymentState == LiquidPledgingBase.PaymentState.Pledged )) {

            var (, fromAddr , , , , , , ) = liquidPledging.getPledgeAdmin(fromOwner);
            token.generateTokens(fromAddr, amount);
            GenerateTokens(liquidPledging, fromAddr, amount);
        }

        if ( (context == TO_FIRST_DELEGATE) &&
            liquidPledging.isProjectCanceled(fromOwner)) {
          if (token.balanceOf(toAddr) >= amount) {
            token.destroyTokens(toAddr, amount);
          }
        }
    }

    function transfer(uint64 idSender, uint64 idPledge, uint amount, uint64 idReceiver) public onlyOwner {
        liquidPledging.transfer(idSender, idPledge, amount, idReceiver);
    }

////////////////
// TokenController
////////////////

    /// @notice Called when `_owner` sends ether to the MiniMe Token contract
    /// @param _owner The address that sent the ether to create tokens
    /// @return True if the ether is accepted, false if it throws
    function proxyPayment(address _owner) public payable returns(bool) {
        return false;
    }

    /// @notice Notifies the controller about a token transfer allowing the
    ///  controller to react if desired
    /// @param _from The origin of the transfer
    /// @param _to The destination of the transfer
    /// @param _amount The amount of the transfer
    /// @return False if the controller does not authorize the transfer
    function onTransfer(address _from, address _to, uint _amount) public returns(bool) {
        return false;
    }

    /// @notice Notifies the controller about an approval allowing the
    ///  controller to react if desired
    /// @param _owner The address that calls `approve()`
    /// @param _spender The spender in the `approve()` call
    /// @param _amount The amount in the `approve()` call
    /// @return False if the controller does not authorize the approval
    function onApprove(address _owner, address _spender, uint _amount) public returns(bool) {
        return false;
    }
}
