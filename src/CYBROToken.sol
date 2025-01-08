// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CYBROToken is ERC20 {
    // Initial supply of token 1B, precision is 18
    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * (10 ** 18);
    address public immutable daoAddress;

    constructor(address _daoAddress) ERC20("Test CYBRO Token", "TCYBRO") {
        require(_daoAddress != address(0), "DAO address cannot be the zero address");

        daoAddress = _daoAddress;
        _mint(daoAddress, INITIAL_SUPPLY);
    }
}
