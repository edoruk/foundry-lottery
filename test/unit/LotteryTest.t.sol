// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Lottery} from "../../src/Lottery.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../mock/VRfCoordinatorV2Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

contract LotteryTest is Test {
    Lottery lottery;
    HelperConfig helperConfig;

    event EnteredLottery(address indexed player);
    event RequestedRandom(uint256 indexed requestId);
    event PickedWinner(address indexed player);

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
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();
        (
            subscriptionId,
            keyHash,
            callbackGasLimit,
            vrfCoordinatorV2,
            interval,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    // enterLottery

    function testEnterLottery_Revert_WhenPlayerDoesNotPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Lottery__InsufficientETH.selector);
        lottery.enterLottery();
    }

    function testEnterLottery_StateIsOpen_WhenContractIsDeployed() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    function testEnterLottery_PlayerAddressIsSavedToPlayers() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: 1 ether}();
        assert(lottery.getPlayerAddress(0) == PLAYER);
    }

    function testEnterLottery_EmitsEnteredLottery() public {
        uint256 entranceFee = lottery.getEntranceFee();

        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    function testLottery_PlayerCantEnterLottery_IfStateIsCalculating()
        public
        EnteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__StateIsNotReady.selector);
        vm.prank(PLAYER);
        lottery.enterLottery{value: 1 ether}();
    }

    // checkUpkeep

    function testCheckUpkeep_Reverts_IfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeep_ReturnsFalse_IsStateIsCalculating()
        public
        EnteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");

        Lottery.LotteryState state = lottery.getLotteryState();
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(state == Lottery.LotteryState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeep_ReturnsFalse_IfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: 1 ether}();

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeep_ReturnsTrue_IfAllParametersTrue()
        public
        EnteredLotteryAndTimePassed
    {
        //setUp

        //execution
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        //assert
        assert(upkeepNeeded == true);
    }

    // performUpkeep

    function testPerformUpkeep_Applies_IfOnlyCheckUpkeepIsTrue()
        public
        EnteredLotteryAndTimePassed
    {
        //setUp

        //execution
        lottery.performUpkeep("");
        //assert
    }

    function testPerformUpkeep_Reverts_IfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 playersCount = 0;
        Lottery.LotteryState lotteryState = lottery.getLotteryState();

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__LotteryIsNotReady.selector,
                currentBalance,
                playersCount,
                lotteryState
            )
        );
        lottery.performUpkeep("");
    }

    modifier EnteredLotteryAndTimePassed() {
        vm.prank(PLAYER);
        lottery.enterLottery{value: 1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeep_UpdatesStateAndEmitsRequestId()
        public
        EnteredLotteryAndTimePassed
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //first entry is an event from mock. first topic is whole emits iteself.

        Lottery.LotteryState lotteryState = lottery.getLotteryState();
        assert(requestId > 0);
        assert(uint256(lotteryState) == 1); //0->Open, 1->Calculating
    }

    // FulfillRandomWords

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWords_CanOnlyBeCalled_AfterPerformUpkeep(
        uint256 _randomRequestId
    ) public EnteredLotteryAndTimePassed skipFork {
        // vm.expectRevert("nonexistent request");
        // VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
        //     0,
        //     address(lottery)
        // );
        // vm.expectRevert("nonexistent request");
        // VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
        //     1,
        //     address(lottery)
        // );
        // We can use fuzz test ,better than writing like these
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            _randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomWords_PicksWinnerResetsAndSendMoney()
        public
        EnteredLotteryAndTimePassed
        skipFork
    {
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < additionalEntrances + startingIndex;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            lottery.enterLottery{value: 1 ether}();
        }

        uint256 startingTimeStamp = lottery.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.expectEmit(true, false, false, false, address(lottery));
        emit PickedWinner(expectedWinner);

        // Because of using mock hsould use skipfork modifier
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(uint256(requestId)),
            address(lottery)
        );

        address recentWinner = lottery.getWinnerAddress();
        uint256 entranceFee = 1 ether;
        uint256 playersCount = lottery.getPlayersCount();
        Lottery.LotteryState lotteryState = lottery.getLotteryState();
        uint256 winnerBalance = expectedWinner.balance;
        uint256 endingTimestamp = lottery.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(playersCount == 0);
        assert(lotteryState == Lottery.LotteryState.OPEN);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimestamp > startingTimeStamp);
    }

    function testGetNumWords_GetInterval_GetRequestConfirmations() public view {
        assert(lottery.getNumWords() == 1);
        assert(lottery.getInterval() == 30);
        assert(lottery.getRequestConfirmations() == 3);
    }
}
