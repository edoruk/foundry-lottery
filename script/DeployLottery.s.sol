// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig();
        (
            uint64 subscriptionId,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            address vrfCoordinatorV2,
            uint256 interval,
            address link,
            uint256 deployerKey
        ) = helperconfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // Create Subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinatorV2,
                deployerKey
            );

            // Fund Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinatorV2,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        Lottery lottery = new Lottery(
            vrfCoordinatorV2,
            subscriptionId,
            keyHash,
            callbackGasLimit,
            interval,
            link
        );
        vm.stopBroadcast();

        // Add Consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            subscriptionId,
            vrfCoordinatorV2,
            address(lottery),
            deployerKey
        );

        return (lottery, helperconfig);
    }
}
