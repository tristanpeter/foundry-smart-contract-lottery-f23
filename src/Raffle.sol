// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations e.g. an Enum
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample raffle contract
 * @author Tristan G
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF2 and Chainlink Automation
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__IntervalRequirementNotMet();
    error Raffle__FundsNotTransferred();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeededYet(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    // @dev default this to 3
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // @dev use getters and setters to retrieve/set values
    uint256 private immutable i_entranceFee;
    // @dev immutable interval state variable - duration of lottery in seconds
    uint256 private immutable i_interval;
    // @dev Chainlink VRF address (Sepolia)
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    // @dev keyHash better reffered to as gasLane
    bytes32 private immutable i_gasLane;
    // @dev subscription ID from Chainlink subscription
    uint64 private immutable i_subscriptionId;
    // @dev restrict the amount of gas we spend on call back from the VRF coordinator in case it costs too much
    uint32 private immutable i_callBackGasLimit;
    // @dev store users who enter the raffle
    address payable[] private s_players;
    // @dev Timestamp of last time winner was picked
    uint256 private s_lastTimeStamp;
    // @dev address of the most recent winner for tracking purposes
    address payable private s_recentWinner;
    // @dev create a state var for this Raffle State
    RaffleState private s_raffleState;

    /** Events */

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // When is the winner supposed to be picked?
    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it's time to perform an upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The raffle is in the OPEN state.
     * 3. The contract has ETH (i.e. players).
     * 4. (Implicit) The subscription is funded with Link.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // check to see if enough time has passed
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeededYet(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // Raffle State is set to CALCULATING
        s_raffleState = RaffleState.CALCULATING;
        // Get a random number
        i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        // Reset s_players[] to a new empty array so that current entrants can't re-enter for free
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // Transfer funds to winner
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__FundsNotTransferred();
        }
        emit WinnerPicked(winner);
    }

    /** Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 playerIndex) external view returns (address) {
        return s_players[playerIndex];
    }
}
