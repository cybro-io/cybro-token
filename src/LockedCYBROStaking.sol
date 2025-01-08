// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.26;

import {CYBROStaking} from "./CYBROStaking.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LockedCYBRO} from "./LockedCYBRO.sol";

contract LockedCYBROStaking is Ownable, CYBROStaking {
    constructor(address _owner, address _stakeToken, uint256 _lockTime, uint32 _percent)
        CYBROStaking(_owner, _stakeToken, _lockTime, _percent)
    {}

    function _sendReward(address user, uint256 reward) internal virtual override {
        LockedCYBRO lcybro = LockedCYBRO(address(stakeToken));
        address[] memory to = new address[](1);
        uint256[] memory amount = new uint256[](1);
        to[0] = user;
        amount[0] = reward + lcybro.allocations(user);
        lcybro.mintFor(to, amount);
    }
}
