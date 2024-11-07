// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { Raffle } from "src/Raffle.sol";
import { HelpConfig } from "./HelpConfig.s.sol";
import { CreateSubscription, FundSubscription, AddConsumer } from "./Integration.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelpConfig) {
        HelpConfig config = new HelpConfig();
          (
            uint256 entranceFee,
            uint256 interval,
            uint256 subscriptionId,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            address vrfCoordinator,
            address link,
            address account
        ) = config.activeNetworkConfig();

        if(subscriptionId == 0) {
            // Create the subscription
            CreateSubscription newCreateSubscription = new CreateSubscription();
            subscriptionId = newCreateSubscription.createSubscription(vrfCoordinator, account);
            // Fund the subscription
            FundSubscription newFundSubscription = new FundSubscription();
            newFundSubscription.fundSubscription(subscriptionId, vrfCoordinator, link, account);

        }

        vm.startBroadcast(account);
        Raffle raffle = new Raffle(entranceFee, interval, vrfCoordinator, subscriptionId, keyHash, callbackGasLimit);
        vm.stopBroadcast();

        AddConsumer newAddConsumer = new AddConsumer();
        newAddConsumer.addConsumer(address(raffle), subscriptionId, vrfCoordinator, account);
        return (raffle, config);
    }
}