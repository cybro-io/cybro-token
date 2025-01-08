// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {LockedCYBRO} from "../../src/LockedCYBRO.sol";
import {LockedCYBROStaking, CYBROStaking} from "../../src/LockedCYBROStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BaseLockedCYBRO is Test {
    ERC20Mock cybro;

    address internal admin;
    uint256 internal adminPrivateKey;

    LockedCYBRO lockedCYBRO;
    LockedCYBROStaking lockedCYBROStaking;
    LockedCYBROStaking lockedCYBROStaking2;
    LockedCYBROStaking lockedCYBROStaking3;
    address[] lockedCYBROStakingAddresses;
    uint256[] lockTimes;
    uint32[] percents;

    address user;
    address user2;
    address user3;

    function setUp() public virtual {
        adminPrivateKey = 0xa11ce;
        admin = vm.addr(adminPrivateKey);
        user = address(10);
        user2 = address(11);
        user3 = address(12);
        lockTimes.push(1000);
        percents.push(10 * 1e2);
        lockTimes.push(2000);
        percents.push(20 * 1e2);
        lockTimes.push(3000);
        percents.push(30 * 1e2);

        vm.startPrank(admin);
        cybro = new ERC20Mock("CYBRO", "CYBRO", 18);
        lockedCYBROStakingAddresses.push(vm.computeCreateAddress(address(admin), vm.getNonce(admin) + 1));
        lockedCYBROStakingAddresses.push(vm.computeCreateAddress(address(admin), vm.getNonce(admin) + 2));
        lockedCYBROStakingAddresses.push(vm.computeCreateAddress(address(admin), vm.getNonce(admin) + 3));
        lockedCYBRO = new LockedCYBRO(lockedCYBROStakingAddresses, address(cybro), admin, 1000, 10, 2000, 10000);
        lockedCYBROStaking = new LockedCYBROStaking(admin, address(lockedCYBRO), lockTimes[0], percents[0]);
        lockedCYBROStaking2 = new LockedCYBROStaking(admin, address(lockedCYBRO), lockTimes[1], percents[1]);
        lockedCYBROStaking3 = new LockedCYBROStaking(admin, address(lockedCYBRO), lockTimes[2], percents[2]);
        vm.stopPrank();
        vm.assertEq(lockedCYBRO.transferWhitelist(address(lockedCYBROStakingAddresses[0])), true);
        vm.assertEq(address(cybro), lockedCYBRO.cybro());
    }
}
