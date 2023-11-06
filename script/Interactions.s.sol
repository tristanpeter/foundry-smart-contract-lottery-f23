// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock";

contract CreateSubscription is Script {

    function createSubscriptionUsingConfig() public returns (uint64) {
        // Creating a "new" instance of the HelperConfig contract.
        HelperConfig helperConfigInstance = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            ,
        ) = helperConfigInstance.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    // This is where the VRF subscription is actually created on the Ethereum blockchain, using vm.startBroadcast and vm.stopBroadcast()
    function createSubscription(address vrfCoordinator) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast();
        // No "new" keyword because it is not being deployed as a new contract, it exists already and "vrfCoordinator" is its address.
        // Its functions are called directly because it already exists.
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).CreateSubscription();
        vm.stopBroadcast();
        console.log("Your Subscription ID is: ", subId);
        console.log("Please update Subscription ID in HelperConfig.s.sol");
        return subId;
    }

    // The run() function defines the main things we need to do.
    function run() external return (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfigInstance = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            uint64 subId,
            
        ) = helperConfigInstance.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    
    function run() external {
        fundSubscriptionUsingConfig();
    }
}
