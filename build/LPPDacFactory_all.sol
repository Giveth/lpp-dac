

///File: giveth-liquidpledging/contracts/ILiquidPledgingPlugin.sol

pragma solidity ^0.4.11;

/*
    Copyright 2017, Jordi Baylina
    Contributors: Adrià Massanet <adria@codecontext.io>, RJ Ewing, Griff
    Green, Arthur Lunn

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


/// @dev `ILiquidPledgingPlugin` is the basic interface for any
///  liquid pledging plugin
contract ILiquidPledgingPlugin {

    /// @notice Plugins are used (much like web hooks) to initiate an action
    ///  upon any donation, delegation, or transfer; this is an optional feature
    ///  and allows for extreme customization of the contract. This function
    ///  implements any action that should be initiated before a transfer.
    /// @param pledgeManager The admin or current manager of the pledge
    /// @param pledgeFrom This is the Id from which value will be transfered.
    /// @param pledgeTo This is the Id that value will be transfered to.    
    /// @param context The situation that is triggering the plugin:
    ///  0 -> Plugin for the owner transferring pledge to another party
    ///  1 -> Plugin for the first delegate transferring pledge to another party
    ///  2 -> Plugin for the second delegate transferring pledge to another party
    ///  ...
    ///  255 -> Plugin for the intendedProject transferring pledge to another party
    ///
    ///  256 -> Plugin for the owner receiving pledge to another party
    ///  257 -> Plugin for the first delegate receiving pledge to another party
    ///  258 -> Plugin for the second delegate receiving pledge to another party
    ///  ...
    ///  511 -> Plugin for the intendedProject receiving pledge to another party
    /// @param amount The amount of value that will be transfered.
    function beforeTransfer(
        uint64 pledgeManager,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount ) public returns (uint maxAllowed);

    /// @notice Plugins are used (much like web hooks) to initiate an action
    ///  upon any donation, delegation, or transfer; this is an optional feature
    ///  and allows for extreme customization of the contract. This function
    ///  implements any action that should be initiated after a transfer.
    /// @param pledgeManager The admin or current manager of the pledge
    /// @param pledgeFrom This is the Id from which value will be transfered.
    /// @param pledgeTo This is the Id that value will be transfered to.    
    /// @param context The situation that is triggering the plugin:
    ///  0 -> Plugin for the owner transferring pledge to another party
    ///  1 -> Plugin for the first delegate transferring pledge to another party
    ///  2 -> Plugin for the second delegate transferring pledge to another party
    ///  ...
    ///  255 -> Plugin for the intendedProject transferring pledge to another party
    ///
    ///  256 -> Plugin for the owner receiving pledge to another party
    ///  257 -> Plugin for the first delegate receiving pledge to another party
    ///  258 -> Plugin for the second delegate receiving pledge to another party
    ///  ...
    ///  511 -> Plugin for the intendedProject receiving pledge to another party
    ///  @param amount The amount of value that will be transfered.
    function afterTransfer(
        uint64 pledgeManager,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) public;
}


///File: giveth-liquidpledging/contracts/LiquidPledgingStorage.sol

pragma solidity ^0.4.18;



/// @dev This is an interface for `LPVault` which serves as a secure storage for
///  the ETH that backs the Pledges, only after `LiquidPledging` authorizes
///  payments can Pledges be converted for ETH
interface ILPVault {
    function authorizePayment(bytes32 _ref, address _dest, address _token, uint _amount) public;
}

/// This contract contains all state variables used in LiquidPledging contracts
/// This is done to have everything in 1 location, b/c state variable layout
/// is MUST have be the same when performing an upgrade.
contract LiquidPledgingStorage {
    enum PledgeAdminType { Giver, Delegate, Project }
    enum PledgeState { Pledged, Paying, Paid }

    /// @dev This struct defines the details of a `PledgeAdmin` which are 
    ///  commonly referenced by their index in the `admins` array
    ///  and can own pledges and act as delegates
    struct PledgeAdmin { 
        PledgeAdminType adminType; // Giver, Delegate or Project
        address addr; // Account or contract address for admin
        uint64 commitTime;  // In seconds, used for time Givers' & Delegates' have to veto
        uint64 parentProject;  // Only for projects
        bool canceled;      //Always false except for canceled projects

        /// @dev if the plugin is 0x0 then nothing happens, if its an address
        // than that smart contract is called when appropriate
        ILiquidPledgingPlugin plugin; 
        string name;
        string url;  // Can be IPFS hash
    }

    struct Pledge {
        uint amount;
        uint64[] delegationChain; // List of delegates in order of authority
        uint64 owner; // PledgeAdmin
        uint64 intendedProject; // Used when delegates are sending to projects
        uint64 commitTime;  // When the intendedProject will become the owner
        uint64 oldPledge; // Points to the id that this Pledge was derived from
        address token;
        PledgeState pledgeState; //  Pledged, Paying, Paid
    }

    PledgeAdmin[] admins; //The list of pledgeAdmins 0 means there is no admin
    Pledge[] pledges;
    /// @dev this mapping allows you to search for a specific pledge's 
    ///  index number by the hash of that pledge
    mapping (bytes32 => uint64) hPledge2idx;

    // this whitelist is for non-proxied plugins
    mapping (bytes32 => bool) pluginContractWhitelist;
    // this whitelist is for proxied plugins
    mapping (address => bool) pluginInstanceWhitelist;
    bool public whitelistDisabled = false;

    ILPVault public vault;

    // reserve 50 slots for future upgrades. I'm not sure if this is necessary 
    // but b/c of multiple inheritance used in lp, better safe then sorry.
    // especially since it is free
    uint[50] private storageOffset;
}

///File: @aragon/os/contracts/acl/IACL.sol

pragma solidity ^0.4.18;


interface IACL {
    function initialize(address permissionsCreator) public;
    function hasPermission(address who, address where, bytes32 what, bytes how) public view returns (bool);
}


///File: @aragon/os/contracts/kernel/IKernel.sol

pragma solidity ^0.4.18;



interface IKernel {
    event SetApp(bytes32 indexed namespace, bytes32 indexed name, bytes32 indexed id, address app);

    function acl() public view returns (IACL);
    function hasPermission(address who, address where, bytes32 what, bytes how) public view returns (bool);

    function setApp(bytes32 namespace, bytes32 name, address app) public returns (bytes32 id);
    function getApp(bytes32 id) public view returns (address);
}

///File: @aragon/os/contracts/apps/AppStorage.sol

pragma solidity ^0.4.18;




contract AppStorage {
    IKernel public kernel;
    bytes32 public appId;
    address internal pinnedCode; // used by Proxy Pinned
    uint256 internal initializationBlock; // used by Initializable
    uint256[95] private storageOffset; // forces App storage to start at after 100 slots
    uint256 private offset;
}


///File: @aragon/os/contracts/common/Initializable.sol

pragma solidity ^0.4.18;




contract Initializable is AppStorage {
    modifier onlyInit {
        require(initializationBlock == 0);
        _;
    }

    /**
    * @return Block number in which the contract was initialized
    */
    function getInitializationBlock() public view returns (uint256) {
        return initializationBlock;
    }

    /**
    * @dev Function to be called by top level contract after initialization has finished.
    */
    function initialized() internal onlyInit {
        initializationBlock = getBlockNumber();
    }

    /**
    * @dev Returns the current block number.
    *      Using a function rather than `block.number` allows us to easily mock the block number in
    *      tests.
    */
    function getBlockNumber() internal view returns (uint256) {
        return block.number;
    }
}


///File: @aragon/os/contracts/evmscript/IEVMScriptExecutor.sol

pragma solidity ^0.4.18;


interface IEVMScriptExecutor {
    function execScript(bytes script, bytes input, address[] blacklist) external returns (bytes);
}


///File: @aragon/os/contracts/evmscript/IEVMScriptRegistry.sol

pragma solidity 0.4.18;


contract EVMScriptRegistryConstants {
    bytes32 constant public EVMSCRIPT_REGISTRY_APP_ID = keccak256("evmreg.aragonpm.eth");
    bytes32 constant public EVMSCRIPT_REGISTRY_APP = keccak256(keccak256("app"), EVMSCRIPT_REGISTRY_APP_ID);
}


interface IEVMScriptRegistry {
    function addScriptExecutor(address executor) external returns (uint id);
    function disableScriptExecutor(uint256 executorId) external;

    function getScriptExecutor(bytes script) public view returns (address);
}

///File: @aragon/os/contracts/evmscript/ScriptHelpers.sol

pragma solidity 0.4.18;


library ScriptHelpers {
    // To test with JS and compare with actual encoder. Maintaining for reference.
    // t = function() { return IEVMScriptExecutor.at('0x4bcdd59d6c77774ee7317fc1095f69ec84421e49').contract.execScript.getData(...[].slice.call(arguments)).slice(10).match(/.{1,64}/g) }
    // run = function() { return ScriptHelpers.new().then(sh => { sh.abiEncode.call(...[].slice.call(arguments)).then(a => console.log(a.slice(2).match(/.{1,64}/g)) ) }) }
    // This is truly not beautiful but lets no daydream to the day solidity gets reflection features

    function abiEncode(bytes _a, bytes _b, address[] _c) public pure returns (bytes d) {
        return encode(_a, _b, _c);
    }

    function encode(bytes memory _a, bytes memory _b, address[] memory _c) internal pure returns (bytes memory d) {
        // A is positioned after the 3 position words
        uint256 aPosition = 0x60;
        uint256 bPosition = aPosition + 32 * abiLength(_a);
        uint256 cPosition = bPosition + 32 * abiLength(_b);
        uint256 length = cPosition + 32 * abiLength(_c);

        d = new bytes(length);
        assembly {
            // Store positions
            mstore(add(d, 0x20), aPosition)
            mstore(add(d, 0x40), bPosition)
            mstore(add(d, 0x60), cPosition)
        }

        // Copy memory to correct position
        copy(d, getPtr(_a), aPosition, _a.length);
        copy(d, getPtr(_b), bPosition, _b.length);
        copy(d, getPtr(_c), cPosition, _c.length * 32); // 1 word per address
    }

    function abiLength(bytes memory _a) internal pure returns (uint256) {
        // 1 for length +
        // memory words + 1 if not divisible for 32 to offset word
        return 1 + (_a.length / 32) + (_a.length % 32 > 0 ? 1 : 0);
    }

    function abiLength(address[] _a) internal pure returns (uint256) {
        // 1 for length + 1 per item
        return 1 + _a.length;
    }

    function copy(bytes _d, uint256 _src, uint256 _pos, uint256 _length) internal pure {
        uint dest;
        assembly {
            dest := add(add(_d, 0x20), _pos)
        }
        memcpy(dest, _src, _length + 32);
    }

    function getPtr(bytes memory _x) internal pure returns (uint256 ptr) {
        assembly {
            ptr := _x
        }
    }

    function getPtr(address[] memory _x) internal pure returns (uint256 ptr) {
        assembly {
            ptr := _x
        }
    }

    function getSpecId(bytes _script) internal pure returns (uint32) {
        return uint32At(_script, 0);
    }

    function uint256At(bytes _data, uint256 _location) internal pure returns (uint256 result) {
        assembly {
            result := mload(add(_data, add(0x20, _location)))
        }
    }

    function addressAt(bytes _data, uint256 _location) internal pure returns (address result) {
        uint256 word = uint256At(_data, _location);

        assembly {
            result := div(and(word, 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000),
            0x1000000000000000000000000)
        }
    }

    function uint32At(bytes _data, uint256 _location) internal pure returns (uint32 result) {
        uint256 word = uint256At(_data, _location);

        assembly {
            result := div(and(word, 0xffffffff00000000000000000000000000000000000000000000000000000000),
            0x100000000000000000000000000000000000000000000000000000000)
        }
    }

    function locationOf(bytes _data, uint256 _location) internal pure returns (uint256 result) {
        assembly {
            result := add(_data, add(0x20, _location))
        }
    }

    function toBytes(bytes4 _sig) internal pure returns (bytes) {
        bytes memory payload = new bytes(4);
        payload[0] = bytes1(_sig);
        payload[1] = bytes1(_sig << 8);
        payload[2] = bytes1(_sig << 16);
        payload[3] = bytes1(_sig << 24);
        return payload;
    }

    function memcpy(uint _dest, uint _src, uint _len) public pure {
        uint256 src = _src;
        uint256 dest = _dest;
        uint256 len = _len;

        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
}

///File: @aragon/os/contracts/evmscript/EVMScriptRunner.sol

pragma solidity ^0.4.18;








contract EVMScriptRunner is AppStorage, EVMScriptRegistryConstants {
    using ScriptHelpers for bytes;

    function runScript(bytes _script, bytes _input, address[] _blacklist) protectState internal returns (bytes output) {
        // TODO: Too much data flying around, maybe extracting spec id here is cheaper
        address executorAddr = getExecutor(_script);
        require(executorAddr != address(0));

        bytes memory calldataArgs = _script.encode(_input, _blacklist);
        bytes4 sig = IEVMScriptExecutor(0).execScript.selector;

        require(executorAddr.delegatecall(sig, calldataArgs));

        return returnedDataDecoded();
    }

    function getExecutor(bytes _script) public view returns (IEVMScriptExecutor) {
        return IEVMScriptExecutor(getExecutorRegistry().getScriptExecutor(_script));
    }

    // TODO: Internal
    function getExecutorRegistry() internal view returns (IEVMScriptRegistry) {
        address registryAddr = kernel.getApp(EVMSCRIPT_REGISTRY_APP);
        return IEVMScriptRegistry(registryAddr);
    }

    /**
    * @dev copies and returns last's call data. Needs to ABI decode first
    */
    function returnedDataDecoded() internal view returns (bytes ret) {
        assembly {
            let size := returndatasize
            switch size
            case 0 {}
            default {
                ret := mload(0x40) // free mem ptr get
                mstore(0x40, add(ret, add(size, 0x20))) // free mem ptr set
                returndatacopy(ret, 0x20, sub(size, 0x20)) // copy return data
            }
        }
        return ret;
    }

    modifier protectState {
        address preKernel = kernel;
        bytes32 preAppId = appId;
        _; // exec
        require(kernel == preKernel);
        require(appId == preAppId);
    }
}

///File: @aragon/os/contracts/acl/ACLSyntaxSugar.sol

pragma solidity 0.4.18;


contract ACLSyntaxSugar {
    function arr() internal pure returns (uint256[] r) {}

    function arr(bytes32 _a) internal pure returns (uint256[] r) {
        return arr(uint256(_a));
    }

    function arr(bytes32 _a, bytes32 _b) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b));
    }

    function arr(address _a) internal pure returns (uint256[] r) {
        return arr(uint256(_a));
    }

    function arr(address _a, address _b) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b));
    }

    function arr(address _a, uint256 _b, uint256 _c) internal pure returns (uint256[] r) {
        return arr(uint256(_a), _b, _c);
    }

    function arr(address _a, uint256 _b) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b));
    }

    function arr(address _a, address _b, uint256 _c, uint256 _d, uint256 _e) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b), _c, _d, _e);
    }

    function arr(address _a, address _b, address _c) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b), uint256(_c));
    }

    function arr(address _a, address _b, uint256 _c) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b), uint256(_c));
    }

    function arr(uint256 _a) internal pure returns (uint256[] r) {
        r = new uint256[](1);
        r[0] = _a;
    }

    function arr(uint256 _a, uint256 _b) internal pure returns (uint256[] r) {
        r = new uint256[](2);
        r[0] = _a;
        r[1] = _b;
    }

    function arr(uint256 _a, uint256 _b, uint256 _c) internal pure returns (uint256[] r) {
        r = new uint256[](3);
        r[0] = _a;
        r[1] = _b;
        r[2] = _c;
    }

    function arr(uint256 _a, uint256 _b, uint256 _c, uint256 _d) internal pure returns (uint256[] r) {
        r = new uint256[](4);
        r[0] = _a;
        r[1] = _b;
        r[2] = _c;
        r[3] = _d;
    }

    function arr(uint256 _a, uint256 _b, uint256 _c, uint256 _d, uint256 _e) internal pure returns (uint256[] r) {
        r = new uint256[](5);
        r[0] = _a;
        r[1] = _b;
        r[2] = _c;
        r[3] = _d;
        r[4] = _e;
    }
}


