// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract Lottery is VRFConsumerBaseV2, AutomationCompatibleInterface {
    // ERRORS
    error Lottery__NotOwner();
    error Lottery__InsufficientETH();
    error Lottery__StateIsNotReady();
    error Lottery__LotteryIsNotReady(
        uint256 currentBalance,
        uint256 playersCount,
        LotteryState lotteryState
    );
    error Lottery__CouldNotSendToWinner();

    enum LotteryState {
        OPEN, //0
        CALCULATING //1
    }

    // VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //Lottery variables
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    uint256 private constant ENTRANCE_FEE = 0.001 ether;
    LotteryState private lotteryState;
    address linkToken;

    // EVENTS
    event EnteredLottery(address indexed player);
    event RequestedRandom(uint256 indexed requestId);
    event PickedWinner(address indexed player);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 keyHash, // gasLane
        uint32 callbackGasLimit,
        uint256 interval,
        address link
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        lotteryState = LotteryState.OPEN;
        i_interval = interval;
        linkToken = link;
    }

    function enterLottery() external payable {
        if (msg.value < ENTRANCE_FEE) {
            revert Lottery__InsufficientETH();
        }
        if (lotteryState != LotteryState.OPEN) {
            revert Lottery__StateIsNotReady();
        }
        s_players.push(payable(msg.sender));
        emit EnteredLottery(msg.sender);
    }

    /**
     * @dev This is the func that the Cahinlink Automation nodes
     * call to see if it is time to perform upkeep.
     */
    function checkUpkeep(
        bytes memory /*performData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = lotteryState == LotteryState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasBalance = address(this).balance >= 0;
        upkeepNeeded = (isOpen && hasPlayers && timePassed && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData*/) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__LotteryIsNotReady(
                address(this).balance,
                s_players.length,
                lotteryState
            );
        }
        lotteryState = LotteryState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRandom(requestId);
    }

    // CEI -checks, -effects, interactions
    function fulfillRandomWords(
        uint256 /* requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        uint256 winnerIndex = _randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(recentWinner);
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__CouldNotSendToWinner();
        }
    }

    function getWinnerAddress() external view returns (address) {
        return s_recentWinner;
    }

    function getPlayerAddress(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }

    function getLotteryState() external view returns (LotteryState) {
        return lotteryState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getEntranceFee() public pure returns (uint256) {
        return ENTRANCE_FEE;
    }
}
