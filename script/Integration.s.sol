// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { HelpConfig, CodeConstants} from "script/HelpConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function run() public {
        createSubcriptionConfig();
    }

    function createSubcriptionConfig() public returns (uint256, address) {
        // Create the subscription config
        HelpConfig hepConfig = new HelpConfig();
        (, , , , , address vrfCoordinator, , address account) = hepConfig.activeNetworkConfig();
        uint256 subId = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256) {
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("Account: ", account);
        vm.startBroadcast(account);
         //cast address to VRFCoordinatorV2_5Mock
         uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID: ", subId);
        return subId;
    }
}   


contract FundSubscription is Script, CodeConstants {
    uint256 public constant FOUND_AMOUNT = 3 ether;

    function run() public {
        fundSubscriptionConfig();     
    }

    function fundSubscriptionConfig() public {
        // Create the subscription config
        HelpConfig config = new HelpConfig();
        (, , uint256 subId , , , address vrfCoordinator, address link, address account) = config.activeNetworkConfig();
        fundSubscription(subId, vrfCoordinator, link, account);
    }

    function fundSubscription(uint256 subId, address vrfCoordinator, address link, address account) public {
        console.log("Subscription Funded: ", subId);
        console.log("Link: ", link);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("Account: ", account);

        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            //cast address to VRFCoordinatorV2_5Mock
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FOUND_AMOUNT * 100);
            vm.stopBroadcast();
        }else {
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator, FOUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();            
        }
        
        
    }


}   

contract AddConsumer is Script{

    function addConsumerConfig(address addressConsumer) public {
        HelpConfig config = new HelpConfig();
        (, , uint256 subId , , , address vrfCoordinator, , address account) = config.activeNetworkConfig();
        addConsumer(addressConsumer, subId, vrfCoordinator, account);
    }

    function addConsumer(address addressConsumer, uint256 subId, address vrfCoordinator, address account) public {
        console.log("Adding Consumer: ", addressConsumer);
        console.log("Subscription ID: ", subId);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("Account: ", account);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, addressConsumer);
        vm.stopBroadcast();
    }
    
    function run() public {
        address mostRecentAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerConfig(mostRecentAddress);
    }
}