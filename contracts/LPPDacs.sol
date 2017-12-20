pragma solidity ^0.4.17;

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
import "giveth-common-contracts/contracts/Escapable.sol";
import "minimetoken/contracts/MiniMeToken.sol";


contract LPPDacs is Escapable, TokenController {
    uint constant FROM_FIRST_DELEGATE = 1;
    uint constant TO_FIRST_DELEGATE = 257;

    LiquidPledging public liquidPledging;

    struct Dac {
        MiniMeToken token;
        address owner;
    }

    mapping (uint64 => Dac) dacs;

    event GenerateTokens(uint64 indexed idDelegate, address addr, uint amount);
    event DestroyTokens(uint64 indexed idDelegate, address addr, uint amount);

    //== constructor

    function LPPDacs(
        LiquidPledging _liquidPledging,
        address _escapeHatchCaller,
        address _escapeHatchDestination
    ) Escapable(_escapeHatchCaller, _escapeHatchDestination) public
    {
        liquidPledging = _liquidPledging;
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
        uint amount
    ) external
    {
        require(msg.sender == address(liquidPledging));
        var (, toOwner, , toIntendedProject, , , toPledgeState ) = liquidPledging.getPledge(pledgeTo);
        var (, fromOwner, , , , , ) = liquidPledging.getPledge(pledgeFrom);
        var (toAdminType, toAddr, , , , , , ) = liquidPledging.getPledgeAdmin(toOwner);
        Dac storage d;
        uint64 idDelegate;

        // only issue tokens when pledge is committed to a project and a dac is the first delegate
        if (context == FROM_FIRST_DELEGATE &&
                toIntendedProject == 0 &&
                toAdminType == LiquidPledgingBase.PledgeAdminType.Project &&
                toOwner != fromOwner &&
                toPledgeState == LiquidPledgingBase.PledgeState.Pledged)
        {
            (idDelegate, , ) = liquidPledging.getPledgeDelegate(pledgeFrom, 1);
            d = dacs[idDelegate];

            require(address(d.token) != 0x0);

            var (, fromAddr , , , , , , ) = liquidPledging.getPledgeAdmin(fromOwner);

            d.token.generateTokens(fromAddr, amount);
            GenerateTokens(idDelegate, fromAddr, amount);
        }

        // if a committed project is canceled and the pledge is rolling back to a
        // dac, we need to burn the tokens that we're generated
        if ( (context == TO_FIRST_DELEGATE) &&
            liquidPledging.isProjectCanceled(fromOwner)) {
            (idDelegate, , ) = liquidPledging.getPledgeDelegate(pledgeTo, 1);
            d = dacs[idDelegate];

            require(address(d.token) != 0x0);

            if (d.token.balanceOf(toAddr) >= amount) {
                d.token.destroyTokens(toAddr, amount);
                DestroyTokens(fromOwner, toAddr, amount);
            }
        }
    }

    //== public

    function addDac(
        string name,
        string url,
        uint64 commitTime,
        string tokenName,
        string tokenSymbol
    ) public
    {
        uint64 idDelegate = liquidPledging.addDelegate(
            name,
            url,
            commitTime,
            ILiquidPledgingPlugin(this)
        );

        MiniMeTokenFactory tokenFactory = new MiniMeTokenFactory();
        MiniMeToken token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);

        dacs[idDelegate] = Dac(token, msg.sender);
    }

    function addDac(
        string name,
        string url,
        uint64 commitTime,
        MiniMeToken token
    ) public
    {
        uint64 idDelegate = liquidPledging.addDelegate(
          name,
          url,
          commitTime,
          ILiquidPledgingPlugin(this)
        );

        dacs[idDelegate] = Dac(token, msg.sender);
    }

    function transfer(
        uint64 idDelegate,
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) public
    {
        Dac storage d = dacs[idDelegate];
        require(msg.sender == d.owner);

        liquidPledging.transfer(
            idDelegate,
            idPledge,
            amount,
            idReceiver
        );
    }

    function getDac(uint64 idDelegate) public view returns (
        MiniMeToken token,
        address owner
    )
    {
        Dac storage d = dacs[idDelegate];
        token = d.token;
        owner = d.owner;
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
