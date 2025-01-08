// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title LockedCYBRO
 * @dev Contract for a locked CYBRO token with vesting functionality.
 */
contract LockedCYBRO is ERC20, Ownable {
    using SafeERC20 for IERC20Metadata;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /* ========== IMMUTABLE STATE VARIABLES ========== */

    /// @notice Timestamp of the Token Generation Event (TGE)
    uint256 public immutable tgeTimestamp;

    /// @notice Timestamp when vesting period starts
    uint256 public immutable vestingStart;

    /// @notice Duration of the vesting period in seconds
    uint256 public immutable vestingDuration;

    /// @notice Percentage of tokens released at TGE
    uint8 public immutable tgePercent;

    /// @notice Address of the underlying CYBRO token
    address public immutable cybro;

    /* ========== STATE VARIABLES ========== */

    /// @notice Total token allocation for each user
    mapping(address account => uint256) public allocations;

    /// @notice Amount of CYBRO tokens claimed by each user
    mapping(address account => uint256) public claimedAmount;

    /// @notice Addresses authorized to receive transfers
    mapping(address account => bool) public transferWhitelist;

    /// @notice Addresses authorized to mint tokens
    mapping(address minter => bool) public mintersWhitelist;

    /// @notice Flag indicating if users can mint tokens via signature
    bool public mintableByUsers;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Initializes the contract with vesting and TGE parameters, and sets up access control.
     * @param _lockedCYBROStakings Array of addresses allowed to stake locked CYBRO
     * @param _cybro Address of the CYBRO token
     * @param admin Address of the contract owner
     * @param _tgeTimestamp Timestamp for the token generation event
     * @param _tgePercent Percentage of tokens to be distributed at TGE
     * @param _vestingStart Timestamp when vesting commences
     * @param _vestingDuration Duration of the vesting period
     */
    constructor(
        address[] memory _lockedCYBROStakings,
        address _cybro,
        address admin,
        uint256 _tgeTimestamp,
        uint8 _tgePercent,
        uint256 _vestingStart,
        uint256 _vestingDuration
    ) ERC20("CYBRO Locked Token", "LCYBRO") Ownable(admin) {
        cybro = _cybro;
        tgeTimestamp = _tgeTimestamp;
        tgePercent = _tgePercent;
        vestingStart = _vestingStart;
        vestingDuration = _vestingDuration;

        for (uint256 i = 0; i < _lockedCYBROStakings.length; i++) {
            transferWhitelist[_lockedCYBROStakings[i]] = true;
            mintersWhitelist[_lockedCYBROStakings[i]] = true;
        }

        // Allow whitelisted addresses and admin to initiate minting
        transferWhitelist[address(0)] = true;
        mintersWhitelist[admin] = true;
        mintableByUsers = true;
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice Calculates the total unlocked tokens available for a given user based on the vesting schedule.
     * @param user Address of the user
     * @return The total unlocked token amount
     */
    function getUnlockedAmount(address user) public view returns (uint256) {
        if (block.timestamp < tgeTimestamp) return 0;

        uint256 tgeAmount = allocations[user] * tgePercent / 100;
        if (block.timestamp < vestingStart) return tgeAmount;

        uint256 totalVestedAmount = allocations[user] - tgeAmount;
        uint256 elapsed = Math.min(block.timestamp - vestingStart, vestingDuration);
        uint256 vestedAmount = elapsed * totalVestedAmount / vestingDuration;

        return tgeAmount + vestedAmount;
    }

    /**
     * @notice Calculates the amount of tokens that can be immediately claimed by the user.
     * @param user Address of the user
     * @return The total claimable token amount
     */
    function getClaimableAmount(address user) public view returns (uint256) {
        return Math.min(getUnlockedAmount(user) - claimedAmount[user], balanceOf(user));
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Allows a user to mint tokens for themselves with a signed message.
     * @param user Address of the user minting the tokens
     * @param totalBalance Total balance of tokens to allocate
     * @param signature ECDSA signature from authorized minter
     */
    function mint(address user, uint256 totalBalance, bytes memory signature) external {
        require(mintableByUsers, "CYBRO: mintable by users");
        address signer_ = keccak256(abi.encodePacked(user, totalBalance, address(this), block.chainid))
            .toEthSignedMessageHash().recover(signature);
        require(mintersWhitelist[signer_], "CYBRO: Invalid signature");
        _mint(user, totalBalance - allocations[user]);
        allocations[user] = totalBalance;
    }

    /**
     * @notice Allows whitelisted minters to mint tokens for multiple users.
     * @param users Array of user addresses
     * @param amounts Array of token amounts corresponding to each user
     */
    function mintFor(address[] memory users, uint256[] memory amounts) external {
        require(mintersWhitelist[msg.sender], "CYBRO: you are not in the whitelist");
        for (uint256 i = 0; i < users.length; i++) {
            _mint(users[i], amounts[i] - allocations[users[i]]);
            allocations[users[i]] = amounts[i];
        }
    }

    /**
     * @notice Allows the user to claim available vested tokens.
     */
    function claim() external {
        uint256 amount = getClaimableAmount(msg.sender);
        require(amount > 0, "CYBRO: amount must be gt zero");
        claimedAmount[msg.sender] += amount;
        _burn(msg.sender, amount);
        IERC20Metadata(cybro).safeTransfer(msg.sender, amount);
    }

    /* ========== EXTERNAL OWNER FUNCTIONS ========== */

    /**
     * @notice Adds an address to the transfer whitelist.
     * @param addr Address to be whitelisted
     */
    function addWhitelistedAddress(address addr) external onlyOwner {
        transferWhitelist[addr] = true;
    }

    /**
     * @notice Removes an address from the transfer whitelist.
     * @param addr Address to be removed from the whitelist
     */
    function removeWhitelistedAddress(address addr) external onlyOwner {
        transferWhitelist[addr] = false;
    }

    /**
     * @notice Adds a minter to the whitelist.
     * @param addr Minter address to be whitelisted
     */
    function addMinter(address addr) external onlyOwner {
        mintersWhitelist[addr] = true;
    }

    /**
     * @notice Removes a minter from the whitelist.
     * @param addr Minter address to be removed from the whitelist
     */
    function removeMinter(address addr) external onlyOwner {
        mintersWhitelist[addr] = false;
    }

    /**
     * @notice Sets the permission for users to mint tokens using a signature.
     * @param _mintableByUsers Boolean indicating if minted by users is allowed
     */
    function setMintableByUsers(bool _mintableByUsers) external onlyOwner {
        mintableByUsers = _mintableByUsers;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @dev Overrides the ERC20 transfer logic to enforce transfer whitelist restrictions.
     */
    function _update(address from, address to, uint256 value) internal override {
        if (!transferWhitelist[from] && !transferWhitelist[to]) {
            revert("CYBRO: not whitelisted");
        }
        super._update(from, to, value);
    }
}