contract ACLHelpers {
    function decodeParamOp(uint256 _x) internal pure returns (uint8 b) {
        return uint8(_x >> (8 * 30));
    }

    function decodeParamId(uint256 _x) internal pure returns (uint8 b) {
        return uint8(_x >> (8 * 31));
    }

    function decodeParamsList(uint256 _x) internal pure returns (uint32 a, uint32 b, uint32 c) {
        a = uint32(_x);
        b = uint32(_x >> (8 * 4));
        c = uint32(_x >> (8 * 8));
    }
}


///File: @aragon/os/contracts/apps/AragonApp.sol

pragma solidity ^0.4.18;







contract AragonApp is AppStorage, Initializable, ACLSyntaxSugar, EVMScriptRunner {
    modifier auth(bytes32 _role) {
        require(canPerform(msg.sender, _role, new uint256[](0)));
        _;
    }

    modifier authP(bytes32 _role, uint256[] params) {
        require(canPerform(msg.sender, _role, params));
        _;
    }

    function canPerform(address _sender, bytes32 _role, uint256[] params) public view returns (bool) {
        bytes memory how; // no need to init memory as it is never used
        if (params.length > 0) {
            uint256 byteLength = params.length * 32;
            assembly {
                how := params // forced casting
                mstore(how, byteLength)
            }
        }
        return address(kernel) == 0 || kernel.hasPermission(_sender, address(this), _role, how);
    }
}


///File: giveth-liquidpledging/contracts/LiquidPledgingACLHelpers.sol

pragma solidity ^0.4.18;

contract LiquidPledgingACLHelpers {
    function arr(uint64 a, uint64 b, address c, uint d, address e) internal pure returns(uint[] r) {
        r = new uint[](4);
        r[0] = uint(a);
        r[1] = uint(b);
        r[2] = uint(c);
        r[3] = d;
        r[4] = uint(e);
    }

    function arr(bool a) internal pure returns (uint[] r) {
        r = new uint[](1);
        uint _a;
        assembly {
            _a := a // forced casting
        }
        r[0] = _a;
    }
}

///File: giveth-liquidpledging/contracts/LiquidPledgingPlugins.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
                  Arthur Lunn

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





contract LiquidPledgingPlugins is AragonApp, LiquidPledgingStorage, LiquidPledgingACLHelpers {

    bytes32 constant public PLUGIN_MANAGER_ROLE = keccak256("PLUGIN_MANAGER_ROLE");

    function addValidPluginInstance(address addr) auth(PLUGIN_MANAGER_ROLE) external {
        pluginInstanceWhitelist[addr] = true;
    }

    function addValidPluginContract(bytes32 contractHash) auth(PLUGIN_MANAGER_ROLE) public {
        pluginContractWhitelist[contractHash] = true;
    }

    function addValidPluginContracts(bytes32[] contractHashes) external auth(PLUGIN_MANAGER_ROLE) {
        for (uint8 i = 0; i < contractHashes.length; i++) {
            addValidPluginContract(contractHashes[i]);
        }
    }

    function removeValidPluginContract(bytes32 contractHash) external authP(PLUGIN_MANAGER_ROLE, arr(contractHash)) {
        pluginContractWhitelist[contractHash] = false;
    }

    function removeValidPluginInstance(address addr) external authP(PLUGIN_MANAGER_ROLE, arr(addr)) {
        pluginInstanceWhitelist[addr] = false;
    }

    function useWhitelist(bool useWhitelist) external auth(PLUGIN_MANAGER_ROLE) {
        whitelistDisabled = !useWhitelist;
    }

    function isValidPlugin(address addr) public view returns(bool) {
        if (whitelistDisabled || addr == 0x0) {
            return true;
        }

        // first check pluginInstances
        if (pluginInstanceWhitelist[addr]) {
            return true;
        }

        // if the addr isn't a valid instance, check the contract code
        bytes32 contractHash = getCodeHash(addr);

        return pluginContractWhitelist[contractHash];
    }

    function getCodeHash(address addr) public view returns(bytes32) {
        bytes memory o_code;
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            mstore(o_code, size) // store length in memory
            // actually retrieve the code, this needs assembly
            extcodecopy(addr, add(o_code, 0x20), 0, size)
        }
        return keccak256(o_code);
    }
}

///File: giveth-liquidpledging/contracts/PledgeAdmins.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
                  Arthur Lunn

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



contract PledgeAdmins is AragonApp, LiquidPledgingPlugins {

    // Limits inserted to prevent large loops that could prevent canceling
    uint constant MAX_SUBPROJECT_LEVEL = 20;
    uint constant MAX_INTERPROJECT_LEVEL = 20;

    // Events
    event GiverAdded(uint64 indexed idGiver, string url);
    event GiverUpdated(uint64 indexed idGiver, string url);
    event DelegateAdded(uint64 indexed idDelegate, string url);
    event DelegateUpdated(uint64 indexed idDelegate, string url);
    event ProjectAdded(uint64 indexed idProject, string url);
    event ProjectUpdated(uint64 indexed idProject, string url);

////////////////////
// Public functions
////////////////////

    /// @notice Creates a Giver Admin with the `msg.sender` as the Admin address
    /// @param name The name used to identify the Giver
    /// @param url The link to the Giver's profile often an IPFS hash
    /// @param commitTime The length of time in seconds the Giver has to
    ///   veto when the Giver's delegates Pledge funds to a project
    /// @param plugin This is Giver's liquid pledge plugin allowing for
    ///  extended functionality
    /// @return idGiver The id number used to reference this Admin
    function addGiver(
        string name,
        string url,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) external returns (uint64 idGiver)
    {
        return addGiver(
            msg.sender,
            name,
            url,
            commitTime,
            plugin
        );
    }

    // TODO: is there an issue w/ allowing anyone to create a giver on behalf of another addy?
    function addGiver(
        address addr,
        string name,
        string url,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) public returns (uint64 idGiver)
    {
        require(isValidPlugin(plugin)); // Plugin check

        idGiver = uint64(admins.length);

        // Save the fields
        admins.push(
            PledgeAdmin(
                PledgeAdminType.Giver,
                addr,
                commitTime,
                0,
                false,
                plugin,
                name,
                url)
        );

        GiverAdded(idGiver, url);
    }

    /// @notice Updates a Giver's info to change the address, name, url, or
    ///  commitTime, it cannot be used to change a plugin, and it must be called
    ///  by the current address of the Giver
    /// @param idGiver This is the Admin id number used to specify the Giver
    /// @param newAddr The new address that represents this Giver
    /// @param newName The new name used to identify the Giver
    /// @param newUrl The new link to the Giver's profile often an IPFS hash
    /// @param newCommitTime Sets the length of time in seconds the Giver has to
    ///   veto when the Giver's delegates Pledge funds to a project
    function updateGiver(
        uint64 idGiver,
        address newAddr,
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) external 
    {
        PledgeAdmin storage giver = _findAdmin(idGiver);
        require(msg.sender == giver.addr);
        require(giver.adminType == PledgeAdminType.Giver); // Must be a Giver
        giver.addr = newAddr;
        giver.name = newName;
        giver.url = newUrl;
        giver.commitTime = newCommitTime;

        GiverUpdated(idGiver, newUrl);
    }

    /// @notice Creates a Delegate Admin with the `msg.sender` as the Admin addr
    /// @param name The name used to identify the Delegate
    /// @param url The link to the Delegate's profile often an IPFS hash
    /// @param commitTime Sets the length of time in seconds that this delegate
    ///  can be vetoed. Whenever this delegate is in a delegate chain the time
    ///  allowed to veto any event must be greater than or equal to this time.
    /// @param plugin This is Delegate's liquid pledge plugin allowing for
    ///  extended functionality
    /// @return idxDelegate The id number used to reference this Delegate within
    ///  the PLEDGE_ADMIN array
    function addDelegate(
        string name,
        string url,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) external returns (uint64 idDelegate) 
    {
        require(isValidPlugin(plugin)); // Plugin check

        idDelegate = uint64(admins.length);

        admins.push(
            PledgeAdmin(
                PledgeAdminType.Delegate,
                msg.sender,
                commitTime,
                0,
                false,
                plugin,
                name,
                url)
        );

        DelegateAdded(idDelegate, url);
    }

    /// @notice Updates a Delegate's info to change the address, name, url, or
    ///  commitTime, it cannot be used to change a plugin, and it must be called
    ///  by the current address of the Delegate
    /// @param idDelegate The Admin id number used to specify the Delegate
    /// @param newAddr The new address that represents this Delegate
    /// @param newName The new name used to identify the Delegate
    /// @param newUrl The new link to the Delegate's profile often an IPFS hash
    /// @param newCommitTime Sets the length of time in seconds that this
    ///  delegate can be vetoed. Whenever this delegate is in a delegate chain
    ///  the time allowed to veto any event must be greater than or equal to
    ///  this time.
    function updateDelegate(
        uint64 idDelegate,
        address newAddr,
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) external 
    {
        PledgeAdmin storage delegate = _findAdmin(idDelegate);
        require(msg.sender == delegate.addr);
        require(delegate.adminType == PledgeAdminType.Delegate);
        delegate.addr = newAddr;
        delegate.name = newName;
        delegate.url = newUrl;
        delegate.commitTime = newCommitTime;

        DelegateUpdated(idDelegate, newUrl);
    }

    /// @notice Creates a Project Admin with the `msg.sender` as the Admin addr
    /// @param name The name used to identify the Project
    /// @param url The link to the Project's profile often an IPFS hash
    /// @param projectAdmin The address for the trusted project manager
    /// @param parentProject The Admin id number for the parent project or 0 if
    ///  there is no parentProject
    /// @param commitTime Sets the length of time in seconds the Project has to
    ///   veto when the Project delegates to another Delegate and they pledge
    ///   those funds to a project
    /// @param plugin This is Project's liquid pledge plugin allowing for
    ///  extended functionality
    /// @return idProject The id number used to reference this Admin
    function addProject(
        string name,
        string url,
        address projectAdmin,
        uint64 parentProject,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) external returns (uint64 idProject) 
    {
        require(isValidPlugin(plugin));

        if (parentProject != 0) {
            PledgeAdmin storage a = _findAdmin(parentProject);
            // getProjectLevel will check that parentProject has a `Project` adminType
            require(_getProjectLevel(a) < MAX_SUBPROJECT_LEVEL);
        }

        idProject = uint64(admins.length);

        admins.push(
            PledgeAdmin(
                PledgeAdminType.Project,
                projectAdmin,
                commitTime,
                parentProject,
                false,
                plugin,
                name,
                url)
        );

        ProjectAdded(idProject, url);
    }

    /// @notice Updates a Project's info to change the address, name, url, or
    ///  commitTime, it cannot be used to change a plugin or a parentProject,
    ///  and it must be called by the current address of the Project
    /// @param idProject The Admin id number used to specify the Project
    /// @param newAddr The new address that represents this Project
    /// @param newName The new name used to identify the Project
    /// @param newUrl The new link to the Project's profile often an IPFS hash
    /// @param newCommitTime Sets the length of time in seconds the Project has
    ///  to veto when the Project delegates to a Delegate and they pledge those
    ///  funds to a project
    function updateProject(
        uint64 idProject,
        address newAddr,
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) external 
    {
        PledgeAdmin storage project = _findAdmin(idProject);

        require(msg.sender == project.addr);
        require(project.adminType == PledgeAdminType.Project);

        project.addr = newAddr;
        project.name = newName;
        project.url = newUrl;
        project.commitTime = newCommitTime;

        ProjectUpdated(idProject, newUrl);
    }

/////////////////////////////
// Public constant functions
/////////////////////////////

    /// @notice A constant getter used to check how many total Admins exist
    /// @return The total number of admins (Givers, Delegates and Projects) .
    function numberOfPledgeAdmins() external view returns(uint) {
        return admins.length - 1;
    }

    /// @notice A constant getter to check the details of a specified Admin
    /// @return addr Account or contract address for admin
    /// @return name Name of the pledgeAdmin
    /// @return url The link to the Project's profile often an IPFS hash
    /// @return commitTime The length of time in seconds the Admin has to veto
    ///   when the Admin delegates to a Delegate and that Delegate pledges those
    ///   funds to a project
    /// @return parentProject The Admin id number for the parent project or 0
    ///  if there is no parentProject
    /// @return canceled 0 for Delegates & Givers, true if a Project has been
    ///  canceled
    /// @return plugin This is Project's liquidPledging plugin allowing for
    ///  extended functionality
    function getPledgeAdmin(uint64 idAdmin) external view returns (
        PledgeAdminType adminType,
        address addr,
        string name,
        string url,
        uint64 commitTime,
        uint64 parentProject,
        bool canceled,
        address plugin
    ) {
        PledgeAdmin storage a = _findAdmin(idAdmin);
        adminType = a.adminType;
        addr = a.addr;
        name = a.name;
        url = a.url;
        commitTime = a.commitTime;
        parentProject = a.parentProject;
        canceled = a.canceled;
        plugin = address(a.plugin);
    }

    /// @notice A getter to find if a specified Project has been canceled
    /// @param projectId The Admin id number used to specify the Project
    /// @return True if the Project has been canceled
    function isProjectCanceled(uint64 projectId)
        public view returns (bool)
    {
        PledgeAdmin storage a = _findAdmin(projectId);

        if (a.adminType == PledgeAdminType.Giver) {
            return false;
        }

        assert(a.adminType == PledgeAdminType.Project);

        if (a.canceled) {
            return true;
        }
        if (a.parentProject == 0) {
            return false;
        }

        return isProjectCanceled(a.parentProject);
    }

///////////////////
// Internal methods
///////////////////

    /// @notice A getter to look up a Admin's details
    /// @param idAdmin The id for the Admin to lookup
    /// @return The PledgeAdmin struct for the specified Admin
    function _findAdmin(uint64 idAdmin) internal view returns (PledgeAdmin storage) {
        require(idAdmin < admins.length);
        return admins[idAdmin];
    }

    /// @notice Find the level of authority a specific Project has
    ///  using a recursive loop
    /// @param a The project admin being queried
    /// @return The level of authority a specific Project has
    function _getProjectLevel(PledgeAdmin a) internal view returns(uint64) {
        assert(a.adminType == PledgeAdminType.Project);

        if (a.parentProject == 0) {
            return(1);
        }

        PledgeAdmin storage parent = _findAdmin(a.parentProject);
        return _getProjectLevel(parent) + 1;
    }
}

