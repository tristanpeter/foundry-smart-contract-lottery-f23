// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfigInstance = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callBackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfigInstance.activeNetworkConfig();

        if (subscriptionId == 0) {
            // We will need to create a Subscription ID
            CreateSubscription createSubscriptionInstance = new CreateSubscription();
            subscriptionId = createSubscriptionInstance.createSubscription(
                vrfCoordinator,
                deployerKey
            );
        }

        FundSubscription fundSubscriptionInstance = new FundSubscription();
        fundSubscriptionInstance.fundSubscription(
            vrfCoordinator,
            subscriptionId,
            link,
            deployerKey
        );

        vm.startBroadcast(deployerKey);
        Raffle raffleInstance = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callBackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumerInstance = new AddConsumer();
        addConsumerInstance.addConsumer(
            address(raffleInstance),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );

        return (raffleInstance, helperConfigInstance);
    }
}
