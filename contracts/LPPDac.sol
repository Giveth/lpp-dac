pragma solidity ^0.4.18;

/*
    Copyright 2017, RJ Ewing <perissology@protonmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/EscapableApp.sol";
import "minimetoken/contracts/MiniMeToken.sol";

contract LPPDac is EscapableApp, TokenController {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint constant FROM_FIRST_DELEGATE = 1;
    uint constant TO_FIRST_DELEGATE = 257;

    LiquidPledging public liquidPledging;
    MiniMeToken public dacToken;
    uint64 public idDelegate;

    event GenerateTokens(address indexed liquidPledging, address addr, uint amount);
    event DestroyTokens(address indexed liquidPledging, address addr, uint amount);

    //== constructor

    function LPPDac(address _escapeHatchDestination) EscapableApp(_escapeHatchDestination) public {}

    function initialize(address _escapeHatchDestination) onlyInit public {
        require(false); // overload the EscapableApp
        _escapeHatchDestination;
    }

    function initialize(
        address _liquidPledging,
        address _token,
        string name,
        string url,
        uint64 commitTime,
        address _escapeHatchDestination
    ) onlyInit external
    {
        super.initialize(_escapeHatchDestination);
        require(_liquidPledging != 0);
        require(_token != 0);

        liquidPledging = LiquidPledging(_liquidPledging);

        idDelegate = liquidPledging.addDelegate(
            name,
            url,
            commitTime,
            ILiquidPledgingPlugin(this)
        );

        dacToken = MiniMeToken(_token);
    }

    //== external

    /// @dev this is called by liquidPledging before every transfer to and from
    ///      a pledgeAdmin that has this contract as its plugin
    /// @dev see ILiquidPledgingPlugin interface for details about context param
    function beforeTransfer(
        uint64 pledgeManager,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) external returns (uint maxAllowed)
    {
        require(msg.sender == address(liquidPledging));
        return amount;
    }

    /// @dev this is called by liquidPledging after every transfer to and from
    ///      a pledgeAdmin that has this contract as its plugin
    /// @dev see ILiquidPledgingPlugin interface for details about context param
    function afterTransfer(
        uint64 pledgeManager,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) external
    {
        require(msg.sender == address(liquidPledging));
        var (, toOwner, , toIntendedProject, , , , toPledgeState ) = liquidPledging.getPledge(pledgeTo);
        var (, fromOwner, , , , , , ) = liquidPledging.getPledge(pledgeFrom);
        var (toAdminType, toAddr, , , , , , ) = liquidPledging.getPledgeAdmin(toOwner);

        // only issue dacTokens when pledge is committed to a project and a dac is the first delegate
        if (context == FROM_FIRST_DELEGATE &&
                toIntendedProject == 0 &&
                toAdminType == LiquidPledgingStorage.PledgeAdminType.Project &&
                toOwner != fromOwner &&
                toPledgeState == LiquidPledgingStorage.PledgeState.Pledged)
        {
            var (, fromAddr , , , , , , ) = liquidPledging.getPledgeAdmin(fromOwner);

            dacToken.generateTokens(fromAddr, amount);
            GenerateTokens(address(liquidPledging), fromAddr, amount);
        }

        // if a committed project is canceled and the pledge is rolling back to a
        // dac, we need to burn the tokens that were generated
        if ( (context == TO_FIRST_DELEGATE) &&
            liquidPledging.isProjectCanceled(fromOwner)) {

            if (dacToken.balanceOf(toAddr) >= amount) {
                dacToken.destroyTokens(toAddr, amount);
                DestroyTokens(address(liquidPledging), toAddr, amount);
            }

        }
    }

    function transfer(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) external authP(ADMIN_ROLE, arr(uint(idPledge), amount, uint(idReceiver)))
    {
        liquidPledging.transfer(
            idDelegate,
            idPledge,
            amount,
            idReceiver
        );
    }

    function update(
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) public auth(ADMIN_ROLE)
    {
        liquidPledging.updateDelegate(
            idDelegate,
            address(this),
            newName,
            newUrl,
            newCommitTime
        );
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