///File: giveth-liquidpledging/contracts/Pledges.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
                  Arthur Lunn

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




contract Pledges is AragonApp, LiquidPledgingStorage {

    // Limits inserted to prevent large loops that could prevent canceling
    uint constant MAX_DELEGATES = 10;

    // a constant for when a delegate is requested that is not in the system
    uint64 constant  NOTFOUND = 0xFFFFFFFFFFFFFFFF;

/////////////////////////////
// Public constant functions
////////////////////////////

    /// @notice A constant getter that returns the total number of pledges
    /// @return The total number of Pledges in the system
    function numberOfPledges() external view returns (uint) {
        return pledges.length - 1;
    }

    /// @notice A getter that returns the details of the specified pledge
    /// @param idPledge the id number of the pledge being queried
    /// @return the amount, owner, the number of delegates (but not the actual
    ///  delegates, the intendedProject (if any), the current commit time and
    ///  the previous pledge this pledge was derived from
    function getPledge(uint64 idPledge) external view returns(
        uint amount,
        uint64 owner,
        uint64 nDelegates,
        uint64 intendedProject,
        uint64 commitTime,
        uint64 oldPledge,
        address token,
        PledgeState pledgeState
    ) {
        Pledge memory p = _findPledge(idPledge);
        amount = p.amount;
        owner = p.owner;
        nDelegates = uint64(p.delegationChain.length);
        intendedProject = p.intendedProject;
        commitTime = p.commitTime;
        oldPledge = p.oldPledge;
        token = p.token;
        pledgeState = p.pledgeState;
    }


////////////////////
// Internal methods
////////////////////

    /// @notice This creates a Pledge with an initial amount of 0 if one is not
    ///  created already; otherwise it finds the pledge with the specified
    ///  attributes; all pledges technically exist, if the pledge hasn't been
    ///  created in this system yet it simply isn't in the hash array
    ///  hPledge2idx[] yet
    /// @param owner The owner of the pledge being looked up
    /// @param delegationChain The list of delegates in order of authority
    /// @param intendedProject The project this pledge will Fund after the
    ///  commitTime has passed
    /// @param commitTime The length of time in seconds the Giver has to
    ///   veto when the Giver's delegates Pledge funds to a project
    /// @param oldPledge This value is used to store the pledge the current
    ///  pledge was came from, and in the case a Project is canceled, the Pledge
    ///  will revert back to it's previous state
    /// @param state The pledge state: Pledged, Paying, or state
    /// @return The hPledge2idx index number
    function _findOrCreatePledge(
        uint64 owner,
        uint64[] delegationChain,
        uint64 intendedProject,
        uint64 commitTime,
        uint64 oldPledge,
        address token,
        PledgeState state
    ) internal returns (uint64)
    {
        bytes32 hPledge = keccak256(delegationChain, owner, intendedProject, commitTime, oldPledge, token, state);
        uint64 id = hPledge2idx[hPledge];
        if (id > 0) {
            return id;
        }

        id = uint64(pledges.length);
        hPledge2idx[hPledge] = id;
        pledges.push(
            Pledge(
                0,
                delegationChain,
                owner,
                intendedProject,
                commitTime,
                oldPledge,
                token,
                state
            )
        );
        return id;
    }

    /// @param idPledge the id of the pledge to load from storage
    /// @return The Pledge
    function _findPledge(uint64 idPledge) internal view returns(Pledge storage) {
        require(idPledge < pledges.length);
        return pledges[idPledge];
    }

    /// @notice A getter that searches the delegationChain for the level of
    ///  authority a specific delegate has within a Pledge
    /// @param p The Pledge that will be searched
    /// @param idDelegate The specified delegate that's searched for
    /// @return If the delegate chain contains the delegate with the
    ///  `admins` array index `idDelegate` this returns that delegates
    ///  corresponding index in the delegationChain. Otherwise it returns
    ///  the NOTFOUND constant
    function _getDelegateIdx(Pledge p, uint64 idDelegate) internal pure returns(uint64) {
        for (uint i = 0; i < p.delegationChain.length; i++) {
            if (p.delegationChain[i] == idDelegate) {
                return uint64(i);
            }
        }
        return NOTFOUND;
    }

    /// @notice A getter to find how many old "parent" pledges a specific Pledge
    ///  had using a self-referential loop
    /// @param p The Pledge being queried
    /// @return The number of old "parent" pledges a specific Pledge had
    function _getPledgeLevel(Pledge p) internal view returns(uint) {
        if (p.oldPledge == 0) {
            return 0;
        }
        Pledge storage oldP = _findPledge(p.oldPledge);
        return _getPledgeLevel(oldP) + 1; // a loop lookup
    }
}


///File: giveth-common-contracts/contracts/ERC20.sol

pragma solidity ^0.4.15;


/**
 * @title ERC20
 * @dev A standard interface for tokens.
 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
 */
contract ERC20 {
  
    /// @dev Returns the total token supply
    function totalSupply() public constant returns (uint256 supply);

    /// @dev Returns the account balance of the account with address _owner
    function balanceOf(address _owner) public constant returns (uint256 balance);

    /// @dev Transfers _value number of tokens to address _to
    function transfer(address _to, uint256 _value) public returns (bool success);

    /// @dev Transfers _value number of tokens from address _from to address _to
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    /// @dev Allows _spender to withdraw from the msg.sender's account up to the _value amount
    function approve(address _spender, uint256 _value) public returns (bool success);

    /// @dev Returns the amount which _spender is still allowed to withdraw from _owner
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

}


///File: giveth-liquidpledging/contracts/EscapableApp.sol

