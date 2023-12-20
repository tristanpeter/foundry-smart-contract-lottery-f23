// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    Raffle raffleInstance;
    HelperConfig helperConfigInstance;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffleInstance, helperConfigInstance) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callBackGasLimit,
            link,

        ) = helperConfigInstance.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitialisesInOpenState() public view {
        assert(raffleInstance.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////////////////////////
    // enterRaffle                //
    ////////////////////////////////

    // @dev testing function when not enough ETH is sent to meet minimum amount condition
    function testEnterRaffleRevertsWhenYouDoNotPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffleInstance.enterRaffle();
    }

    // @dev testing function when there is enough ETH sent to meet minimum amount condition, and s_players is therefore updated
    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        // Pretend PLAYER is performing the tx
        vm.prank(PLAYER);
        // Act
        raffleInstance.enterRaffle{value: entranceFee}();
        address playerRecorded = raffleInstance.getPlayer(0);
        // Assert
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        // Address of emitter is the raffle contract
        vm.expectEmit(true, false, false, false, address(raffleInstance));
        emit EnteredRaffle(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
    }

    // Simulate raffle is in CALCULATING state by using vm.warp() and vm.roll()
    function testEnterRaffleRevertsIfNotInOpenState() public {
        // Arrange
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        raffleInstance.performUpkeep("");
        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
    }

    ////////////////////////////////
    // checkUpkeep                //
    ////////////////////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffleInstance.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        // Give it players and give it a balance, and also warp time
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffleInstance.performUpkeep("");

        // Act
        (bool isUpkeepRequired, ) = raffleInstance.checkUpkeep("");

        // Assert
        assert(!isUpkeepRequired);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
        // Act
        (bool upkeepNeeded, ) = raffleInstance.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAllParametersAreSatisfied() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
        // Act
        // Act
        (bool upkeepNeeded, ) = raffleInstance.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    ////////////////////////////////
    // performUpkeep              //
    ////////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();

        // Act / Assert ==> Because performUpkeep() doesn't revert, it has passed i.e. checkUpkeep() conditions are all satisfied.
        raffleInstance.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        console.log("The contract balance is: ", address(this).balance);

        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffleInstance.getRaffleState();

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeededYet.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffleInstance.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Arrange - modifier
        // Act
        vm.recordLogs();
        raffleInstance.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffleInstance.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    ////////////////////////////////
    // fulfillRandomWords         //
    ////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomwordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffleInstance)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffleInstance.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        // Act
        vm.recordLogs();
        raffleInstance.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Address of emitter is the raffle contract
        //vm.expectEmit(true, false, false, false, address(raffleInstance));
        //emit WinnerPicked(expectedWinner);

        uint256 previousTimeStamp = raffleInstance.getLastTimeStamp();

        // Pretend to be chainlink vrf to get the random number and pick a winner

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffleInstance)
        );

        // Assert
        assert(uint256(raffleInstance.getRaffleState()) == 0);
        assert(raffleInstance.getRecentWinner() != address(0));
        assert(raffleInstance.getLengthOfPlayersArray() == 0);
        assert(previousTimeStamp < raffleInstance.getLastTimeStamp());
        assert(
            raffleInstance.getRecentWinner().balance ==
                ((STARTING_USER_BALANCE + prize) - entranceFee)
        );
    }
}
