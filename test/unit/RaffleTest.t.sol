// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";    
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelpConfig} from "../../script/HelpConfig.s.sol";
import {VmSafe} from "forge-std/VM.sol";
import {CodeConstants} from "../../script/HelpConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
//import "forge-std/console.sol";

contract RaffleTest is Test, CodeConstants {

    uint256 private entranceFee;
    uint256 private interval;
    uint256 private subscriptionId;
    bytes32 private keyHash;
    uint32 private callbackGasLimit;
    address private vrfCoordinator;
    address private link;
    Raffle private raffle;
    HelpConfig private config;

    address private USER = makeAddr("USER");
    address private USER2 = makeAddr("USER2");
    uint256 private constant SEND_VALUE = 0.01 ether;
    uint256 private constant STARTING_BALANCE = 10 ether;

    function setUp() public virtual {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, config) = deployRaffle.run();
        (entranceFee, interval, subscriptionId, keyHash, callbackGasLimit,   vrfCoordinator, link, ) = config.activeNetworkConfig();
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    function testEntreRaffleWithNoEnoughFunds() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__SendMoreThanEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testRaffleStateStartAtOpen() public view {
        assertEq(uint256(raffle.getState()), uint256(Raffle.RaffleState.OPEN));
    }

    function testUserWasEnteredWithEntranceFee() public {
        vm.prank(USER);
        raffle.enterRaffle{value: SEND_VALUE}();
        assertEq(USER, raffle.getPlayerByIndex(0));
    }

    function testEntreRaffleEmitsEvent() public {
        
        vm.expectEmit(true, false, false, false);
        emit Raffle.RaffleEntered(USER);
        vm.prank(USER);
        raffle.enterRaffle{value: SEND_VALUE}();
    }

    function testUseCantEnterRaffleWithRaffleCalculatingState() public {
        //Arrange
        vm.prank(USER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: SEND_VALUE}();  
        raffle.performUpkeep(""); 

        //Act //Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(USER);
        raffle.enterRaffle{value: SEND_VALUE}();  
    }

    function testCheckUpKeepReturnFalseWhenTheConditionIsNotValide() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool response, ) = raffle.checkUpkeep("");
        assertFalse(response);
    }

    function testConditionIsTrueWhenAllParametersAreValid() public {
        //Arrange
        vm.prank(USER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: SEND_VALUE}();

        //Act
        assertTrue(raffle.checkCondition());
    }

    function testCheckConditonIsFalseWhenRaffleStateIsNotOpen() public {
        //Arrange
        vm.prank(USER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: SEND_VALUE}();
        raffle.performUpkeep("");
        //Act
        assertFalse(raffle.checkCondition());
    }

    modifier entreRaffle{
        //Arrange
        vm.prank(USER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: SEND_VALUE}();
        _;
    }

    
    function testRequestRafflerWinnerEvent() public entreRaffle {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        
        VmSafe.Log[] memory entries = abi.decode(abi.encode(vm.getRecordedLogs()), (VmSafe.Log[]));
        assertEq(entries.length, 2);
        bytes32 requestId = entries[0].topics[1];
        assert(requestId > 0);

    }

    function testFulFillRandomWordsIsCallOnlyAfterPerformUpkeep(uint256 _randomRequestId) public entreRaffle skipFork(){
        //Act
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(_randomRequestId, address(raffle));

    }

    modifier skipFork{
        if(block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFromEntreRaffleToFulFillRandomWord() public entreRaffle skipFork {
        
        address expectedWinner = address(5);
        uint256 numberOfPlayers = 5;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i < startingIndex + numberOfPlayers; i++) {
            address user = address(uint160(i));
            hoax(user, 1 ether);
            raffle.enterRaffle{value: SEND_VALUE}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        
        //Act //Arrange
        vm.recordLogs();
        raffle.performUpkeep("");
        VmSafe.Log[] memory entries = abi.decode(abi.encode(vm.getRecordedLogs()), (VmSafe.Log[]));
        bytes32 requestId = entries[1].topics[1];
        console.log("requestId: ", uint256(requestId));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //Assert
        uint256 lasTimeStamp = raffle.getLastTimeStamp();
        Raffle.RaffleState raffleState = raffle.getState();
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = SEND_VALUE * (numberOfPlayers + startingIndex);
        

        assert(uint256(raffleState) == 0);
        assert(recentWinner == expectedWinner);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }

}