pragma solidity ^0.4.18;
/*
    Copyright 2016, Jordi Baylina
    Contributor: Adrià Massanet <adria@codecontext.io>

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

// import "./Owned.sol";




/// @dev `EscapableApp` is a base level contract; it creates an escape hatch
///  function that can be called in an
///  emergency that will allow designated addresses to send any ether or tokens
///  held in the contract to an `escapeHatchDestination` as long as they were
///  not blacklisted
contract EscapableApp is AragonApp {
    // warning whoever has this role can move all funds to the `escapeHatchDestination`
    bytes32 constant public ESCAPE_HATCH_CALLER_ROLE = keccak256("ESCAPE_HATCH_CALLER_ROLE");

    event EscapeHatchBlackistedToken(address token);
    event EscapeHatchCalled(address token, uint amount);

    address public escapeHatchDestination;
    mapping (address=>bool) private escapeBlacklist; // Token contract addresses
    uint[20] private storageOffset; // reserve 20 slots for future upgrades

    function EscapableApp(address _escapeHatchDestination) public {
        _init(_escapeHatchDestination);
    }

    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract; if a neutral address
    ///  is required, the WHG Multisig is an option:
    ///  0x8Ff920020c8AD673661c8117f2855C384758C572 
    function initialize(address _escapeHatchDestination) onlyInit public {
        _init(_escapeHatchDestination);
    }

    /// @notice The `escapeHatch()` should only be called as a last resort if a
    /// security issue is uncovered or something unexpected happened
    /// @param _token to transfer, use 0x0 for ether
    function escapeHatch(address _token) external authP(ESCAPE_HATCH_CALLER_ROLE, arr(_token)) {
        require(escapeBlacklist[_token]==false);

        uint256 balance;

        /// @dev Logic for ether
        if (_token == 0x0) {
            balance = this.balance;
            escapeHatchDestination.transfer(balance);
            EscapeHatchCalled(_token, balance);
            return;
        }
        /// @dev Logic for tokens
        ERC20 token = ERC20(_token);
        balance = token.balanceOf(this);
        require(token.transfer(escapeHatchDestination, balance));
        EscapeHatchCalled(_token, balance);
    }

    /// @notice Checks to see if `_token` is in the blacklist of tokens
    /// @param _token the token address being queried
    /// @return False if `_token` is in the blacklist and can't be taken out of
    ///  the contract via the `escapeHatch()`
    function isTokenEscapable(address _token) view external returns (bool) {
        return !escapeBlacklist[_token];
    }

    function _init(address _escapeHatchDestination) internal {
        initialized();
        require(_escapeHatchDestination != 0x0);

        escapeHatchDestination = _escapeHatchDestination;
    }

    /// @notice Creates the blacklist of tokens that are not able to be taken
    ///  out of the contract; can only be done at the deployment, and the logic
    ///  to add to the blacklist will be in the constructor of a child contract
    /// @param _token the token contract address that is to be blacklisted 
    function _blacklistEscapeToken(address _token) internal {
        escapeBlacklist[_token] = true;
        EscapeHatchBlackistedToken(_token);
    }
}


///File: giveth-liquidpledging/contracts/LiquidPledgingBase.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina
    Contributors: Adrià Massanet <adria@codecontext.io>, RJ Ewing, Griff
    Green, Arthur Lunn

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






/// @dev `LiquidPledgingBase` is the base level contract used to carry out
///  liquidPledging's most basic functions, mostly handling and searching the
///  data structures
contract LiquidPledgingBase is EscapableApp, LiquidPledgingStorage, PledgeAdmins, Pledges {

    event Transfer(uint indexed from, uint indexed to, uint amount);
    event CancelProject(uint indexed idProject);

/////////////
// Modifiers
/////////////

    /// @dev The `vault`is the only addresses that can call a function with this
    ///  modifier
    modifier onlyVault() {
        require(msg.sender == address(vault));
        _;
    }

///////////////
// Constructor
///////////////

    function initialize(address _escapeHatchDestination) onlyInit public {
        require(false); // overload the EscapableApp
        _escapeHatchDestination;
    }

    /// @param _vault The vault where the ETH backing the pledges is stored
    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract; if a neutral address
    ///  is required, the WHG Multisig is an option:
    ///  0x8Ff920020c8AD673661c8117f2855C384758C572 
    function initialize(address _vault, address _escapeHatchDestination) onlyInit public {
        super.initialize(_escapeHatchDestination);
        require(_vault != 0x0);

        vault = ILPVault(_vault);

        admins.length = 1; // we reserve the 0 admin
        pledges.length = 1; // we reserve the 0 pledge
    }


/////////////////////////////
// Public constant functions
/////////////////////////////

    /// @notice Getter to find Delegate w/ the Pledge ID & the Delegate index
    /// @param idPledge The id number representing the pledge being queried
    /// @param idxDelegate The index number for the delegate in this Pledge 
    function getPledgeDelegate(uint64 idPledge, uint64 idxDelegate) external view returns(
        uint64 idDelegate,
        address addr,
        string name
    ) {
        Pledge storage p = _findPledge(idPledge);
        idDelegate = p.delegationChain[idxDelegate - 1];
        PledgeAdmin storage delegate = _findAdmin(idDelegate);
        addr = delegate.addr;
        name = delegate.name;
    }

///////////////////
// Public functions
///////////////////

    /// @notice Only affects pledges with the Pledged PledgeState for 2 things:
    ///   #1: Checks if the pledge should be committed. This means that
    ///       if the pledge has an intendedProject and it is past the
    ///       commitTime, it changes the owner to be the proposed project
    ///       (The UI will have to read the commit time and manually do what
    ///       this function does to the pledge for the end user
    ///       at the expiration of the commitTime)
    ///
    ///   #2: Checks to make sure that if there has been a cancellation in the
    ///       chain of projects, the pledge's owner has been changed
    ///       appropriately.
    ///
    /// This function can be called by anybody at anytime on any pledge.
    ///  In general it can be called to force the calls of the affected 
    ///  plugins, which also need to be predicted by the UI
    /// @param idPledge This is the id of the pledge that will be normalized
    /// @return The normalized Pledge!
    function normalizePledge(uint64 idPledge) public returns(uint64) {
        Pledge storage p = _findPledge(idPledge);

        // Check to make sure this pledge hasn't already been used 
        // or is in the process of being used
        if (p.pledgeState != PledgeState.Pledged) {
            return idPledge;
        }

        // First send to a project if it's proposed and committed
        if ((p.intendedProject > 0) && ( _getTime() > p.commitTime)) {
            uint64 oldPledge = _findOrCreatePledge(
                p.owner,
                p.delegationChain,
                0,
                0,
                p.oldPledge,
                p.token,
                PledgeState.Pledged
            );
            uint64 toPledge = _findOrCreatePledge(
                p.intendedProject,
                new uint64[](0),
                0,
                0,
                oldPledge,
                p.token,
                PledgeState.Pledged
            );
            _doTransfer(idPledge, toPledge, p.amount);
            idPledge = toPledge;
            p = _findPledge(idPledge);
        }

        toPledge = _getOldestPledgeNotCanceled(idPledge);
        if (toPledge != idPledge) {
            _doTransfer(idPledge, toPledge, p.amount);
        }

        return toPledge;
    }

////////////////////
// Internal methods
////////////////////

    /// @notice A check to see if the msg.sender is the owner or the
    ///  plugin contract for a specific Admin
    /// @param idAdmin The id of the admin being checked
    function _checkAdminOwner(uint64 idAdmin) internal view {
        PledgeAdmin storage a = _findAdmin(idAdmin);
        require(msg.sender == address(a.plugin) || msg.sender == a.addr);
    }

    function _transfer( 
        uint64 idSender,
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal
    {
        require(idReceiver > 0); // prevent burning value
        idPledge = normalizePledge(idPledge);

        Pledge storage p = _findPledge(idPledge);
        PledgeAdmin storage receiver = _findAdmin(idReceiver);

        require(p.pledgeState == PledgeState.Pledged);

        // If the sender is the owner of the Pledge
        if (p.owner == idSender) {

            if (receiver.adminType == PledgeAdminType.Giver) {
                _transferOwnershipToGiver(idPledge, amount, idReceiver);
                return;
            } else if (receiver.adminType == PledgeAdminType.Project) {
                _transferOwnershipToProject(idPledge, amount, idReceiver);
                return;
            } else if (receiver.adminType == PledgeAdminType.Delegate) {

                uint recieverDIdx = _getDelegateIdx(p, idReceiver);
                if (p.intendedProject > 0 && recieverDIdx != NOTFOUND) {
                    // if there is an intendedProject and the receiver is in the delegationChain,
                    // then we want to preserve the delegationChain as this is a veto of the
                    // intendedProject by the owner

                    if (recieverDIdx == p.delegationChain.length - 1) {
                        uint64 toPledge = _findOrCreatePledge(
                            p.owner,
                            p.delegationChain,
                            0,
                            0,
                            p.oldPledge,
                            p.token,
                            PledgeState.Pledged);
                        _doTransfer(idPledge, toPledge, amount);
                        return;
                    }

                    _undelegate(idPledge, amount, p.delegationChain.length - receiverDIdx - 1);
                    return;
                }
                // owner is not vetoing an intendedProject and is transferring the pledge to a delegate,
                // so we want to reset the delegationChain
                idPledge = _undelegate(
                    idPledge,
                    amount,
                    p.delegationChain.length
                );
                _appendDelegate(idPledge, amount, idReceiver);
                return;
            }

            // This should never be reached as the receiver.adminType
            // should always be either a Giver, Project, or Delegate
            assert(false);
        }

        // If the sender is a Delegate
        uint senderDIdx = _getDelegateIdx(p, idSender);
        if (senderDIdx != NOTFOUND) {

            // And the receiver is another Giver
            if (receiver.adminType == PledgeAdminType.Giver) {
                // Only transfer to the Giver who owns the pledge
                assert(p.owner == idReceiver);
                _undelegate(idPledge, amount, p.delegationChain.length);
                return;
            }

            // And the receiver is another Delegate
            if (receiver.adminType == PledgeAdminType.Delegate) {
                uint receiverDIdx = _getDelegateIdx(p, idReceiver);

                // And not in the delegationChain
                if (receiverDIdx == NOTFOUND) {
                    idPledge = _undelegate(
                        idPledge,
                        amount,
                        p.delegationChain.length - senderDIdx - 1
                    );
                    _appendDelegate(idPledge, amount, idReceiver);
                    return;

                // And part of the delegationChain and is after the sender, then
                //  all of the other delegates after the sender are removed and
                //  the receiver is appended at the end of the delegationChain
                } else if (receiverDIdx > senderDIdx) {
                    idPledge = _undelegate(
                        idPledge,
                        amount,
                        p.delegationChain.length - senderDIdx - 1
                    );
                    _appendDelegate(idPledge, amount, idReceiver);
                    return;
                }

                // And is already part of the delegate chain but is before the
                //  sender, then the sender and all of the other delegates after
                //  the RECEIVER are removed from the delegationChain
                //TODO Check for Game Theory issues (from Arthur) this allows the sender to sort of go komakosi and remove himself and the delegates between himself and the receiver... should this authority be allowed?
                _undelegate(
                    idPledge,
                    amount,
                    p.delegationChain.length - receiverDIdx - 1
                );
                return;
            }

            // And the receiver is a Project, all the delegates after the sender
            //  are removed and the amount is pre-committed to the project
            if (receiver.adminType == PledgeAdminType.Project) {
                idPledge = _undelegate(
                    idPledge,
                    amount,
                    p.delegationChain.length - senderDIdx - 1
                );
                _proposeAssignProject(idPledge, amount, idReceiver);
                return;
            }
        }
        assert(false);  // When the sender is not an owner or a delegate
    }

    /// @notice `transferOwnershipToProject` allows for the transfer of
    ///  ownership to the project, but it can also be called by a project
    ///  to un-delegate everyone by setting one's own id for the idReceiver
    /// @param idPledge the id of the pledge to be transfered.
    /// @param amount Quantity of value that's being transfered
    /// @param idReceiver The new owner of the project (or self to un-delegate)
    function _transferOwnershipToProject(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        // Ensure that the pledge is not already at max pledge depth
        // and the project has not been canceled
        require(_getPledgeLevel(p) < MAX_INTERPROJECT_LEVEL);
        require(!isProjectCanceled(idReceiver));

        uint64 oldPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        uint64 toPledge = _findOrCreatePledge(
            idReceiver,                     // Set the new owner
            new uint64[](0),                // clear the delegation chain
            0,
            0,
            oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }   


    /// @notice `transferOwnershipToGiver` allows for the transfer of
    ///  value back to the Giver, value is placed in a pledged state
    ///  without being attached to a project, delegation chain, or time line.
    /// @param idPledge the id of the pledge to be transferred.
    /// @param amount Quantity of value that's being transferred
    /// @param idReceiver The new owner of the pledge
    function _transferOwnershipToGiver(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        uint64 toPledge = _findOrCreatePledge(
            idReceiver,
            new uint64[](0),
            0,
            0,
            0,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `appendDelegate` allows for a delegate to be added onto the
    ///  end of the delegate chain for a given Pledge.
    /// @param idPledge the id of the pledge thats delegate chain will be modified.
    /// @param amount Quantity of value that's being chained.
    /// @param idReceiver The delegate to be added at the end of the chain
    function _appendDelegate(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        require(p.delegationChain.length < MAX_DELEGATES);
        uint64[] memory newDelegationChain = new uint64[](
            p.delegationChain.length + 1
        );
        for (uint i = 0; i < p.delegationChain.length; i++) {
            newDelegationChain[i] = p.delegationChain[i];
        }

        // Make the last item in the array the idReceiver
        newDelegationChain[p.delegationChain.length] = idReceiver;

        uint64 toPledge = _findOrCreatePledge(
            p.owner,
            newDelegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `appendDelegate` allows for a delegate to be added onto the
    ///  end of the delegate chain for a given Pledge.
    /// @param idPledge the id of the pledge thats delegate chain will be modified.
    /// @param amount Quantity of value that's shifted from delegates.
    /// @param q Number (or depth) of delegates to remove
    /// @return toPledge The id for the pledge being adjusted or created
    function _undelegate(
        uint64 idPledge,
        uint amount,
        uint q
    ) internal returns (uint64 toPledge)
    {
        Pledge storage p = _findPledge(idPledge);
        uint64[] memory newDelegationChain = new uint64[](
            p.delegationChain.length - q
        );

        for (uint i = 0; i < p.delegationChain.length - q; i++) {
            newDelegationChain[i] = p.delegationChain[i];
        }
        toPledge = _findOrCreatePledge(
            p.owner,
            newDelegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `proposeAssignProject` proposes the assignment of a pledge
    ///  to a specific project.
    /// @dev This function should potentially be named more specifically.
    /// @param idPledge the id of the pledge that will be assigned.
    /// @param amount Quantity of value this pledge leader would be assigned.
    /// @param idReceiver The project this pledge will potentially 
    ///  be assigned to.
    function _proposeAssignProject(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        require(_getPledgeLevel(p) < MAX_INTERPROJECT_LEVEL);
        require(!isProjectCanceled(idReceiver));

        uint64 toPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            idReceiver,
            uint64(_getTime() + _maxCommitTime(p)),
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `doTransfer` is designed to allow for pledge amounts to be 
    ///  shifted around internally.
    /// @param from This is the id of the pledge from which value will be transferred.
    /// @param to This is the id of the pledge that value will be transferred to.
    /// @param _amount The amount of value that will be transferred.
    function _doTransfer(uint64 from, uint64 to, uint _amount) internal {
        uint amount = _callPlugins(true, from, to, _amount);
        if (from == to) {
            return;
        }
        if (amount == 0) {
            return;
        }

        Pledge storage pFrom = _findPledge(from);
        Pledge storage pTo = _findPledge(to);

        require(pFrom.amount >= amount);
        pFrom.amount -= amount;
        pTo.amount += amount;

        Transfer(from, to, amount);
        _callPlugins(false, from, to, amount);
    }

    /// @notice A getter to find the longest commitTime out of the owner and all
    ///  the delegates for a specified pledge
    /// @param p The Pledge being queried
    /// @return The maximum commitTime out of the owner and all the delegates
    function _maxCommitTime(Pledge p) internal view returns(uint64 commitTime) {
        PledgeAdmin storage a = _findAdmin(p.owner);
        commitTime = a.commitTime; // start with the owner's commitTime

        for (uint i = 0; i < p.delegationChain.length; i++) {
            a = _findAdmin(p.delegationChain[i]);

            // If a delegate's commitTime is longer, make it the new commitTime
            if (a.commitTime > commitTime) {
                commitTime = a.commitTime;
            }
        }
    }

    /// @notice A getter to find the oldest pledge that hasn't been canceled
    /// @param idPledge The starting place to lookup the pledges
    /// @return The oldest idPledge that hasn't been canceled (DUH!)
    function _getOldestPledgeNotCanceled(
        uint64 idPledge
    ) internal view returns(uint64)
    {
        if (idPledge == 0) {
            return 0;
        }

        Pledge storage p = _findPledge(idPledge);
        PledgeAdmin storage admin = _findAdmin(p.owner);
        
        if (admin.adminType == PledgeAdminType.Giver) {
            return idPledge;
        }

        assert(admin.adminType == PledgeAdminType.Project);
        if (!isProjectCanceled(p.owner)) {
            return idPledge;
        }

        return _getOldestPledgeNotCanceled(p.oldPledge);
    }

    /// @notice `callPlugin` is used to trigger the general functions in the
    ///  plugin for any actions needed before and after a transfer happens.
    ///  Specifically what this does in relation to the plugin is something
    ///  that largely depends on the functions of that plugin. This function
    ///  is generally called in pairs, once before, and once after a transfer.
    /// @param before This toggle determines whether the plugin call is occurring
    ///  before or after a transfer.
    /// @param adminId This should be the Id of the *trusted* individual
    ///  who has control over this plugin.
    /// @param fromPledge This is the Id from which value is being transfered.
    /// @param toPledge This is the Id that value is being transfered to.
    /// @param context The situation that is triggering the plugin. See plugin
    ///  for a full description of contexts.
    /// @param amount The amount of value that is being transfered.
    function _callPlugin(
        bool before,
        uint64 adminId,
        uint64 fromPledge,
        uint64 toPledge,
        uint64 context,
        address token,
        uint amount
    ) internal returns (uint allowedAmount) 
    {
        uint newAmount;
        allowedAmount = amount;
        PledgeAdmin storage admin = _findAdmin(adminId);

        // Checks admin has a plugin assigned and a non-zero amount is requested
        if (address(admin.plugin) != 0 && allowedAmount > 0) {
            // There are two separate functions called in the plugin.
            // One is called before the transfer and one after
            if (before) {
                newAmount = admin.plugin.beforeTransfer(
                    adminId,
                    fromPledge,
                    toPledge,
                    context,
                    token,
                    amount
                );
                require(newAmount <= allowedAmount);
                allowedAmount = newAmount;
            } else {
                admin.plugin.afterTransfer(
                    adminId,
                    fromPledge,
                    toPledge,
                    context,
                    token,
                    amount
                );
            }
        }
    }

    /// @notice `callPluginsPledge` is used to apply plugin calls to
    ///  the delegate chain and the intended project if there is one.
    ///  It does so in either a transferring or receiving context based
    ///  on the `p` and  `fromPledge` parameters.
    /// @param before This toggle determines whether the plugin call is occuring
    ///  before or after a transfer.
    /// @param idPledge This is the id of the pledge on which this plugin
    ///  is being called.
    /// @param fromPledge This is the Id from which value is being transfered.
    /// @param toPledge This is the Id that value is being transfered to.
    /// @param amount The amount of value that is being transfered.
    function _callPluginsPledge(
        bool before,
        uint64 idPledge,
        uint64 fromPledge,
        uint64 toPledge,
        uint amount
    ) internal returns (uint allowedAmount) 
    {
        // Determine if callPlugin is being applied in a receiving
        // or transferring context
        uint64 offset = idPledge == fromPledge ? 0 : 256;
        allowedAmount = amount;
        Pledge storage p = _findPledge(idPledge);

        // Always call the plugin on the owner
        allowedAmount = _callPlugin(
            before,
            p.owner,
            fromPledge,
            toPledge,
            offset,
            p.token,
            allowedAmount
        );

        // Apply call plugin to all delegates
        for (uint64 i = 0; i < p.delegationChain.length; i++) {
            allowedAmount = _callPlugin(
                before,
                p.delegationChain[i],
                fromPledge,
                toPledge,
                offset + i + 1,
                p.token,
                allowedAmount
            );
        }

        // If there is an intended project also call the plugin in
        // either a transferring or receiving context based on offset
        // on the intended project
        if (p.intendedProject > 0) {
            allowedAmount = _callPlugin(
                before,
                p.intendedProject,
                fromPledge,
                toPledge,
                offset + 255,
                p.token,
                allowedAmount
            );
        }
    }

    /// @notice `callPlugins` calls `callPluginsPledge` once for the transfer
    ///  context and once for the receiving context. The aggregated 
    ///  allowed amount is then returned.
    /// @param before This toggle determines whether the plugin call is occurring
    ///  before or after a transfer.
    /// @param fromPledge This is the Id from which value is being transferred.
    /// @param toPledge This is the Id that value is being transferred to.
    /// @param amount The amount of value that is being transferred.
    function _callPlugins(
        bool before,
        uint64 fromPledge,
        uint64 toPledge,
        uint amount
    ) internal returns (uint allowedAmount) 
    {
        allowedAmount = amount;

        // Call the plugins in the transfer context
        allowedAmount = _callPluginsPledge(
            before,
            fromPledge,
            fromPledge,
            toPledge,
            allowedAmount
        );

        // Call the plugins in the receive context
        allowedAmount = _callPluginsPledge(
            before,
            toPledge,
            fromPledge,
            toPledge,
            allowedAmount
        );
    }

/////////////
// Test functions
/////////////

    /// @notice Basic helper function to return the current time
    function _getTime() internal view returns (uint) {
        return now;
    }
}


///File: giveth-liquidpledging/contracts/LiquidPledging.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
    Arthur Lunn

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



/// @dev `LiquidPledging` allows for liquid pledging through the use of
///  internal id structures and delegate chaining. All basic operations for
///  handling liquid pledging are supplied as well as plugin features
///  to allow for expanded functionality.
contract LiquidPledging is LiquidPledgingBase {

    function LiquidPledging(address _escapeHatchDestination) EscapableApp(_escapeHatchDestination) public {
    }

    function addGiverAndDonate(uint64 idReceiver, address token, uint amount)
        public
    {
        addGiverAndDonate(idReceiver, msg.sender, token, amount);
    }

    function addGiverAndDonate(uint64 idReceiver, address donorAddress, address token, uint amount)
        public
    {
        require(donorAddress != 0);
        // default to a 3 day (259200 seconds) commitTime
        uint64 idGiver = addGiver(donorAddress, "", "", 259200, ILiquidPledgingPlugin(0));
        donate(idGiver, idReceiver, token, amount);
    }

    /// @notice This is how value enters the system and how pledges are created;
    ///  the ether is sent to the vault, an pledge for the Giver is created (or
    ///  found), the amount of ETH donated in wei is added to the `amount` in
    ///  the Giver's Pledge, and an LP transfer is done to the idReceiver for
    ///  the full amount
    /// @param idGiver The id of the Giver donating
    /// @param idReceiver The Admin receiving the donation; can be any Admin:
    ///  the Giver themselves, another Giver, a Delegate or a Project
    function donate(uint64 idGiver, uint64 idReceiver, address token, uint amount)
        public
    {
        require(idGiver > 0); // prevent burning donations. idReceiver is checked in _transfer
        require(amount > 0);
        require(token != 0x0);

        PledgeAdmin storage sender = _findAdmin(idGiver);
        require(sender.adminType == PledgeAdminType.Giver);

        // TODO should this be done at the end of this function?
        // what re-entrancy issues are there if this is done here?
        // if done at the end of the function, will that affect plugins?
        require(ERC20(token).transferFrom(msg.sender, address(vault), amount)); // transfer the token to the `vault`

        uint64 idPledge = _findOrCreatePledge(
            idGiver,
            new uint64[](0), // Creates empty array for delegationChain
            0,
            0,
            0,
            token,
            PledgeState.Pledged
        );

        Pledge storage pTo = _findPledge(idPledge);
        pTo.amount += amount;

        Transfer(0, idPledge, amount);

        _transfer(idGiver, idPledge, amount, idReceiver);
    }

    /// @notice Transfers amounts between pledges for internal accounting
    /// @param idSender Id of the Admin that is transferring the amount from
    ///  Pledge to Pledge; this admin must have permissions to move the value
    /// @param idPledge Id of the pledge that's moving the value
    /// @param amount Quantity of ETH (in wei) that this pledge is transferring 
    ///  the authority to withdraw from the vault
    /// @param idReceiver Destination of the `amount`, can be a Giver/Project sending
    ///  to a Giver, a Delegate or a Project; a Delegate sending to another
    ///  Delegate, or a Delegate pre-commiting it to a Project 
    function transfer( 
        uint64 idSender,
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) public
    {
        _checkAdminOwner(idSender);
        _transfer(idSender, idPledge, amount, idReceiver);
    }

    /// @notice Authorizes a payment be made from the `vault` can be used by the
    ///  Giver to veto a pre-committed donation from a Delegate to an
    ///  intendedProject
    /// @param idPledge Id of the pledge that is to be redeemed into ether
    /// @param amount Quantity of ether (in wei) to be authorized
    function withdraw(uint64 idPledge, uint amount) public {
        idPledge = normalizePledge(idPledge); // Updates pledge info 

        Pledge storage p = _findPledge(idPledge);
        require(p.pledgeState == PledgeState.Pledged);
        _checkAdminOwner(p.owner);

        uint64 idNewPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Paying
        );

        _doTransfer(idPledge, idNewPledge, amount);

        PledgeAdmin storage owner = _findAdmin(p.owner);
        vault.authorizePayment(bytes32(idNewPledge), owner.addr, p.token, amount);
    }

    /// @notice `onlyVault` Confirms a withdraw request changing the PledgeState
    ///  from Paying to Paid
    /// @param idPledge Id of the pledge that is to be withdrawn
    /// @param amount Quantity of ether (in wei) to be withdrawn
    function confirmPayment(uint64 idPledge, uint amount) public onlyVault {
        Pledge storage p = _findPledge(idPledge);

        require(p.pledgeState == PledgeState.Paying);

        uint64 idNewPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Paid
        );

        _doTransfer(idPledge, idNewPledge, amount);
    }

    /// @notice `onlyVault` Cancels a withdraw request, changing the PledgeState
    ///  from Paying back to Pledged
    /// @param idPledge Id of the pledge that's withdraw is to be canceled
    /// @param amount Quantity of ether (in wei) to be canceled
    function cancelPayment(uint64 idPledge, uint amount) public onlyVault {
        Pledge storage p = _findPledge(idPledge);

        require(p.pledgeState == PledgeState.Paying);

        // When a payment is canceled, never is assigned to a project.
        uint64 idOldPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );

        idOldPledge = normalizePledge(idOldPledge);

        _doTransfer(idPledge, idOldPledge, amount);
    }

    /// @notice Changes the `project.canceled` flag to `true`; cannot be undone
    /// @param idProject Id of the project that is to be canceled
    function cancelProject(uint64 idProject) public {
        PledgeAdmin storage project = _findAdmin(idProject);
        _checkAdminOwner(idProject);
        project.canceled = true;

        CancelProject(idProject);
    }

    /// @notice Transfers `amount` in `idPledge` back to the `oldPledge` that
    ///  that sent it there in the first place, a Ctrl-z 
    /// @param idPledge Id of the pledge that is to be canceled
    /// @param amount Quantity of ether (in wei) to be transfered to the 
    ///  `oldPledge`
    function cancelPledge(uint64 idPledge, uint amount) public {
        idPledge = normalizePledge(idPledge);

        Pledge storage p = _findPledge(idPledge);
        require(p.oldPledge != 0);
        require(p.pledgeState == PledgeState.Pledged);
        _checkAdminOwner(p.owner);

        uint64 oldPledge = _getOldestPledgeNotCanceled(p.oldPledge);
        _doTransfer(idPledge, oldPledge, amount);
    }


////////
// Multi pledge methods
////////

    // @dev This set of functions makes moving a lot of pledges around much more
    // efficient (saves gas) than calling these functions in series
    
    
    /// @dev Bitmask used for dividing pledge amounts in Multi pledge methods
    uint constant D64 = 0x10000000000000000;

    /// @notice Transfers multiple amounts within multiple Pledges in an
    ///  efficient single call 
    /// @param idSender Id of the Admin that is transferring the amounts from
    ///  all the Pledges; this admin must have permissions to move the value
    /// @param pledgesAmounts An array of Pledge amounts and the idPledges with 
    ///  which the amounts are associated; these are extrapolated using the D64
    ///  bitmask
    /// @param idReceiver Destination of the `pledesAmounts`, can be a Giver or 
    ///  Project sending to a Giver, a Delegate or a Project; a Delegate sending
    ///  to another Delegate, or a Delegate pre-commiting it to a Project 
    function mTransfer(
        uint64 idSender,
        uint[] pledgesAmounts,
        uint64 idReceiver
    ) public 
    {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64(pledgesAmounts[i] & (D64-1));
            uint amount = pledgesAmounts[i] / D64;

            transfer(idSender, idPledge, amount, idReceiver);
        }
    }

    /// @notice Authorizes multiple amounts within multiple Pledges to be
    ///  withdrawn from the `vault` in an efficient single call 
    /// @param pledgesAmounts An array of Pledge amounts and the idPledges with 
    ///  which the amounts are associated; these are extrapolated using the D64
    ///  bitmask
    function mWithdraw(uint[] pledgesAmounts) public {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64(pledgesAmounts[i] & (D64-1));
            uint amount = pledgesAmounts[i] / D64;

            withdraw(idPledge, amount);
        }
    }

    /// @notice `mConfirmPayment` allows for multiple pledges to be confirmed
    ///  efficiently
    /// @param pledgesAmounts An array of pledge amounts and IDs which are extrapolated
    ///  using the D64 bitmask
    function mConfirmPayment(uint[] pledgesAmounts) public {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64(pledgesAmounts[i] & (D64-1));
            uint amount = pledgesAmounts[i] / D64;

            confirmPayment(idPledge, amount);
        }
    }

    /// @notice `mCancelPayment` allows for multiple pledges to be canceled
    ///  efficiently
    /// @param pledgesAmounts An array of pledge amounts and IDs which are extrapolated
    ///  using the D64 bitmask
    function mCancelPayment(uint[] pledgesAmounts) public {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64(pledgesAmounts[i] & (D64-1));
            uint amount = pledgesAmounts[i] / D64;

            cancelPayment(idPledge, amount);
        }
    }

    /// @notice `mNormalizePledge` allows for multiple pledges to be
    ///  normalized efficiently
    /// @param pledges An array of pledge IDs
    function mNormalizePledge(uint64[] pledges) public {
        for (uint i = 0; i < pledges.length; i++ ) {
            normalizePledge(pledges[i]);
        }
    }
}


///File: minimetoken/contracts/Controlled.sol

pragma solidity ^0.4.18;

contract Controlled {
    /// @notice The address of the controller is the only address that can call
    ///  a function with this modifier
    modifier onlyController { require(msg.sender == controller); _; }

    address public controller;

    function Controlled() public { controller = msg.sender;}

    /// @notice Changes the controller of the contract
    /// @param _newController The new controller of the contract
    function changeController(address _newController) public onlyController {
        controller = _newController;
    }
}


///File: minimetoken/contracts/TokenController.sol

pragma solidity ^0.4.18;

/// @dev The token controller contract must implement these functions
contract TokenController {
    /// @notice Called when `_owner` sends ether to the MiniMe Token contract
    /// @param _owner The address that sent the ether to create tokens
    /// @return True if the ether is accepted, false if it throws
    function proxyPayment(address _owner) public payable returns(bool);

    /// @notice Notifies the controller about a token transfer allowing the
    ///  controller to react if desired
    /// @param _from The origin of the transfer
    /// @param _to The destination of the transfer
    /// @param _amount The amount of the transfer
    /// @return False if the controller does not authorize the transfer
    function onTransfer(address _from, address _to, uint _amount) public returns(bool);

    /// @notice Notifies the controller about an approval allowing the
    ///  controller to react if desired
    /// @param _owner The address that calls `approve()`
    /// @param _spender The spender in the `approve()` call
    /// @param _amount The amount in the `approve()` call
    /// @return False if the controller does not authorize the approval
    function onApprove(address _owner, address _spender, uint _amount) public
        returns(bool);
}


///File: minimetoken/contracts/MiniMeToken.sol

pragma solidity ^0.4.18;

/*
    Copyright 2016, Jordi Baylina

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

/// @title MiniMeToken Contract
/// @author Jordi Baylina
/// @dev This token contract's goal is to make it easy for anyone to clone this
///  token using the token distribution at a given block, this will allow DAO's
///  and DApps to upgrade their features in a decentralized manner without
///  affecting the original token
/// @dev It is ERC20 compliant, but still needs to under go further testing.




contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 _amount, address _token, bytes _data) public;
}

/// @dev The actual token contract, the default controller is the msg.sender
///  that deploys the contract, so usually this token will be deployed by a
///  token controller contract, which Giveth will call a "Campaign"
contract MiniMeToken is Controlled {

    string public name;                //The Token's name: e.g. DigixDAO Tokens
    uint8 public decimals;             //Number of decimals of the smallest unit
    string public symbol;              //An identifier: e.g. REP
    string public version = 'MMT_0.2'; //An arbitrary versioning scheme


    /// @dev `Checkpoint` is the structure that attaches a block number to a
    ///  given value, the block number attached is the one that last changed the
    ///  value
    struct  Checkpoint {

        // `fromBlock` is the block number that the value was generated from
        uint128 fromBlock;

        // `value` is the amount of tokens at a specific block number
        uint128 value;
    }

    // `parentToken` is the Token address that was cloned to produce this token;
    //  it will be 0x0 for a token that was not cloned
    MiniMeToken public parentToken;

    // `parentSnapShotBlock` is the block number from the Parent Token that was
    //  used to determine the initial distribution of the Clone Token
    uint public parentSnapShotBlock;

    // `creationBlock` is the block number that the Clone Token was created
    uint public creationBlock;

    // `balances` is the map that tracks the balance of each address, in this
    //  contract when the balance changes the block number that the change
    //  occurred is also included in the map
    mapping (address => Checkpoint[]) balances;

    // `allowed` tracks any extra transfer rights as in all ERC20 tokens
    mapping (address => mapping (address => uint256)) allowed;

    // Tracks the history of the `totalSupply` of the token
    Checkpoint[] totalSupplyHistory;

    // Flag that determines if the token is transferable or not.
    bool public transfersEnabled;

    // The factory used to create new clone tokens
    MiniMeTokenFactory public tokenFactory;

////////////////
// Constructor
////////////////

    /// @notice Constructor to create a MiniMeToken
    /// @param _tokenFactory The address of the MiniMeTokenFactory contract that
    ///  will create the Clone token contracts, the token factory needs to be
    ///  deployed first
    /// @param _parentToken Address of the parent token, set to 0x0 if it is a
    ///  new token
    /// @param _parentSnapShotBlock Block of the parent token that will
    ///  determine the initial distribution of the clone token, set to 0 if it
    ///  is a new token
    /// @param _tokenName Name of the new token
    /// @param _decimalUnits Number of decimals of the new token
    /// @param _tokenSymbol Token Symbol for the new token
    /// @param _transfersEnabled If true, tokens will be able to be transferred
    function MiniMeToken(
        address _tokenFactory,
        address _parentToken,
        uint _parentSnapShotBlock,
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        bool _transfersEnabled
    ) public {
        tokenFactory = MiniMeTokenFactory(_tokenFactory);
        name = _tokenName;                                 // Set the name
        decimals = _decimalUnits;                          // Set the decimals
        symbol = _tokenSymbol;                             // Set the symbol
        parentToken = MiniMeToken(_parentToken);
        parentSnapShotBlock = _parentSnapShotBlock;
        transfersEnabled = _transfersEnabled;
        creationBlock = block.number;
    }


///////////////////
// ERC20 Methods
///////////////////

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        require(transfersEnabled);
        return doTransfer(msg.sender, _to, _amount);
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    ///  is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount
    ) public returns (bool success) {

        // The controller of this contract can move tokens around at will,
        //  this is important to recognize! Confirm that you trust the
        //  controller of this contract, which in most situations should be
        //  another open source smart contract or 0x0
        if (msg.sender != controller) {
            require(transfersEnabled);

            // The standard ERC 20 transferFrom functionality
            if (allowed[_from][msg.sender] < _amount) return false;
            allowed[_from][msg.sender] -= _amount;
        }
        return doTransfer(_from, _to, _amount);
    }

    /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function doTransfer(address _from, address _to, uint _amount
    ) internal returns(bool) {

           if (_amount == 0) {
               return true;
           }

           require(parentSnapShotBlock < block.number);

           // Do not allow transfer to 0x0 or the token contract itself
           require((_to != 0) && (_to != address(this)));

           // If the amount being transfered is more than the balance of the
           //  account the transfer returns false
           var previousBalanceFrom = balanceOfAt(_from, block.number);
           if (previousBalanceFrom < _amount) {
               return false;
           }

           // Alerts the token controller of the transfer
           if (isContract(controller)) {
               require(TokenController(controller).onTransfer(_from, _to, _amount));
           }

           // First update the balance array with the new value for the address
           //  sending the tokens
           updateValueAtNow(balances[_from], previousBalanceFrom - _amount);

           // Then update the balance array with the new value for the address
           //  receiving the tokens
           var previousBalanceTo = balanceOfAt(_to, block.number);
           require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
           updateValueAtNow(balances[_to], previousBalanceTo + _amount);

           // An event to make the transfer easy to find on the blockchain
           Transfer(_from, _to, _amount);

           return true;
    }

    /// @param _owner The address that's balance is being requested
    /// @return The balance of `_owner` at the current block
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the approval was successful
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        require(transfersEnabled);

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender,0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_amount == 0) || (allowed[msg.sender][_spender] == 0));

        // Alerts the token controller of the approve function call
        if (isContract(controller)) {
            require(TokenController(controller).onApprove(msg.sender, _spender, _amount));
        }

        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @dev This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender
    ) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /// @notice `msg.sender` approves `_spender` to send `_amount` tokens on
    ///  its behalf, and then a function is triggered in the contract that is
    ///  being approved, `_spender`. This allows users to use their tokens to
    ///  interact with contracts in one function call instead of two
    /// @param _spender The address of the contract able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the function call was successful
    function approveAndCall(address _spender, uint256 _amount, bytes _extraData
    ) public returns (bool success) {
        require(approve(_spender, _amount));

        ApproveAndCallFallBack(_spender).receiveApproval(
            msg.sender,
            _amount,
            this,
            _extraData
        );

        return true;
    }

    /// @dev This function makes it easy to get the total number of tokens
    /// @return The total number of tokens
    function totalSupply() public constant returns (uint) {
        return totalSupplyAt(block.number);
    }


////////////////
// Query balance and totalSupply in History
////////////////

    /// @dev Queries the balance of `_owner` at a specific `_blockNumber`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _blockNumber The block number when the balance is queried
    /// @return The balance at `_blockNumber`
    function balanceOfAt(address _owner, uint _blockNumber) public constant
        returns (uint) {

        // These next few lines are used when the balance of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.balanceOfAt` be queried at the
        //  genesis block for that token as this contains initial balance of
        //  this token
        if ((balances[_owner].length == 0)
            || (balances[_owner][0].fromBlock > _blockNumber)) {
            if (address(parentToken) != 0) {
                return parentToken.balanceOfAt(_owner, min(_blockNumber, parentSnapShotBlock));
            } else {
                // Has no parent
                return 0;
            }

        // This will return the expected balance during normal situations
        } else {
            return getValueAt(balances[_owner], _blockNumber);
        }
    }

    /// @notice Total amount of tokens at a specific `_blockNumber`.
    /// @param _blockNumber The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_blockNumber`
    function totalSupplyAt(uint _blockNumber) public constant returns(uint) {

        // These next few lines are used when the totalSupply of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.totalSupplyAt` be queried at the
        //  genesis block for this token as that contains totalSupply of this
        //  token at this block number.
        if ((totalSupplyHistory.length == 0)
            || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            if (address(parentToken) != 0) {
                return parentToken.totalSupplyAt(min(_blockNumber, parentSnapShotBlock));
            } else {
                return 0;
            }

        // This will return the expected totalSupply during normal situations
        } else {
            return getValueAt(totalSupplyHistory, _blockNumber);
        }
    }

////////////////
// Clone Token Method
////////////////

    /// @notice Creates a new clone token with the initial distribution being
    ///  this token at `_snapshotBlock`
    /// @param _cloneTokenName Name of the clone token
    /// @param _cloneDecimalUnits Number of decimals of the smallest unit
    /// @param _cloneTokenSymbol Symbol of the clone token
    /// @param _snapshotBlock Block when the distribution of the parent token is
    ///  copied to set the initial distribution of the new clone token;
    ///  if the block is zero than the actual block, the current block is used
    /// @param _transfersEnabled True if transfers are allowed in the clone
    /// @return The address of the new MiniMeToken Contract
    function createCloneToken(
        string _cloneTokenName,
        uint8 _cloneDecimalUnits,
        string _cloneTokenSymbol,
        uint _snapshotBlock,
        bool _transfersEnabled
        ) public returns(address) {
        if (_snapshotBlock == 0) _snapshotBlock = block.number;
        MiniMeToken cloneToken = tokenFactory.createCloneToken(
            this,
            _snapshotBlock,
            _cloneTokenName,
            _cloneDecimalUnits,
            _cloneTokenSymbol,
            _transfersEnabled
            );

        cloneToken.changeController(msg.sender);

        // An event to make the token easy to find on the blockchain
        NewCloneToken(address(cloneToken), _snapshotBlock);
        return address(cloneToken);
    }

////////////////
// Generate and destroy tokens
////////////////

    /// @notice Generates `_amount` tokens that are assigned to `_owner`
    /// @param _owner The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @return True if the tokens are generated correctly
    function generateTokens(address _owner, uint _amount
    ) public onlyController returns (bool) {
        uint curTotalSupply = totalSupply();
        require(curTotalSupply + _amount >= curTotalSupply); // Check for overflow
        uint previousBalanceTo = balanceOf(_owner);
        require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
        updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount);
        updateValueAtNow(balances[_owner], previousBalanceTo + _amount);
        Transfer(0, _owner, _amount);
        return true;
    }


    /// @notice Burns `_amount` tokens from `_owner`
    /// @param _owner The address that will lose the tokens
    /// @param _amount The quantity of tokens to burn
    /// @return True if the tokens are burned correctly
    function destroyTokens(address _owner, uint _amount
    ) onlyController public returns (bool) {
        uint curTotalSupply = totalSupply();
        require(curTotalSupply >= _amount);
        uint previousBalanceFrom = balanceOf(_owner);
        require(previousBalanceFrom >= _amount);
        updateValueAtNow(totalSupplyHistory, curTotalSupply - _amount);
        updateValueAtNow(balances[_owner], previousBalanceFrom - _amount);
        Transfer(_owner, 0, _amount);
        return true;
    }

////////////////
// Enable tokens transfers
////////////////


    /// @notice Enables token holders to transfer their tokens freely if true
    /// @param _transfersEnabled True if transfers are allowed in the clone
    function enableTransfers(bool _transfersEnabled) public onlyController {
        transfersEnabled = _transfersEnabled;
    }

////////////////
// Internal helper functions to query and set a value in a snapshot array
////////////////

    /// @dev `getValueAt` retrieves the number of tokens at a given block number
    /// @param checkpoints The history of values being queried
    /// @param _block The block number to retrieve the value at
    /// @return The number of tokens being queried
    function getValueAt(Checkpoint[] storage checkpoints, uint _block
    ) constant internal returns (uint) {
        if (checkpoints.length == 0) return 0;

        // Shortcut for the actual value
        if (_block >= checkpoints[checkpoints.length-1].fromBlock)
            return checkpoints[checkpoints.length-1].value;
        if (_block < checkpoints[0].fromBlock) return 0;

        // Binary search of the value in the array
        uint min = 0;
        uint max = checkpoints.length-1;
        while (max > min) {
            uint mid = (max + min + 1)/ 2;
            if (checkpoints[mid].fromBlock<=_block) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        return checkpoints[min].value;
    }

    /// @dev `updateValueAtNow` used to update the `balances` map and the
    ///  `totalSupplyHistory`
    /// @param checkpoints The history of data being updated
    /// @param _value The new number of tokens
    function updateValueAtNow(Checkpoint[] storage checkpoints, uint _value
    ) internal  {
        if ((checkpoints.length == 0)
        || (checkpoints[checkpoints.length -1].fromBlock < block.number)) {
               Checkpoint storage newCheckPoint = checkpoints[ checkpoints.length++ ];
               newCheckPoint.fromBlock =  uint128(block.number);
               newCheckPoint.value = uint128(_value);
           } else {
               Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length-1];
               oldCheckPoint.value = uint128(_value);
           }
    }

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) constant internal returns(bool) {
        uint size;
        if (_addr == 0) return false;
        assembly {
            size := extcodesize(_addr)
        }
        return size>0;
    }

    /// @dev Helper function to return a min betwen the two uints
    function min(uint a, uint b) pure internal returns (uint) {
        return a < b ? a : b;
    }

    /// @notice The fallback function: If the contract's controller has not been
    ///  set to 0, then the `proxyPayment` method is called which relays the
    ///  ether and creates tokens as described in the token controller contract
    function () public payable {
        require(isContract(controller));
        require(TokenController(controller).proxyPayment.value(msg.value)(msg.sender));
    }

//////////
// Safety Methods
//////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyController {
        if (_token == 0x0) {
            controller.transfer(this.balance);
            return;
        }

        MiniMeToken token = MiniMeToken(_token);
        uint balance = token.balanceOf(this);
        token.transfer(controller, balance);
        ClaimedTokens(_token, controller, balance);
    }

////////////////
// Events
////////////////
    event ClaimedTokens(address indexed _token, address indexed _controller, uint _amount);
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event NewCloneToken(address indexed _cloneToken, uint _snapshotBlock);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
        );

}


////////////////
// MiniMeTokenFactory
////////////////

/// @dev This contract is used to generate clone contracts from a contract.
///  In solidity this is the way to create a contract from a contract of the
///  same class
contract MiniMeTokenFactory {

    /// @notice Update the DApp by creating a new token with new functionalities
    ///  the msg.sender becomes the controller of this clone token
    /// @param _parentToken Address of the token being cloned
    /// @param _snapshotBlock Block of the parent token that will
    ///  determine the initial distribution of the clone token
    /// @param _tokenName Name of the new token
    /// @param _decimalUnits Number of decimals of the new token
    /// @param _tokenSymbol Token Symbol for the new token
    /// @param _transfersEnabled If true, tokens will be able to be transferred
    /// @return The address of the new token contract
    function createCloneToken(
        address _parentToken,
        uint _snapshotBlock,
        string _tokenName,
        uint8 _decimalUnits,
        string _tokenSymbol,
        bool _transfersEnabled
    ) public returns (MiniMeToken) {
        MiniMeToken newToken = new MiniMeToken(
            this,
            _parentToken,
            _snapshotBlock,
            _tokenName,
            _decimalUnits,
            _tokenSymbol,
            _transfersEnabled
            );

        newToken.changeController(msg.sender);
        return newToken;
    }
}


///File: ./contracts/LPPDac.sol

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


///File: @aragon/os/contracts/apps/IAppProxy.sol

pragma solidity 0.4.18;

interface IAppProxy {
    function isUpgradeable() public pure returns (bool);
    function getCode() public view returns (address);
}


///File: @aragon/os/contracts/common/DelegateProxy.sol

pragma solidity 0.4.18;


contract DelegateProxy {
    /**
    * @dev Performs a delegatecall and returns whatever the delegatecall returned (entire context execution will return!)
    * @param _dst Destination address to perform the delegatecall
    * @param _calldata Calldata for the delegatecall
    */
    function delegatedFwd(address _dst, bytes _calldata) internal {
        require(isContract(_dst));
        assembly {
            let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20), mload(_calldata), 0, 0)
            let size := returndatasize

            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)

            // revert instead of invalid() bc if the underlying call failed with invalid() it already wasted gas.
            // if the call returned error data, forward it
            switch result case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    function isContract(address _target) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_target) }
        return size > 0;
    }
}


