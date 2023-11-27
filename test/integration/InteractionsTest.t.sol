// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../mock/VRfCoordinatorV2Mock.sol";

contract InteractionsTest is Test {
    CreateSubscription createSubscription;
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;
    HelperConfig helperConfig;
    FundSubscription fundSubscription;

    uint96 baseFee = 0.1 ether; //0.1 LINK
    uint96 gasPrice = 1e9; //1 gwei

    uint64 subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;
    uint256 interval;
    address link;
    uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(baseFee, gasPrice);
        helperConfig = new HelperConfig();

        (
            subscriptionId,
            keyHash,
            callbackGasLimit,
            vrfCoordinatorV2,
            interval,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testCreateSubscription_Created_Successfully() public skipFork {
        assert(
            createSubscription.createSubscriptionUsingConfig() ==
                vrfCoordinatorV2Mock.createSubscription()
        );
        assert(createSubscription.createSubscriptionUsingConfig() != 0);
    }

    function testFundSubscription_Fund_Successfully() public {}
}
