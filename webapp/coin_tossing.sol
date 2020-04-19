pragma solidity >=0.4.22 <0.7.0;

contract Owned {
    constructor() public { owner = msg.sender; }
    address owner;
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only Owner can call this."
        );
        _;
    }
}

contract Tossing is Owned {
    bool private outcome;
    uint64 private random;
    bytes32 public commitment;
    CoinTossingGame game;

    function setGameAddress(CoinTossingGame addr) public { game = addr; }
    function submitCommit() public { game.tossCommit (commitment); }
    function toss () public onlyOwner{
        random = uint64(uint256(keccak256(abi.encodePacked(now))));
        if (random % 2 == 1 ){
            outcome = true;
        }else{
            outcome = false;
        }
        commitment = keccak256(abi.encodePacked(outcome,random));
    }
} 

contract CoinTossingGame {
 
    /*
        Rules:
        1.This game uses commitment scheme to ensure 50% chance of winning for both tosser and guesser.
        2.This game will start after guesser made a guess to a existing bet.
        3.The game will end in 24 hours from the moment a guess is made (or more accurately block.timestamp)
        4.If tosser do not reveal answer after game ended, the guesser can take all bet amount and tosser will lose deposit.
        5.If no guesser, tosser is free to withdraw the bet.
    */
    
    // Game elements that can be accessed publicly (with Getters)
    address public tosser;
    address public guesser;
    bytes32 public tosserCommitment;
    bool public guess;
    address public winner;
    uint public waitingTime;
    uint public gameEnd;
    bool public gameStarted;
 
    
    struct playerInfo{
        bytes32 name;
        uint32 age;
    }

    mapping (address=>uint) deposits;
    mapping (address=>playerInfo) players;
    
    address private keeper;
    

    // Modifiers
    modifier onlyAfter(uint _time) { require(now > _time); _; }
    modifier onlyTosser() {
        require(
            msg.sender == tosser,
            "Only Tosser can call this."
        );
        _;
    }

    modifier onlyGuesser() {
        require(
            msg.sender == guesser,
            "Only Guesser can call this."
        );
        _;
    }
    modifier matchCommitment(bool outcome, uint64 random){
        require(
            commitmentCheck(outcome,random),
            "Tosser Commitment does not match actual outcome."
            );
        _;
    }
    modifier enoughBetAmount(){
        require(
            msg.value >= deposits[tosser],
            "Not enough bet ammount."
            );
        _;
    }
    modifier noGuess(){ require(!gameStarted,"Game Already Started!"); _; }
    
    // Events
    event NewToss(address, uint);
    event NewGuess(address, uint);
  
  
  
    // Public functions  
    constructor() public payable {
        keeper = msg.sender;
        waitingTime = 24 hours;
        gameEnd = 2**256 - 1; //almost infinite
    }
    
    
    function tossCommit(bytes32 commitment) public payable {
        //this function is to be called by someone who wants to start a game
        tosser = msg.sender;
        deposits[msg.sender] = msg.value;
        tosserCommitment = commitment;
        emit NewToss(msg.sender, msg.value);
    }
    
    function guessOutcome(bool choice) public payable enoughBetAmount(){
        //this function is to be called by someone who wants to guess
        deposits[msg.sender] = msg.value;
        guesser = msg.sender;
        guess = choice;
        gameEnd = now + waitingTime;
        gameStarted = true;
        emit NewGuess(msg.sender, msg.value);
    }
    
    function getWinner() view public returns(address) {
        return(winner);
    }

    function showResult(bool outcome, uint64 random) public matchCommitment(outcome,random){
        // tosser reveals answer by calling this function
        // require(keccak256(abi.encodePacked(outcome,random))==tosserCommitment);
        if (guess == outcome) {
            winner = guesser;
        } else {
            winner = tosser;
        }
        winner.transfer(keeper.balance);

    }

   
    function cashBack() public onlyGuesser() onlyAfter(gameEnd){
        // if the tosser did not show answer in time
        msg.sender.transfer(keeper.balance);
    }
    
    function withdraw() public onlyTosser() noGuess() {
        // a function for tosser to withdraw from game if nobody guess
        msg.sender.transfer(keeper.balance);
    }
    
    
    // Internal function
    function commitmentCheck(bool outcome, uint64 random) internal returns (bool) {
        return keccak256(abi.encodePacked(outcome,random))==tosserCommitment;
    }
    
    
}
