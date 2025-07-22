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
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreToEnterRaffle(); //hatayı daha iyi okuyalım diye
    error Raffle__TransferFailed();
    error Raffle_RaffleNOTOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /*DURUM DEĞİŞKENLERİ */
    uint256 private immutable i_entranceFee; // Katılım ücreti
    uint256 private immutable i_interval; // piyango arasında geçen süre
    address payable[] private s_players; // addrese bağlı oyuncuları alacağım ödeme olduğu için payable
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_gasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**
     * Events
     */
    // events önemi
    // 1. yeniden deploy eildiğinde daha kolay şekilde ulaşma
    // 2. front end kısmında daha iyi indeksleme
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_gasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    // miras aldığında sözleşmedeki constractoru yazman gerekir

    //çekilişe girecek
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, " yeterli paran yok") // gaz tasarruflu değil
        // require(msg.value >= i_entranceFee, Raffle__SendMoreToEnterRaffle()); //özel derleyici sürümüyle çalışır
        // katılmak için para gönderilmesi gerekiyor

        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle(); // fonskiyonun çalışmasını önler
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNOTOpen();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev chanlink otomatik bağlatısı fonskyionu çekilişi kazananı ögrenmek için zamanın gelip gelmediğini anlayacağız
     * upkeepNeeded kesin true olmalı
     * 1. zaman aralığını geççmiş olmalı
     * 2. çekiliş açık olmalı
     * 3. kontratta eth olmalı
     * 4. kullanıcıda LINK olmalı
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    //kazananı seçecek
    // 1. Random sayı
    // 2. oyuncuların sayılarından random seçilmeli
    // 3. otomatik olarak başlayacak

    function performUpkeep(bytes calldata /*performData  */) external {
        // geçen saniyeleri ayarlamak için
        // s_lastTimeStamp => her piyango çekildiğinde bu değişecek o yüzden hafızada tutulmalı
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // random sayı al
        s_raffleState = RaffleState.CALCULATING; // kazanan seçerken katılma durdurulacak
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash, // ödeme max gas fiyat
                subId: i_subscriptionId, // sözleşmeyi başlatan abone idsi
                requestConfirmations: REQUEST_CONFIRMATIONS, // istek göndermede bloklar için bekleyecek
                callbackGasLimit: i_gasLimit, //GÖNÜLLÜ OLDUĞUMUZ GASI ÖDEME LİMİTİ
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /*requestId*/ uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWiner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWiner];
        s_recentWinner = recentWinner;
        /* kazanan belirlendi ve şimdi yeniden müşterilr çekilişe katılmaları lazım */
        s_raffleState = RaffleState.OPEN; // kazanan belirlendikten sonra açılacak
        s_players = new address payable[](0); // bu dizi elemanlarını sıfırladık şimdi yeni gelenler katılacak
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }

    /**
     * Getter Fonks.
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
