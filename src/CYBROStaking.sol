// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CYBROStaking is Ownable {
    using SafeERC20 for IERC20Metadata;

    struct UserState {
        uint256 balance;
        uint256 lastClaimTimestamp;
        uint256 unlockTimestamp;
        uint256 yearlyReward;
    }

    mapping(address => UserState) public users;
    uint256 public lockTime;
    uint32 public percent;

    /// @notice Token being staked.
    IERC20Metadata public immutable stakeToken;

    /// @notice Minimal balance for stake.
    uint256 public minBalance;

    /// @notice Counter of deposits - withdrawals. Contains amount of funds owned by users
    /// which are kept in the contract.
    uint256 public totalLocked;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _stakeToken, uint256 _lockTime, uint32 _percent) Ownable(_owner) {
        lockTime = _lockTime;
        percent = _percent;
        stakeToken = IERC20Metadata(_stakeToken);
    }

    /// @notice Ensures that balance of the contract is not lower than total amount owed to
    /// users besides rewards.
    modifier ensureSolvency() virtual {
        _;
        require(stakeToken.balanceOf(address(this)) >= totalLocked, "CYBRO: insolvency");
    }

    /* ========== VIEWS ========== */

    function getRewardOf(address addr) public view virtual returns (uint256) {
        UserState memory user = users[addr];

        uint256 elapsed = user.lastClaimTimestamp > user.unlockTimestamp
            ? 0
            : Math.min(block.timestamp - user.lastClaimTimestamp, user.unlockTimestamp - user.lastClaimTimestamp);

        return user.yearlyReward * elapsed / 365 days;
    }

    /* ========== FUNCTIONS ========== */

    function setMinBalance(uint256 _minBalance) external onlyOwner {
        minBalance = _minBalance;
    }

    /// @notice Set lock time and percent
    function setLockTimeAndPercent(uint256 _lockTime, uint32 _percent) external onlyOwner {
        lockTime = _lockTime;
        percent = _percent;
    }

    /// @notice Stake given amount for given amount of time
    /// If user already has staked amount, lock is restarted.
    function stake(uint256 amount) external {
        UserState storage user = users[msg.sender];

        require(user.balance + amount >= minBalance, "CYBRO: you must send more to stake");
        require(amount > 0, "CYBRO: amount must be gt 0");

        claim();

        user.unlockTimestamp = block.timestamp + lockTime;
        user.balance += amount;
        user.yearlyReward = user.balance * percent / 1e4;
        totalLocked += amount;

        stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw entire balance.
    /// @param force Whether to withdraw without claiming rewards. Should only be used in emergency
    /// cases when contract does not have enough funds to pay out rewards.
    function withdraw(bool force) public {
        UserState storage user = users[msg.sender];

        require(user.unlockTimestamp <= block.timestamp, "CYBRO: you must wait more to withdraw");
        require(user.balance > 0, "CYBRO: you haven't anything for withdraw");

        if (!force) {
            claim();
        }

        uint256 balance = user.balance;
        delete users[msg.sender];

        totalLocked -= balance;
        stakeToken.safeTransfer(msg.sender, balance);
        emit Withdrawn(msg.sender, balance);
    }

    function withdraw() external {
        withdraw(false);
    }

    /// @notice Claim all accrued rewards.
    function claim() public ensureSolvency returns (uint256 reward) {
        UserState storage user = users[msg.sender];
        reward = getRewardOf(msg.sender);
        user.lastClaimTimestamp = block.timestamp;
        if (reward > 0) {
            _sendReward(msg.sender, reward);
            emit Claimed(msg.sender, reward);
        }
    }

    /// @notice Function for administrators to withdraw extra amounts sent to the contract
    /// for reward payouts and for withdraw funds accidentally sent to the contract.
    function withdrawFunds(address token, uint256 amount) external virtual onlyOwner ensureSolvency {
        if (token == address(0)) {
            (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
            require(success, "CYBRO: failed to send ETH");
        } else if (token != address(stakeToken)) {
            IERC20Metadata(token).safeTransfer(msg.sender, IERC20Metadata(token).balanceOf(address(this)));
        } else {
            stakeToken.safeTransfer(msg.sender, amount);
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice Send reward to user
    function _sendReward(address user, uint256 reward) internal virtual {
        stakeToken.safeTransfer(user, reward);
    }

    /* ========== EVENTS ========== */
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
}
