// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

//import "@openzeppelin/contracts/access/Ownable.sol";

//import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

// This abstract is manually copy/pasted @openzeppelin/contracts/utils/Context.sol, required for below abstract.
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// This abstract is manually copy/pasted @openzeppelin/contracts/access/Ownable.sol, as import not working. Error is "Source "@openzeppelin/contracts/access/Ownable.sol" not found: File outside of allowed directories.". Had to add public keyword in constructor to get this to work
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() public {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// Actual contract for the lottery
contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    // Using "enum" to enumerate, OPEN=0, CLOSED=1, CALCULATING_WINNER=2
    // Create variable to store it
    LOTTERY_STATE public lottery_state;
    uint256 public fee;
    bytes32 public keyhash;
    event RequestedRandomness(bytes32 requestId);

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18); //since we'll work in wei, convert this to 18 decimals
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED; //At the initialisation of contract, we want the state to be closed
        fee = _fee;
        keyhash = _keyhash;
    }

    function enter() public payable {
        // $50 minimum lottery ticket fee. Should be stored when contract is first deployed, i.e. place in constructor object
        require(lottery_state == LOTTERY_STATE.OPEN); //Can only enter if admin has opened the lottery
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        // We know Chainlink will provide the conversion in 8 decimals (see documentation)
        // Hence we'll want to convert it to 18 deciamls as well
        uint256 adjustedPrice = uint256(price) * 10**10; // adjustedPrice will be in 18 decimals
        // Typically when doing conversion of $50 to eth, where rate is $2000/ETH, you would do (50/2000).
        // However, solidity cannot work with decimals. So have to do something like 50*10**18 / 2000. And make up for the 10**18 later.
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice; //the additional 10**18 after usdEntryFee, is to cancel out the division adjuster in previous line
        return costToEnter; // costToEnter will be in wei
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        //Need to get a random winner. Not straightforward as blockchain is a deterministic system. Math.random() from w/e language is also not truly random
        //One quick,dirty,development method to get randomness is to hash a combination of global variables (e.g. block.difficulty) that seems hard to predict. However, NEVER use this in production as this is exploitable, due to hashing algorithm (e.g. keccack256) is not random
        //To get verifiable randomness, need an oracle (e.g. Chainlink VRF)
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );
        require(_randomness > 0, "random-not-found");
        uint256 indexOfWinner = _randomness % players.length; //modulo by number of players to get a random number that corresponds to player max index
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance); //payout the winner

        //Reset the laundry at the end
        players = new address payable[](0); //resetting players array
        lottery_state = LOTTERY_STATE.CLOSED; //close lottery
        randomness = _randomness;
    }
}
