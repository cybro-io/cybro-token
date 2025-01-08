// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20Mock} from "./ERC20Mock.sol";

contract WETHMock is ERC20Mock {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20Mock(name, symbol, decimals) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);

        (bool success,) = payable(msg.sender).call{value: wad}("");
        require(success);
    }
}