///File: @aragon/os/contracts/kernel/KernelStorage.sol

pragma solidity 0.4.18;


contract KernelConstants {
    bytes32 constant public CORE_NAMESPACE = keccak256("core");
    bytes32 constant public APP_BASES_NAMESPACE = keccak256("base");
    bytes32 constant public APP_ADDR_NAMESPACE = keccak256("app");

    bytes32 constant public KERNEL_APP_ID = keccak256("kernel.aragonpm.eth");
    bytes32 constant public KERNEL_APP = keccak256(CORE_NAMESPACE, KERNEL_APP_ID);

    bytes32 constant public ACL_APP_ID = keccak256("acl.aragonpm.eth");
    bytes32 constant public ACL_APP = keccak256(APP_ADDR_NAMESPACE, ACL_APP_ID);
}


contract KernelStorage is KernelConstants {
    mapping (bytes32 => address) public apps;
}


///File: @aragon/os/contracts/apps/AppProxyBase.sol

pragma solidity 0.4.18;







contract AppProxyBase is IAppProxy, AppStorage, DelegateProxy, KernelConstants {
    /**
    * @dev Initialize AppProxy
    * @param _kernel Reference to organization kernel for the app
    * @param _appId Identifier for app
    * @param _initializePayload Payload for call to be made after setup to initialize
    */
    function AppProxyBase(IKernel _kernel, bytes32 _appId, bytes _initializePayload) public {
        kernel = _kernel;
        appId = _appId;

        // Implicit check that kernel is actually a Kernel
        // The EVM doesn't actually provide a way for us to make sure, but we can force a revert to
        // occur if the kernel is set to 0x0 or a non-code address when we try to call a method on
        // it.
        address appCode = getAppBase(appId);

        // If initialize payload is provided, it will be executed
        if (_initializePayload.length > 0) {
            require(isContract(appCode));
            // Cannot make delegatecall as a delegateproxy.delegatedFwd as it
            // returns ending execution context and halts contract deployment
            require(appCode.delegatecall(_initializePayload));
        }
    }

    function getAppBase(bytes32 _appId) internal view returns (address) {
        return kernel.getApp(keccak256(APP_BASES_NAMESPACE, _appId));
    }

    function () payable public {
        address target = getCode();
        require(target != 0); // if app code hasn't been set yet, don't call
        delegatedFwd(target, msg.data);
    }
}

