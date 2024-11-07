//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { console } from "forge-std/Script.sol";
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
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
// internal & private view & pure functions
// external & public view & pure functions

/**
 * @title test of simple Raffle
 * @author Marc M.
 * @dev Raffle contract
 */
contract Raffle is VRFConsumerBaseV2Plus{
    /** Errors */
    error Raffle__SendMoreThanEntranceFee();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 numPlayers, uint256 raffleState);

    /** enum */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    //@dev  The time interval between picks in seconds
    uint256 private i_interval;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEntered(address indexed player);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(uint256 _entranceFee, uint256 _interval, address _vrfCoordinator, uint256 _subscriptionId, bytes32 _keyHash, uint32 _callbackGasLimit) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        i_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit; 
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreThanEntranceFee();
        }
        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = checkCondition();
        return (upkeepNeeded, ""); 
    }

    function checkCondition() public view returns (bool) {
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        return isRaffleOpen && hasPlayers && hasBalance && timeHasPassed;
    }

    //1. Get a random number
    //2. Use random number to pick winner
    //3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        if (!checkCondition()) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
            })
        );
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*_requestId */,
        uint256[] calldata _randomWords
    ) internal override {
       uint256 randomValue = _randomWords[0];
       console.log("Random Value: ", randomValue);
       uint256 indexOfWinner = randomValue % s_players.length;
       console.log("Index of Winner: ", indexOfWinner);
       address winner = s_players[indexOfWinner];
       console.log("Winner: ", winner);
       s_recentWinner = winner;
       s_raffleState = RaffleState.OPEN;
       s_players = new address payable[](0);
       s_lastTimeStamp = block.timestamp;
       (bool success, ) = payable(winner).call{value: address(this).balance}("");
       if (!success) {
           revert Raffle__TransferFailed();
       }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerByIndex(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
