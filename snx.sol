// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Semver
/// @notice Semver is a simple contract for managing contract versions.
contract Semver {
    /// @notice Contract version number (major).
    uint256 private immutable MAJOR_VERSION;

    /// @notice Contract version number (minor).
    uint256 private immutable MINOR_VERSION;

    /// @notice Contract version number (patch).
    uint256 private immutable PATCH_VERSION;

    /// @param _major Version number (major).
    /// @param _minor Version number (minor).
    /// @param _patch Version number (patch).
    constructor(uint256 _major, uint256 _minor, uint256 _patch) {
        MAJOR_VERSION = _major;
        MINOR_VERSION = _minor;
        PATCH_VERSION = _patch;
    }

    /// @notice Returns the full semver contract version.
    /// @return Semver contract version as a string.
    function version() public view returns (string memory) {
        return string(
            abi.encodePacked(
                Strings.toString(MAJOR_VERSION),
                ".",
                Strings.toString(MINOR_VERSION),
                ".",
                Strings.toString(PATCH_VERSION)
            )
        );
    }
}

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title IOptimismMintableERC20
/// @notice This interface is available on the OptimismMintableERC20 contract.
///         We declare it as a separate interface so that it can be used in
///         custom implementations of OptimismMintableERC20.
interface IOptimismMintableERC20 is IERC165 {
    function remoteToken() external view returns (address);

    function bridge() external returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;
}

/// @custom:legacy
/// @title ILegacyMintableERC20
/// @notice This interface was available on the legacy L2StandardERC20 contract.
///         It remains available on the OptimismMintableERC20 contract for
///         backwards compatibility.
interface ILegacyMintableERC20 is IERC165 {
    function l1Token() external view returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;
}

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/// @title OptimismMintableERC20
/// @notice OptimismMintableERC20 is a standard extension of the base ERC20 token contract designed
///         to allow the StandardBridge contracts to mint and burn tokens. This makes it possible to
///         use an OptimismMintablERC20 as the L2 representation of an L1 token, or vice-versa.
///         Designed to be backwards compatible with the older StandardL2ERC20 token which was only
///         meant for use on L2.
contract OptimismMintableERC20 is IOptimismMintableERC20, ILegacyMintableERC20, ERC20, Semver {

    //Use mapping to approve minters as OptimismFactory Tokens are not compatible with OpenZeppelin AccessControl standard
    mapping(address => bool) public minter;

    /// @notice Address of the corresponding version of this token on the remote chain.
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this network.
    address public immutable BRIDGE;

    //Declare pDAO or SC multisig who can add or remove minters.
    address public multisig;

    /// @notice Emitted whenever tokens are minted for an account.
    /// @param account Address of the account tokens are being minted for.
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    /// @param account Address of the account tokens are being burned from.
    /// @param amount  Amount of tokens burned.
    event Burn(address indexed account, uint256 amount);

    /// @notice A modifier that only allows the bridge to call
    modifier onlyBridge() {
        //We rewrite the onlyBridge() call to check for minter status, this way we can be confident the interface will conform to the standard even if there is any changes to the bridge on Base
        require(minter[msg.sender] == true || msg.sender == BRIDGE, "OptimismMintableERC20: only bridge can mint and burn");
        _;
    }

    /// @custom:semver 1.0.3
    /// @param _bridge      Address of the L2 standard bridge.
    /// @param _remoteToken Address of the corresponding L1 token.
    /// @param _name        ERC20 name.
    /// @param _symbol      ERC20 symbol.
    constructor(
        address _bridge,
        address _remoteToken,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        Semver(1, 0, 3)
    {
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;

        //Set bridge to minter
        minter[_bridge] = true;

        //Set multisig as deployer to start, deployer can migrate multisig to pDAO multisig but this way we don't change constructor interface
        multisig = msg.sender;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(
        address _to,
        uint256 _amount
    )
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyBridge
    {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function burn(
        address _from,
        uint256 _amount
    )
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyBridge
    {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    /// @notice ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the legacy L2StandardERC20.
        bytes4 iface2 = type(ILegacyMintableERC20).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2 || _interfaceId == iface3;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the remote token. Use REMOTE_TOKEN going forward.
    function l1Token() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the bridge. Use BRIDGE going forward.
    function l2Bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE.
    function bridge() public view returns (address) {
        return BRIDGE;
    }

    //multisig can transfer ownership to new multisig
    function migrateMultisig(address _address) public {
        require(msg.sender == multisig);
        multisig = _address;
    }

    //multisig can add new minter
    function addMinter(address _address) public {
        require(msg.sender == multisig);
        minter[_address] = true;
    }

    //multisig can remove minters but cannot remove bridge
    function revokeMinter(address _address) public {
        require(msg.sender == multisig);
        minter[_address] = false;
    }
}
