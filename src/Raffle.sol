//Bir smart contract yazarken contract uyum düzeni bu şekilde olmalıdır.
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
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Raffle contract
 * @author Hüsniye Çapanoğlu/Patrick Collins
 * @notice This contract is for smaple raffle
 * @dev Implements ChainLink VRFv2.5
 */

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract Raffle {
    /**Errors  */
    error Raffle__SendMoreToEnterRaffle(); //hatayı daha iyi okuyalım diye

    uint256 private immutable i_entranceFee; // Katılım ücreti
    uint256 private immutable i_interval; // piyango arasında geçen süre
    address payable[] private s_players; // addrese bağlı oyuncuları alacağım ödeme olduğu için payable
    uint256 private s_lastTimeStamp;
    /**Events  */
    // events önemi
    // 1. yeniden deploy eildiğinde daha kolay şekilde ulaşma
    // 2. front end kısmında daha iyi indeksleme
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    //çekilişe girecek
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, " yeterli paran yok") // gaz tasarruflu değil
        // require(msg.value >= i_entranceFee, Raffle__SendMoreToEnterRaffle()); //özel derleyici sürümüyle çalışır
        // katılmak için para gönderilmesi gerekiyor

        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle(); // fonskiyonun çalışmasını önler
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    //kazananı seçecek
    // 1. Random sayı
    // 2. oyuncuların sayılarından random seçilmeli
    // 3. otomatik olarak başlayacak

    function pickWinner() external {
        // geçen saniyeleri ayarlamak için
        // s_lastTimeStamp => her piyango çekildiğinde bu değişecek o yüzden hafızada tutulmalı
        if ((block.timestamp - s_lastTimeStamp) > i_interval) {
            revert();
        }
        // random sayı al

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /**Getter Fonks. */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
