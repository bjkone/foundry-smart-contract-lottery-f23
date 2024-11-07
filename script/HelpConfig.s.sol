// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint96 public constant BASE_FEE = 0.25 ether;
    uint96 public constant GASE_PRICE_LINK = 1e9;
    int256 public constant WEI_PER_UNIT_LINK = 4e15;
}


contract HelpConfig is CodeConstants, Script {

    error Raffle___NetworkNotSupported();

    NetworkConfig public activeNetworkConfig;


    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256  subscriptionId;
        bytes32 keyHash; 
        uint32  callbackGasLimit;
        address vrfCoordinator;
        address link;
        address account;
    }

    constructor() {
        if(block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getOrBuildSepoliaNetworkConfig();
        } else if(block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrBuildAnvilNetworkConfig();      
        }else {
            revert Raffle___NetworkNotSupported();
        }
    }

    function getOrBuildSepoliaNetworkConfig() public view returns (NetworkConfig memory) {

        if(activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        return NetworkConfig({
            entranceFee : 0.01 ether,
            interval : 30, //30 seconds
            subscriptionId : 0,
            keyHash : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit : 500_000,
            vrfCoordinator : 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link : 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account : 0xA5C9D4184548410821cffFfa495F89706a824dC0
        });
    }

    function getOrBuildAnvilNetworkConfig() public returns (NetworkConfig memory) {

        if(activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

       
        vm.startBroadcast(); //don't need account because we work with anvil
        VRFCoordinatorV2_5Mock vrf = new VRFCoordinatorV2_5Mock(BASE_FEE, GASE_PRICE_LINK, WEI_PER_UNIT_LINK);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return NetworkConfig({
            entranceFee : 0.01 ether,
            interval : 30, //30 seconds
            subscriptionId : 0,
            keyHash : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //@dev you can use the keyHash of sepolia
            callbackGasLimit : 500_000, 
            vrfCoordinator : address(vrf),
            link : address(link),
            account : 0x4e59b44847b379578588920cA78FbF26c0B4956C //default sender
        });
    }


}