///File: @aragon/os/contracts/apps/AppProxyUpgradeable.sol

pragma solidity 0.4.18;




contract AppProxyUpgradeable is AppProxyBase {
    address public pinnedCode;

    /**
    * @dev Initialize AppProxyUpgradeable (makes it an upgradeable Aragon app)
    * @param _kernel Reference to organization kernel for the app
    * @param _appId Identifier for app
    * @param _initializePayload Payload for call to be made after setup to initialize
    */
    function AppProxyUpgradeable(IKernel _kernel, bytes32 _appId, bytes _initializePayload)
             AppProxyBase(_kernel, _appId, _initializePayload) public
    {

    }

    function getCode() public view returns (address) {
        return getAppBase(appId);
    }

    function isUpgradeable() public pure returns (bool) {
        return true;
    }
}


///File: @aragon/os/contracts/apps/AppProxyPinned.sol

pragma solidity 0.4.18;




contract AppProxyPinned is AppProxyBase {
    /**
    * @dev Initialize AppProxyPinned (makes it an un-upgradeable Aragon app)
    * @param _kernel Reference to organization kernel for the app
    * @param _appId Identifier for app
    * @param _initializePayload Payload for call to be made after setup to initialize
    */
    function AppProxyPinned(IKernel _kernel, bytes32 _appId, bytes _initializePayload)
             AppProxyBase(_kernel, _appId, _initializePayload) public
    {
        pinnedCode = getAppBase(appId);
        require(pinnedCode != address(0));
    }

    function getCode() public view returns (address) {
        return pinnedCode;
    }

    function isUpgradeable() public pure returns (bool) {
        return false;
    }

    function () payable public {
        delegatedFwd(getCode(), msg.data);
    }
}

///File: @aragon/os/contracts/factory/AppProxyFactory.sol

pragma solidity 0.4.18;





