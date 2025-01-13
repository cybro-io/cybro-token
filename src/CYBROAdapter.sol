// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {OFTAdapter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CYBROOFTAdapter is OFTAdapter {
    /**
     * @notice Constructor for CYBROOFTAdapter
     * @param _token The address of the deployed, already existing ERC20 token address
     * @param _layerZeroEndpoint The address of the local endpoint
     * @param _owner The address of the token owner used as a delegate in LayerZero Endpoint
     */
    constructor(address _token, address _layerZeroEndpoint, address _owner)
        OFTAdapter(_token, _layerZeroEndpoint, _owner)
        Ownable(_owner)
    {}
}
