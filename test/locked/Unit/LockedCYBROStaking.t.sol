// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {BaseLockedCYBRO, LockedCYBROStaking, CYBROStaking, LockedCYBRO, IERC20} from "../BaseLockedCYBRO.t.sol";

contract LockedCYBROStakingTest is BaseLockedCYBRO {
    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        lockedCYBRO.setMintableByUsers(false);
    }

    function test_RevertStake_BalanceMustBeGtMin() public {
        uint256 amount = 1e8;

        address[] memory to = new address[](1);
        uint256[] memory amountMint = new uint256[](1);
        amountMint[0] = amount;
        to[0] = user;

        vm.prank(admin);
        lockedCYBRO.mintFor(to, amountMint);
        vm.prank(user);
        lockedCYBRO.approve(address(lockedCYBROStaking), amount);

        vm.startPrank(admin);
        lockedCYBROStaking.setMinBalance(1e5);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert("CYBRO: you must send more to stake");
        lockedCYBROStaking.stake(1);
    }

    function test_stake() public {
        uint256 amount = 2e18;

        address[] memory to = new address[](1);
        uint256[] memory amountMint = new uint256[](1);
        amountMint[0] = amount;
        to[0] = user;

        vm.prank(admin);
        lockedCYBRO.mintFor(to, amountMint);

        vm.startPrank(user);
        lockedCYBRO.approve(address(lockedCYBROStaking3), amount);
        vm.expectEmit(address(lockedCYBROStaking3));
        emit CYBROStaking.Staked(user, amount);
        lockedCYBROStaking3.stake(amount);

        vm.warp(block.timestamp + 900);
        lockedCYBROStaking3.claim();

        vm.warp(1e5);
        assertGt(lockedCYBROStaking3.getRewardOf(user), 0);
    }

    function test_stakeFuzz(uint256 amount) public {
        vm.warp(1001);
        amount = bound(amount, 1e6, 1e40);

        address[] memory to = new address[](1);
        uint256[] memory amountMint = new uint256[](1);
        amountMint[0] = amount;
        to[0] = user;

        vm.prank(admin);
        lockedCYBRO.mintFor(to, amountMint);

        vm.startPrank(user);
        lockedCYBRO.approve(address(lockedCYBROStaking), amount);
        vm.expectEmit(address(lockedCYBROStaking));
        emit CYBROStaking.Staked(user, amount);
        lockedCYBROStaking.stake(amount);
        vm.stopPrank();
        vm.prank(admin);
        vm.expectRevert();
        lockedCYBROStaking.withdrawFunds(address(lockedCYBRO), amount);

        uint256 reward = lockedCYBROStaking.getRewardOf(user);
        assertEq(reward, 0);

        vm.warp(lockTimes[0] * 1e6);
        assertGt(lockedCYBROStaking.getRewardOf(user), 0);
    }

    modifier stake() {
        uint256 amount = 1e18;

        uint256 preCalculatedReward = (amount * percents[0] / 1e4) * lockTimes[0] / 365 days;
        address[] memory to = new address[](1);
        uint256[] memory amountMint = new uint256[](1);
        amountMint[0] = amount;
        to[0] = user;
        vm.prank(admin);
        lockedCYBRO.mintFor(to, amountMint);

        vm.startPrank(user);
        lockedCYBRO.approve(address(lockedCYBROStaking), amount);
        lockedCYBROStaking.stake(amount);
        vm.stopPrank();
        _;
    }

    modifier stakeFuzz(uint256 amount) {
        amount = bound(amount, 1e5, 1e40);

        address[] memory to = new address[](1);
        uint256[] memory amountMint = new uint256[](1);
        amountMint[0] = amount;
        to[0] = user;

        uint256 preCalculatedReward = (amount * percents[0] / 1e4) * lockTimes[0] / 365 days;
        vm.prank(admin);
        lockedCYBRO.mintFor(to, amountMint);

        vm.startPrank(user);
        lockedCYBRO.approve(address(lockedCYBROStaking), amount);
        lockedCYBROStaking.stake(amount);
        vm.stopPrank();
        vm.warp(lockTimes[0] * 1e5);
        _;
    }

    function test_claimFuzz(uint256 amount) public stakeFuzz(amount) {
        uint256 reward = lockedCYBROStaking.getRewardOf(user);
        vm.assume(reward > 0);

        vm.startPrank(user);
        uint256 lockedCYBROBalanceOfUserBefore = lockedCYBRO.balanceOf(user);
        vm.expectEmit(address(lockedCYBRO));
        emit IERC20.Transfer(address(0), user, reward);
        vm.expectEmit(address(lockedCYBROStaking));
        emit CYBROStaking.Claimed(user, reward);
        lockedCYBROStaking.claim();
        assertEq(lockedCYBRO.balanceOf(user), lockedCYBROBalanceOfUserBefore + reward);
        vm.stopPrank();
    }

    function test_RevertWithdraw_UnlockTimestamp() public stake {
        vm.prank(user);
        vm.expectRevert("CYBRO: you must wait more to withdraw");
        lockedCYBROStaking.withdraw();
    }

    function test_withdrawFuzz(uint256 amount) public stakeFuzz(amount) {
        uint256 reward = lockedCYBROStaking.getRewardOf(user);
        vm.assume(reward > 0);
        uint256 lockedCYBROBalanceOfUserBefore = lockedCYBRO.balanceOf(user);
        (uint256 balance,,,) = lockedCYBROStaking.users(user);

        vm.prank(user);
        lockedCYBROStaking.withdraw();

        assertEq(lockedCYBRO.balanceOf(user), lockedCYBROBalanceOfUserBefore + balance + reward);
    }
}