contract AppProxyFactory {
    event NewAppProxy(address proxy);

    function newAppProxy(IKernel _kernel, bytes32 _appId) public returns (AppProxyUpgradeable) {
        return newAppProxy(_kernel, _appId, new bytes(0));
    }

    function newAppProxy(IKernel _kernel, bytes32 _appId, bytes _initializePayload) public returns (AppProxyUpgradeable) {
        AppProxyUpgradeable proxy = new AppProxyUpgradeable(_kernel, _appId, _initializePayload);
        NewAppProxy(address(proxy));
        return proxy;
    }

    function newAppProxyPinned(IKernel _kernel, bytes32 _appId) public returns (AppProxyPinned) {
        return newAppProxyPinned(_kernel, _appId, new bytes(0));
    }

    function newAppProxyPinned(IKernel _kernel, bytes32 _appId, bytes _initializePayload) public returns (AppProxyPinned) {
        AppProxyPinned proxy = new AppProxyPinned(_kernel, _appId, _initializePayload);
        NewAppProxy(address(proxy));
        return proxy;
    }
}


///File: @aragon/os/contracts/kernel/Kernel.sol

pragma solidity 0.4.18;









contract Kernel is IKernel, KernelStorage, Initializable, AppProxyFactory, ACLSyntaxSugar {
    bytes32 constant public APP_MANAGER_ROLE = keccak256("APP_MANAGER_ROLE");

    /**
    * @dev Initialize can only be called once. It saves the block number in which it was initialized.
    * @notice Initializes a kernel instance along with its ACL and sets `_permissionsCreator` as the entity that can create other permissions
    * @param _baseAcl Address of base ACL app
    * @param _permissionsCreator Entity that will be given permission over createPermission
    */
    function initialize(address _baseAcl, address _permissionsCreator) onlyInit public {
        initialized();

        IACL acl = IACL(newAppProxy(this, ACL_APP_ID));

        _setApp(APP_BASES_NAMESPACE, ACL_APP_ID, _baseAcl);
        _setApp(APP_ADDR_NAMESPACE, ACL_APP_ID, acl);

        acl.initialize(_permissionsCreator);
    }

    /**
    * @dev Create a new instance of an app linked to this kernel and set its base
    *      implementation if it was not already set
    * @param _name Name of the app
    * @param _appBase Address of the app's base implementation
    * @return AppProxy instance
    */
    function newAppInstance(bytes32 _name, address _appBase) auth(APP_MANAGER_ROLE, arr(APP_BASES_NAMESPACE, _name)) public returns (IAppProxy appProxy) {
        _setAppIfNew(APP_BASES_NAMESPACE, _name, _appBase);
        appProxy = newAppProxy(this, _name);
    }

    /**
    * @dev Create a new pinned instance of an app linked to this kernel and set
    *      its base implementation if it was not already set
    * @param _name Name of the app
    * @param _appBase Address of the app's base implementation
    * @return AppProxy instance
    */
    function newPinnedAppInstance(bytes32 _name, address _appBase) auth(APP_MANAGER_ROLE, arr(APP_BASES_NAMESPACE, _name)) public returns (IAppProxy appProxy) {
        _setAppIfNew(APP_BASES_NAMESPACE, _name, _appBase);
        appProxy = newAppProxyPinned(this, _name);
    }

    /**
    * @dev Set the resolving address of an app instance or base implementation
    * @param _namespace App namespace to use
    * @param _name Name of the app
    * @param _app Address of the app
    * @return ID of app
    */
    function setApp(bytes32 _namespace, bytes32 _name, address _app) auth(APP_MANAGER_ROLE, arr(_namespace, _name)) kernelIntegrity public returns (bytes32 id) {
        return _setApp(_namespace, _name, _app);
    }

    /**
    * @dev Get the address of an app instance or base implementation
    * @param _id App identifier
    * @return Address of the app
    */
    function getApp(bytes32 _id) public view returns (address) {
        return apps[_id];
    }

    /**
    * @dev Get the installed ACL app
    * @return ACL app
    */
    function acl() public view returns (IACL) {
        return IACL(getApp(ACL_APP));
    }

    /**
    * @dev Function called by apps to check ACL on kernel or to check permission status
    * @param _who Sender of the original call
    * @param _where Address of the app
    * @param _what Identifier for a group of actions in app
    * @param _how Extra data for ACL auth
    * @return boolean indicating whether the ACL allows the role or not
    */
    function hasPermission(address _who, address _where, bytes32 _what, bytes _how) public view returns (bool) {
        return acl().hasPermission(_who, _where, _what, _how);
    }

    function _setApp(bytes32 _namespace, bytes32 _name, address _app) internal returns (bytes32 id) {
        id = keccak256(_namespace, _name);
        apps[id] = _app;
        SetApp(_namespace, _name, id, _app);
    }

    function _setAppIfNew(bytes32 _namespace, bytes32 _name, address _app) internal returns (bytes32 id) {
        id = keccak256(_namespace, _name);

        if (_app != address(0)) {
            address app = getApp(id);
            if (app != address(0)) {
                require(app == _app);
            } else {
                apps[id] = _app;
                SetApp(_namespace, _name, id, _app);
            }
        }
    }

    modifier auth(bytes32 _role, uint256[] memory params) {
        bytes memory how;
        uint256 byteLength = params.length * 32;
        assembly {
            how := params // forced casting
            mstore(how, byteLength)
        }
        // Params is invalid from this point fwd
        require(hasPermission(msg.sender, address(this), _role, how));
        _;
    }

    modifier kernelIntegrity {
        _; // After execution check integrity
        address kernel = getApp(KERNEL_APP);
        uint256 size;
        assembly { size := extcodesize(kernel) }
        require(size > 0);
    }
}


///File: @aragon/os/contracts/acl/ACL.sol

pragma solidity 0.4.18;






interface ACLOracle {
    function canPerform(address who, address where, bytes32 what) public view returns (bool);
}


contract ACL is IACL, AragonApp, ACLHelpers {
    bytes32 constant public CREATE_PERMISSIONS_ROLE = keccak256("CREATE_PERMISSIONS_ROLE");

    // whether a certain entity has a permission
    mapping (bytes32 => bytes32) permissions; // 0 for no permission, or parameters id
    mapping (bytes32 => Param[]) public permissionParams;

    // who is the manager of a permission
    mapping (bytes32 => address) permissionManager;

    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, NOT, AND, OR, XOR, IF_ELSE, RET } // op types

    struct Param {
        uint8 id;
        uint8 op;
        uint240 value; // even though value is an uint240 it can store addresses
        // in the case of 32 byte hashes losing 2 bytes precision isn't a huge deal
        // op and id take less than 1 byte each so it can be kept in 1 sstore
    }

    uint8 constant BLOCK_NUMBER_PARAM_ID = 200;
    uint8 constant TIMESTAMP_PARAM_ID    = 201;
    uint8 constant SENDER_PARAM_ID       = 202;
    uint8 constant ORACLE_PARAM_ID       = 203;
    uint8 constant LOGIC_OP_PARAM_ID     = 204;
    uint8 constant PARAM_VALUE_PARAM_ID  = 205;
    // TODO: Add execution times param type?

    bytes32 constant public EMPTY_PARAM_HASH = keccak256(uint256(0));
    address constant ANY_ENTITY = address(-1);

    modifier onlyPermissionManager(address _app, bytes32 _role) {
        require(msg.sender == getPermissionManager(_app, _role));
        _;
    }

    event SetPermission(address indexed entity, address indexed app, bytes32 indexed role, bool allowed);
    event ChangePermissionManager(address indexed app, bytes32 indexed role, address indexed manager);

    /**
    * @dev Initialize can only be called once. It saves the block number in which it was initialized.
    * @notice Initializes an ACL instance and sets `_permissionsCreator` as the entity that can create other permissions
    * @param _permissionsCreator Entity that will be given permission over createPermission
    */
    function initialize(address _permissionsCreator) onlyInit public {
        initialized();
        require(msg.sender == address(kernel));

        _createPermission(_permissionsCreator, this, CREATE_PERMISSIONS_ROLE, _permissionsCreator);
    }

    /**
    * @dev Creates a permission that wasn't previously set. Access is limited by the ACL.
    *      If a created permission is removed it is possible to reset it with createPermission.
    * @notice Create a new permission granting `_entity` the ability to perform actions of role `_role` on `_app` (setting `_manager` as the permission manager)
    * @param _entity Address of the whitelisted entity that will be able to perform the role
    * @param _app Address of the app in which the role will be allowed (requires app to depend on kernel for ACL)
    * @param _role Identifier for the group of actions in app given access to perform
    * @param _manager Address of the entity that will be able to grant and revoke the permission further.
    */
    function createPermission(address _entity, address _app, bytes32 _role, address _manager) external {
        require(hasPermission(msg.sender, address(this), CREATE_PERMISSIONS_ROLE));

        _createPermission(_entity, _app, _role, _manager);
    }

    /**
    * @dev Grants permission if allowed. This requires `msg.sender` to be the permission manager
    * @notice Grants `_entity` the ability to perform actions of role `_role` on `_app`
    * @param _entity Address of the whitelisted entity that will be able to perform the role
    * @param _app Address of the app in which the role will be allowed (requires app to depend on kernel for ACL)
    * @param _role Identifier for the group of actions in app given access to perform
    */
    function grantPermission(address _entity, address _app, bytes32 _role)
        external
    {
        grantPermissionP(_entity, _app, _role, new uint256[](0));
    }

    /**
    * @dev Grants a permission with parameters if allowed. This requires `msg.sender` to be the permission manager
    * @notice Grants `_entity` the ability to perform actions of role `_role` on `_app`
    * @param _entity Address of the whitelisted entity that will be able to perform the role
    * @param _app Address of the app in which the role will be allowed (requires app to depend on kernel for ACL)
    * @param _role Identifier for the group of actions in app given access to perform
    * @param _params Permission parameters
    */
    function grantPermissionP(address _entity, address _app, bytes32 _role, uint256[] _params)
        onlyPermissionManager(_app, _role)
        public
    {
        require(!hasPermission(_entity, _app, _role));

        bytes32 paramsHash = _params.length > 0 ? _saveParams(_params) : EMPTY_PARAM_HASH;
        _setPermission(_entity, _app, _role, paramsHash);
    }

    /**
    * @dev Revokes permission if allowed. This requires `msg.sender` to be the the permission manager
    * @notice Revokes `_entity` the ability to perform actions of role `_role` on `_app`
    * @param _entity Address of the whitelisted entity to revoke access from
    * @param _app Address of the app in which the role will be revoked
    * @param _role Identifier for the group of actions in app being revoked
    */
    function revokePermission(address _entity, address _app, bytes32 _role)
        onlyPermissionManager(_app, _role)
        external
    {
        require(hasPermission(_entity, _app, _role));

        _setPermission(_entity, _app, _role, bytes32(0));
    }

    /**
    * @notice Sets `_newManager` as the manager of the permission `_role` in `_app`
    * @param _newManager Address for the new manager
    * @param _app Address of the app in which the permission management is being transferred
    * @param _role Identifier for the group of actions being transferred
    */
    function setPermissionManager(address _newManager, address _app, bytes32 _role)
        onlyPermissionManager(_app, _role)
        external
    {
        _setPermissionManager(_newManager, _app, _role);
    }

    /**
    * @dev Get manager for permission
    * @param _app Address of the app
    * @param _role Identifier for a group of actions in app
    * @return address of the manager for the permission
    */
    function getPermissionManager(address _app, bytes32 _role) public view returns (address) {
        return permissionManager[roleHash(_app, _role)];
    }

    /**
    * @dev Function called by apps to check ACL on kernel or to check permission statu
    * @param _who Sender of the original call
    * @param _where Address of the app
    * @param _where Identifier for a group of actions in app
    * @param _how Permission parameters
    * @return boolean indicating whether the ACL allows the role or not
    */
    function hasPermission(address _who, address _where, bytes32 _what, bytes memory _how) public view returns (bool) {
        uint256[] memory how;
        uint256 intsLength = _how.length / 32;
        assembly {
            how := _how // forced casting
            mstore(how, intsLength)
        }
        // _how is invalid from this point fwd
        return hasPermission(_who, _where, _what, how);
    }

    function hasPermission(address _who, address _where, bytes32 _what, uint256[] memory _how) public view returns (bool) {
        bytes32 whoParams = permissions[permissionHash(_who, _where, _what)];
        if (whoParams != bytes32(0) && evalParams(whoParams, _who, _where, _what, _how)) {
            return true;
        }

        bytes32 anyParams = permissions[permissionHash(ANY_ENTITY, _where, _what)];
        if (anyParams != bytes32(0) && evalParams(anyParams, ANY_ENTITY, _where, _what, _how)) {
            return true;
        }

        return false;
    }

    function hasPermission(address _who, address _where, bytes32 _what) public view returns (bool) {
        uint256[] memory empty = new uint256[](0);
        return hasPermission(_who, _where, _what, empty);
    }

    /**
    * @dev Internal createPermission for access inside the kernel (on instantiation)
    */
    function _createPermission(address _entity, address _app, bytes32 _role, address _manager) internal {
        // only allow permission creation (or re-creation) when there is no manager
        require(getPermissionManager(_app, _role) == address(0));

        _setPermission(_entity, _app, _role, EMPTY_PARAM_HASH);
        _setPermissionManager(_manager, _app, _role);
    }

    /**
    * @dev Internal function called to actually save the permission
    */
    function _setPermission(address _entity, address _app, bytes32 _role, bytes32 _paramsHash) internal {
        permissions[permissionHash(_entity, _app, _role)] = _paramsHash;

        SetPermission(_entity, _app, _role, _paramsHash != bytes32(0));
    }

    function _saveParams(uint256[] _encodedParams) internal returns (bytes32) {
        bytes32 paramHash = keccak256(_encodedParams);
        Param[] storage params = permissionParams[paramHash];

        if (params.length == 0) { // params not saved before
            for (uint256 i = 0; i < _encodedParams.length; i++) {
                uint256 encodedParam = _encodedParams[i];
                Param memory param = Param(decodeParamId(encodedParam), decodeParamOp(encodedParam), uint240(encodedParam));
                params.push(param);
            }
        }

        return paramHash;
    }

    function evalParams(
        bytes32 _paramsHash,
        address _who,
        address _where,
        bytes32 _what,
        uint256[] _how
    ) internal view returns (bool)
    {
        if (_paramsHash == EMPTY_PARAM_HASH) {
            return true;
        }

        return evalParam(_paramsHash, 0, _who, _where, _what, _how);
    }

    function evalParam(
        bytes32 _paramsHash,
        uint32 _paramId,
        address _who,
        address _where,
        bytes32 _what,
        uint256[] _how
    ) internal view returns (bool)
    {
        if (_paramId >= permissionParams[_paramsHash].length) {
            return false; // out of bounds
        }

        Param memory param = permissionParams[_paramsHash][_paramId];

        if (param.id == LOGIC_OP_PARAM_ID) {
            return evalLogic(param, _paramsHash, _who, _where, _what, _how);
        }

        uint256 value;
        uint256 comparedTo = uint256(param.value);

        // get value
        if (param.id == ORACLE_PARAM_ID) {
            value = ACLOracle(param.value).canPerform(_who, _where, _what) ? 1 : 0;
            comparedTo = 1;
        } else if (param.id == BLOCK_NUMBER_PARAM_ID) {
            value = blockN();
        } else if (param.id == TIMESTAMP_PARAM_ID) {
            value = time();
        } else if (param.id == SENDER_PARAM_ID) {
            value = uint256(msg.sender);
        } else if (param.id == PARAM_VALUE_PARAM_ID) {
            value = uint256(param.value);
        } else {
            if (param.id >= _how.length) {
                return false;
            }
            value = uint256(uint240(_how[param.id])); // force lost precision
        }

        if (Op(param.op) == Op.RET) {
            return uint256(value) > 0;
        }

        return compare(value, Op(param.op), comparedTo);
    }

    function evalLogic(Param _param, bytes32 _paramsHash, address _who, address _where, bytes32 _what, uint256[] _how) internal view returns (bool) {
        if (Op(_param.op) == Op.IF_ELSE) {
            var (condition, success, failure) = decodeParamsList(uint256(_param.value));
            bool result = evalParam(_paramsHash, condition, _who, _where, _what, _how);

            return evalParam(_paramsHash, result ? success : failure, _who, _where, _what, _how);
        }

        var (v1, v2,) = decodeParamsList(uint256(_param.value));
        bool r1 = evalParam(_paramsHash, v1, _who, _where, _what, _how);

        if (Op(_param.op) == Op.NOT) {
            return !r1;
        }

        if (r1 && Op(_param.op) == Op.OR) {
            return true;
        }

        if (!r1 && Op(_param.op) == Op.AND) {
            return false;
        }

        bool r2 = evalParam(_paramsHash, v2, _who, _where, _what, _how);

        if (Op(_param.op) == Op.XOR) {
            return (r1 && !r2) || (!r1 && r2);
        }

        return r2; // both or and and depend on result of r2 after checks
    }

    function compare(uint256 _a, Op _op, uint256 _b) internal pure returns (bool) {
        if (_op == Op.EQ)  return _a == _b;                              // solium-disable-line lbrace
        if (_op == Op.NEQ) return _a != _b;                              // solium-disable-line lbrace
        if (_op == Op.GT)  return _a > _b;                               // solium-disable-line lbrace
        if (_op == Op.LT)  return _a < _b;                               // solium-disable-line lbrace
        if (_op == Op.GTE) return _a >= _b;                              // solium-disable-line lbrace
        if (_op == Op.LTE) return _a <= _b;                              // solium-disable-line lbrace
        return false;
    }

    /**
    * @dev Internal function that sets management
    */
    function _setPermissionManager(address _newManager, address _app, bytes32 _role) internal {
        permissionManager[roleHash(_app, _role)] = _newManager;
        ChangePermissionManager(_app, _role, _newManager);
    }

    function roleHash(address _where, bytes32 _what) pure internal returns (bytes32) {
        return keccak256(uint256(1), _where, _what);
    }

    function permissionHash(address _who, address _where, bytes32 _what) pure internal returns (bytes32) {
        return keccak256(uint256(2), _who, _where, _what);
    }

    function time() internal view returns (uint64) { return uint64(block.timestamp); } // solium-disable-line security/no-block-members

    function blockN() internal view returns (uint256) { return block.number; }
}


