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
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig, UlnBase} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

contract OFTScript is Script {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

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
    struct OFTData {
        address oft;
        string rpc;
    }

    function _addressToBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function deploy_testnet(address cybro) public {
        (, address deployer,) = vm.readCallers();
        uint256 optimismForkId = vm.createFork(vm.rpcUrl("optimism_sepolia"));
        uint256 blastForkId = vm.createSelectFork(vm.rpcUrl("blast_sepolia"));

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
    function deploy_adapter(address cybro) public {
        (, address deployer,) = vm.readCallers();
        uint256 blastMainnetForkId = vm.createFork(vm.rpcUrl("blast"));

        vm.selectFork(blastMainnetForkId);
        ILayerZeroEndpointV2 layerZeroEndpoint =
            ILayerZeroEndpointV2(address(0x1a44076050125825900e736c501f859c50fE728c));
        vm.startBroadcast();
        CYBROOFTAdapter adapter = new CYBROOFTAdapter(cybro, address(layerZeroEndpoint), deployer);
        vm.stopBroadcast();

        console.log("adapter", address(adapter));
    }

    /**
     * @notice Deploys multiple OFTs
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
     * @param peers The array of OFTData structs
     */
    function set_peers(OFTData[] calldata peers) public {
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
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0),
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

    function find_dead_dvns(OFTData[] memory ofts) public {
        uint256[] memory forkIds = new uint256[](ofts.length);
        uint32[] memory eids = new uint32[](ofts.length);
        // Create forks
        for (uint256 i = 0; i < ofts.length; i++) {
            forkIds[i] = vm.createSelectFork(ofts[i].rpc);
            eids[i] = CYBROOFT(ofts[i].oft).endpoint().eid();
        }

        for (uint256 i = 0; i < ofts.length; i++) {
            vm.selectFork(forkIds[i]);
            uint32 currentEid = eids[i];
            address currentOft = ofts[i].oft;
            ILayerZeroEndpointV2 endpoint = CYBROOFT(currentOft).endpoint();

            for (uint256 j = 0; j < ofts.length; j++) {
                if (i != j) {
                    uint32 otherEid = eids[j];
                    address sendLibrary = endpoint.getSendLibrary(currentOft, otherEid);
                    (address receiveLibrary,) = endpoint.getReceiveLibrary(currentOft, otherEid);
                    if (
                        _hasDeadDVN(sendLibrary, currentOft, otherEid)
                            || _hasDeadDVN(receiveLibrary, currentOft, otherEid)
                    ) {
                        console.log(
                            string.concat(
                                "Route from ", vm.toString(currentEid), " to ", vm.toString(otherEid), " has dead DVNs"
                            )
                        );
                    }
                }
            }
        }
    }

    function _hasDeadDVN(address lib, address oft, uint32 eid) internal view returns (bool hasDead) {
        UlnConfig memory config = UlnBase(lib).getUlnConfig(oft, eid);

        for (uint256 k = 0; k < config.requiredDVNCount; k++) {
            hasDead = hasDead || _isDead(config.requiredDVNs[k]);
        }
        for (uint256 k = 0; k < config.optionalDVNCount; k++) {
            hasDead = hasDead || _isDead(config.optionalDVNs[k]);
        }
    }

    function _isDead(address dvn) internal view returns (bool) {
        return address(dvn).code.length == 0;
    }

    // DVN list: https://docs.layerzero.network/v2/home/modular-security/security-stack-dvns#configuring-security-stack
    function set_dvns(OFTData memory src, OFTData memory dst, address[] memory dvns) public {
        vm.createSelectFork(dst.rpc);
        uint32 otherEid = CYBROOFT(dst.oft).endpoint().eid();

        vm.createSelectFork(src.rpc);
        ILayerZeroEndpointV2 endpoint = CYBROOFT(src.oft).endpoint();

        address sendLibrary = endpoint.getSendLibrary(src.oft, otherEid);
        (address receiveLibrary,) = endpoint.getReceiveLibrary(src.oft, otherEid);

        vm.startBroadcast();
        _setLibDVNS(endpoint, sendLibrary, src.oft, otherEid, dvns);
        _setLibDVNS(endpoint, receiveLibrary, src.oft, otherEid, dvns);
    }

    function _setLibDVNS(ILayerZeroEndpointV2 endpoint, address lib, address oft, uint32 eid, address[] memory dvns)
        internal
    {
        UlnConfig memory currentConfig = UlnBase(lib).getUlnConfig(oft, eid);
        UlnConfig memory newConfig = UlnConfig({
            confirmations: currentConfig.confirmations,
            requiredDVNs: dvns,
            requiredDVNCount: uint8(dvns.length),
            optionalDVNs: new address[](0),
            optionalDVNCount: 0,
            optionalDVNThreshold: 0
        });

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({eid: eid, configType: 2, config: abi.encode(newConfig)});

        endpoint.setConfig(oft, lib, params);
    }

    function set_enforced_options(OFTData[] calldata ofts) public {
        uint256[] memory forkIds = new uint256[](ofts.length);
        uint32[] memory eids = new uint32[](ofts.length);

        for (uint256 i = 0; i < ofts.length; i++) {
            forkIds[i] = vm.createSelectFork(ofts[i].rpc);
            eids[i] = CYBROOFT(ofts[i].oft).endpoint().eid();
        }

        bytes memory enforcedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(50000, 0);

        for (uint256 i = 0; i < ofts.length; i++) {
            vm.selectFork(forkIds[i]);
            EnforcedOptionParam[] memory enforcedOptionsArray = new EnforcedOptionParam[](eids.length - 1);
            uint256 k;
            for (uint256 j = 0; j < eids.length; j++) {
                if (j != i) {
                    enforcedOptionsArray[k++] =
                        EnforcedOptionParam({eid: eids[j], msgType: uint16(1), options: enforcedOptions});
                }
            }
            vm.startBroadcast();
            CYBROOFT(ofts[i].oft).setEnforcedOptions(enforcedOptionsArray);
            vm.stopBroadcast();
        }
    }
}
