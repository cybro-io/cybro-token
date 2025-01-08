// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {CYBROOFTAdapter} from "../src/CYBROAdapter.sol";
import {CYBROOFT} from "../src/CYBROOFT.sol";
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {
    IOFT,
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OFTScript is Script {
    using SafeERC20 for IERC20;

    /**
     * @notice Struct to store input data for deploying OFTs
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param endpoint The address of the layerzero endpoint
     * @param rpc The RPC URL of the network
     */
    struct OFTDeployInput {
        string name;
        string symbol;
        address endpoint;
        string rpc;
    }

    /**
     * @notice Struct to set peers for deployed OFTs
     * @param oft The address of the OFT
     * @param rpc The RPC URL of the network
     */
    struct SetPeers {
        address oft;
        string rpc;
    }

    function _addressToBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function deploy_testnet() public {
        (, address deployer,) = vm.readCallers();
        uint256 optimismForkId = vm.createFork(vm.rpcUrl("optimism_sepolia"));
        uint256 blastForkId = vm.createSelectFork(vm.rpcUrl("blast_sepolia"));

        address cybro = address(0);
        address layerZeroEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
        vm.startBroadcast();
        CYBROOFTAdapter adapter = new CYBROOFTAdapter(cybro, layerZeroEndpoint, deployer);
        vm.stopBroadcast();

        console.log("adapter", address(adapter));

        vm.selectFork(optimismForkId);
        vm.startBroadcast();
        CYBROOFT optimism_oft = new CYBROOFT("Optimism CYBRO", "OCYBRO", layerZeroEndpoint, deployer);

        console.log("optimism OFT", address(optimism_oft));
        optimism_oft.setPeer(40243, _addressToBytes32(address(adapter)));
        vm.stopBroadcast();

        vm.selectFork(blastForkId);
        vm.startBroadcast();
        adapter.setPeer(40232, _addressToBytes32(address(optimism_oft)));
    }

    /**
     * @notice Deploys CYBROOFTAdapter on the Blast mainnet
     */
    function deploy_adapter() public {
        (, address deployer,) = vm.readCallers();
        uint256 blastMainnetForkId = vm.createFork(vm.rpcUrl("blast"));

        vm.selectFork(blastMainnetForkId);
        address cybro = address(0);
        address layerZeroEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
        vm.startBroadcast();
        CYBROOFTAdapter adapter = new CYBROOFTAdapter(cybro, layerZeroEndpoint, deployer);
        vm.stopBroadcast();

        console.log("adapter", address(adapter));
    }

    /**
     * @notice Deploys multiple OFTs and sets their peers
     * @param ofts The array of OFTDeployInput structs
     */
    function deploy_ofts(OFTDeployInput[] calldata ofts) public {
        (, address deployer,) = vm.readCallers();
        CYBROOFT oft;
        // Deploy and setPeers for deployed oft and adapter
        for (uint256 i = 0; i < ofts.length; i++) {
            vm.createSelectFork(ofts[i].rpc);
            vm.startBroadcast();

            oft = new CYBROOFT(ofts[i].name, ofts[i].symbol, ofts[i].endpoint, deployer);

            console.log("chain", ofts[i].rpc, "OFT addr", address(oft));
            vm.stopBroadcast();
        }
    }

    /**
     * @notice Sets peers for already deployed OFTs
     * @param peers The array of SetPeers structs
     */
    function set_peers(SetPeers[] calldata peers) public {
        uint256[] memory forkIds = new uint256[](peers.length);
        // Create forks
        for (uint256 i = 0; i < peers.length; i++) {
            forkIds[i] = vm.createFork(peers[i].rpc);
        }
        for (uint256 i = 0; i < peers.length; i++) {
            vm.selectFork(forkIds[i]);
            uint32 currentEid = IMessagingChannel(CYBROOFT(peers[i].oft).endpoint()).eid();
            for (uint256 j = 0; j < peers.length; j++) {
                vm.selectFork(forkIds[j]);
                if (i != j) {
                    vm.startBroadcast();
                    if (CYBROOFT(peers[j].oft).peers(currentEid) == "") {
                        CYBROOFT(peers[j].oft).setPeer(currentEid, _addressToBytes32(peers[i].oft));
                    }
                    vm.stopBroadcast();
                }
            }
        }
        console.log("Succesfully set peers for all OFTs");
    }

    /**
     * @notice Sends a specified amount of tokens to a given address on a specified chain.
     * @param oft The address of the OFT (Omnichain Fungible Token) contract.
     * @param to The address of the recipient.
     * @param eid The chain ID of the destination chain.
     * @param amount The amount of tokens to send.
     */
    function send(address oft, address to, uint32 eid, uint256 amount) public {
        (, address sender,) = vm.readCallers();
        vm.startBroadcast();
        // Get the address of the underlying token from the OFT contract
        address token = IOFT(oft).token();
        // If the token address is adapter address
        // and the sender's allowance is insufficient, approve max allowance
        if (token != oft && IERC20(token).allowance(sender, oft) < amount) {
            IERC20(token).forceApprove(oft, type(uint256).max);
        }

        SendParam memory sendParam = SendParam({
            dstEid: eid,
            to: _addressToBytes32(to),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        // Quote the messaging fee for sending the tokens
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);

        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            IOFT(oft).send{value: fee.nativeFee}(sendParam, fee, sender);

        console.log("amountSentLD:", oftReceipt.amountSentLD, "amountReceivedLD:", oftReceipt.amountReceivedLD);
        console.log(msgReceipt.nonce);

        vm.stopBroadcast();
    }
}