///File: giveth-liquidpledging/contracts/LPConstants.sol

pragma solidity ^0.4.18;



contract LPConstants is KernelConstants {
    bytes32 constant public VAULT_APP_ID = keccak256("vault");
    bytes32 constant public LP_APP_ID = keccak256("liquidPledging");
}

///File: giveth-common-contracts/contracts/Owned.sol

pragma solidity ^0.4.15;


/// @title Owned
/// @author Adrià Massanet <adria@codecontext.io>
/// @notice The Owned contract has an owner address, and provides basic 
///  authorization control functions, this simplifies & the implementation of
///  user permissions; this contract has three work flows for a change in
///  ownership, the first requires the new owner to validate that they have the
///  ability to accept ownership, the second allows the ownership to be
///  directly transfered without requiring acceptance, and the third allows for
///  the ownership to be removed to allow for decentralization 
contract Owned {

    address public owner;
    address public newOwnerCandidate;

    event OwnershipRequested(address indexed by, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);
    event OwnershipRemoved();

    /// @dev The constructor sets the `msg.sender` as the`owner` of the contract
    function Owned() public {
        owner = msg.sender;
    }

    /// @dev `owner` is the only address that can call a function with this
    /// modifier
    modifier onlyOwner() {
        require (msg.sender == owner);
        _;
    }
    
    /// @dev In this 1st option for ownership transfer `proposeOwnership()` must
    ///  be called first by the current `owner` then `acceptOwnership()` must be
    ///  called by the `newOwnerCandidate`
    /// @notice `onlyOwner` Proposes to transfer control of the contract to a
    ///  new owner
    /// @param _newOwnerCandidate The address being proposed as the new owner
    function proposeOwnership(address _newOwnerCandidate) public onlyOwner {
        newOwnerCandidate = _newOwnerCandidate;
        OwnershipRequested(msg.sender, newOwnerCandidate);
    }

    /// @notice Can only be called by the `newOwnerCandidate`, accepts the
    ///  transfer of ownership
    function acceptOwnership() public {
        require(msg.sender == newOwnerCandidate);

        address oldOwner = owner;
        owner = newOwnerCandidate;
        newOwnerCandidate = 0x0;

        OwnershipTransferred(oldOwner, owner);
    }

    /// @dev In this 2nd option for ownership transfer `changeOwnership()` can
    ///  be called and it will immediately assign ownership to the `newOwner`
    /// @notice `owner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner
    function changeOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != 0x0);

        address oldOwner = owner;
        owner = _newOwner;
        newOwnerCandidate = 0x0;

        OwnershipTransferred(oldOwner, owner);
    }

    /// @dev In this 3rd option for ownership transfer `removeOwnership()` can
    ///  be called and it will immediately assign ownership to the 0x0 address;
    ///  it requires a 0xdece be input as a parameter to prevent accidental use
    /// @notice Decentralizes the contract, this operation cannot be undone 
    /// @param _dac `0xdac` has to be entered for this function to work
    function removeOwnership(address _dac) public onlyOwner {
        require(_dac == 0xdac);
        owner = 0x0;
        newOwnerCandidate = 0x0;
        OwnershipRemoved();     
    }
} 


///File: giveth-common-contracts/contracts/Escapable.sol

pragma solidity ^0.4.15;
/*
    Copyright 2016, Jordi Baylina
    Contributor: Adrià Massanet <adria@codecontext.io>

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





/// @dev `Escapable` is a base level contract built off of the `Owned`
///  contract; it creates an escape hatch function that can be called in an
///  emergency that will allow designated addresses to send any ether or tokens
///  held in the contract to an `escapeHatchDestination` as long as they were
///  not blacklisted
contract Escapable is Owned {
    address public escapeHatchCaller;
    address public escapeHatchDestination;
    mapping (address=>bool) private escapeBlacklist; // Token contract addresses

    /// @notice The Constructor assigns the `escapeHatchDestination` and the
    ///  `escapeHatchCaller`
    /// @param _escapeHatchCaller The address of a trusted account or contract
    ///  to call `escapeHatch()` to send the ether in this contract to the
    ///  `escapeHatchDestination` it would be ideal that `escapeHatchCaller`
    ///  cannot move funds out of `escapeHatchDestination`
    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract; if a neutral address
    ///  is required, the WHG Multisig is an option:
    ///  0x8Ff920020c8AD673661c8117f2855C384758C572 
    function Escapable(address _escapeHatchCaller, address _escapeHatchDestination) public {
        escapeHatchCaller = _escapeHatchCaller;
        escapeHatchDestination = _escapeHatchDestination;
    }

    /// @dev The addresses preassigned as `escapeHatchCaller` or `owner`
    ///  are the only addresses that can call a function with this modifier
    modifier onlyEscapeHatchCallerOrOwner {
        require ((msg.sender == escapeHatchCaller)||(msg.sender == owner));
        _;
    }

    /// @notice Creates the blacklist of tokens that are not able to be taken
    ///  out of the contract; can only be done at the deployment, and the logic
    ///  to add to the blacklist will be in the constructor of a child contract
    /// @param _token the token contract address that is to be blacklisted 
    function blacklistEscapeToken(address _token) internal {
        escapeBlacklist[_token] = true;
        EscapeHatchBlackistedToken(_token);
    }

    /// @notice Checks to see if `_token` is in the blacklist of tokens
    /// @param _token the token address being queried
    /// @return False if `_token` is in the blacklist and can't be taken out of
    ///  the contract via the `escapeHatch()`
    function isTokenEscapable(address _token) constant public returns (bool) {
        return !escapeBlacklist[_token];
    }

    /// @notice The `escapeHatch()` should only be called as a last resort if a
    /// security issue is uncovered or something unexpected happened
    /// @param _token to transfer, use 0x0 for ether
    function escapeHatch(address _token) public onlyEscapeHatchCallerOrOwner {   
        require(escapeBlacklist[_token]==false);

        uint256 balance;

        /// @dev Logic for ether
        if (_token == 0x0) {
            balance = this.balance;
            escapeHatchDestination.transfer(balance);
            EscapeHatchCalled(_token, balance);
            return;
        }
        /// @dev Logic for tokens
        ERC20 token = ERC20(_token);
        balance = token.balanceOf(this);
        require(token.transfer(escapeHatchDestination, balance));
        EscapeHatchCalled(_token, balance);
    }

    /// @notice Changes the address assigned to call `escapeHatch()`
    /// @param _newEscapeHatchCaller The address of a trusted account or
    ///  contract to call `escapeHatch()` to send the value in this contract to
    ///  the `escapeHatchDestination`; it would be ideal that `escapeHatchCaller`
    ///  cannot move funds out of `escapeHatchDestination`
    function changeHatchEscapeCaller(address _newEscapeHatchCaller) public onlyEscapeHatchCallerOrOwner {
        escapeHatchCaller = _newEscapeHatchCaller;
    }

    event EscapeHatchBlackistedToken(address token);
    event EscapeHatchCalled(address token, uint amount);
}


///File: ./contracts/LPPDacFactory.sol

pragma solidity ^0.4.18;











contract LPPDacFactory is LPConstants, Escapable, AppProxyFactory {
    Kernel public kernel;
    MiniMeTokenFactory public tokenFactory;

    bytes32 constant public DAC_APP_ID = keccak256("lpp-dac");
    bytes32 constant public DAC_APP = keccak256(APP_BASES_NAMESPACE, DAC_APP_ID);
    bytes32 constant public LP_APP_INSTANCE = keccak256(APP_ADDR_NAMESPACE, LP_APP_ID);

    event DeployDac(address dac);

    function LPPDacFactory(address _kernel, address _tokenFactory, address _escapeHatchCaller, address _escapeHatchDestination)
        Escapable(_escapeHatchCaller, _escapeHatchDestination) public
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
        string tokenSymbol,
        address escapeHatchCaller,
        address escapeHatchDestination
    ) public
    { 
        // TODO: could make MiniMeToken an AragonApp to save gas by deploying a proxy
        address token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);
        newDac(name, url, commitTime, token, escapeHatchCaller, escapeHatchDestination);
    }

    function newDac(
        string name,
        string url,
        uint64 commitTime,
        address _token,
        address escapeHatchCaller,
        address escapeHatchDestination
    ) public
    {
        address dacBase = kernel.getApp(DAC_APP);
        require(dacBase != 0);
        address liquidPledging = kernel.getApp(LP_APP_INSTANCE);
        require(liquidPledging != 0);

        LPPDac dac = LPPDac(newAppProxy(kernel, DAC_APP_ID));

        LiquidPledging(liquidPledging).addValidPluginInstance(address(dac));

        dac.initialize(liquidPledging, _token, name, url, commitTime, escapeHatchDestination);
        MiniMeToken(_token).changeController(address(dac));

        ACL acl = ACL(kernel.acl());

        bytes32 hatchCallerRole = dac.ESCAPE_HATCH_CALLER_ROLE();
        bytes32 adminRole = dac.ADMIN_ROLE();

        // this permission is managed by the escapeHatchCaller
        acl.createPermission(escapeHatchCaller, address(dac), hatchCallerRole, escapeHatchCaller);
        // this permission is managed by msg.sender
        acl.createPermission(msg.sender, address(dac), adminRole, msg.sender);

        DeployDac(address(dac));
    }
}


///File: ./contracts/LPPDacFactory.sol

pragma solidity ^0.4.18;











contract LPPDacFactory is LPConstants, Escapable, AppProxyFactory {
    Kernel public kernel;
    MiniMeTokenFactory public tokenFactory;

    bytes32 constant public DAC_APP_ID = keccak256("lpp-dac");
    bytes32 constant public DAC_APP = keccak256(APP_BASES_NAMESPACE, DAC_APP_ID);
    bytes32 constant public LP_APP_INSTANCE = keccak256(APP_ADDR_NAMESPACE, LP_APP_ID);

    event DeployDac(address dac);

    function LPPDacFactory(address _kernel, address _tokenFactory, address _escapeHatchCaller, address _escapeHatchDestination)
        Escapable(_escapeHatchCaller, _escapeHatchDestination) public
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
        string tokenSymbol,
        address escapeHatchCaller,
        address escapeHatchDestination
    ) public
    { 
        // TODO: could make MiniMeToken an AragonApp to save gas by deploying a proxy
        address token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);
        newDac(name, url, commitTime, token, escapeHatchCaller, escapeHatchDestination);
    }

    function newDac(
        string name,
        string url,
        uint64 commitTime,
        address _token,
        address escapeHatchCaller,
        address escapeHatchDestination
    ) public
    {
        address dacBase = kernel.getApp(DAC_APP);
        require(dacBase != 0);
        address liquidPledging = kernel.getApp(LP_APP_INSTANCE);
        require(liquidPledging != 0);

        LPPDac dac = LPPDac(newAppProxy(kernel, DAC_APP_ID));

        LiquidPledging(liquidPledging).addValidPluginInstance(address(dac));

        dac.initialize(liquidPledging, _token, name, url, commitTime, escapeHatchDestination);
        MiniMeToken(_token).changeController(address(dac));

        ACL acl = ACL(kernel.acl());

        bytes32 hatchCallerRole = dac.ESCAPE_HATCH_CALLER_ROLE();
        bytes32 adminRole = dac.ADMIN_ROLE();

        // this permission is managed by the escapeHatchCaller
        acl.createPermission(escapeHatchCaller, address(dac), hatchCallerRole, escapeHatchCaller);
        // this permission is managed by msg.sender
        acl.createPermission(msg.sender, address(dac), adminRole, msg.sender);

        DeployDac(address(dac));
    }
}
