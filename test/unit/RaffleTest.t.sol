// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffleInstance;
    HelperConfig helperConfigInstance;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit;

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
            callBackGasLimit
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
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffleInstance.enterRaffle{value: entranceFee}();

        // Assert
    }
}
