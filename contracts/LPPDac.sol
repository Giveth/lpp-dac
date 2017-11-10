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

    LiquidPledging public liquidPledging;
    MiniMeToken public token;
    uint64 public idProject;

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
        var (, toOwner, , intendedProject, , , toPaymentState ) = liquidPledging.getPledge(pledgeTo);
        var (, fromOwner, , , , , ) = liquidPledging.getPledge(pledgeFrom);
        var (adminType, , , , , , , ) = liquidPledging.getPledgeAdmin(toOwner);

        // only issue tokens when pledge is committed to a project and this contract is the first delegate
        if ( (context == FROM_FIRST_DELEGATE) &&
                ( intendedProject == 0 ) &&
                ( adminType == LiquidPledgingBase.PledgeAdminType.Project ) &&
                ( toOwner != fromOwner ) &&
                ( toPaymentState == LiquidPledgingBase.PaymentState.Pledged )) {
            var (, addr , , , , , , ) = liquidPledging.getPledgeAdmin(fromOwner);
            token.generateTokens(addr, amount);
        }
    }

    function cancelDAC() public onlyOwner {
        require( !isCanceled() );

        liquidPledging.cancelProject(idProject);
    }

    function transfer(uint64 idSender, uint64 idPledge, uint amount, uint64 idReceiver) public onlyOwner {
      require( !isCanceled() );

      liquidPledging.transfer(idSender, idPledge, amount, idReceiver);
    }

    function isCanceled() public view returns (bool) {
      return liquidPledging.isProjectCanceled(idProject);
    }
}
