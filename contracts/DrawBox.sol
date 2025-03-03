// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Lottery
 * @dev A lottery system where users can buy tickets and a winner is randomly selected
 */
contract LotterySystem {
    // State variables
    address public owner;
    uint256 public lotteryIdCounter;
    
    struct Lottery {
        uint256 id;
        address authority;
        uint256 ticketPrice;
        uint256 lastTicketId;
        uint256 winnerId;
        bool winnerChosen;
        bool claimed;
        uint256 totalPrize;
    }
    
    struct Ticket {
        uint256 id;
        uint256 lotteryId;
        address owner;
    }
    
    // Mappings
    mapping(uint256 => Lottery) public lotteries;
    mapping(uint256 => mapping(uint256 => Ticket)) public tickets;
    
    // Events
    event LotteryCreated(uint256 indexed lotteryId, address indexed authority, uint256 ticketPrice);
    event TicketPurchased(uint256 indexed lotteryId, uint256 indexed ticketId, address indexed buyer);
    event WinnerSelected(uint256 indexed lotteryId, uint256 indexed ticketId);
    event PrizeClaimed(uint256 indexed lotteryId, uint256 indexed ticketId, address indexed winner, uint256 amount);
    
    // Errors
    error WinnerAlreadyExists();
    error NoTickets();
    error WinnerNotChosen();
    error InvalidWinner();
    error AlreadyClaimed();
    error NotAuthorized();
    error InsufficientFunds();
    
    // Constructor
    constructor() {
        owner = msg.sender;
        lotteryIdCounter = 0;
    }
    
    // Modifiers
    modifier onlyLotteryAuthority(uint256 lotteryId) {
        if(lotteries[lotteryId].authority != msg.sender) {
            revert NotAuthorized();
        }
        _;
    }
    
    /**
     * @dev Create a new lottery with specified ticket price
     * @param ticketPrice Price per lottery ticket in wei
     */
    function createLottery(uint256 ticketPrice) external {
        lotteryIdCounter++;
        
        Lottery storage lottery = lotteries[lotteryIdCounter];
        lottery.id = lotteryIdCounter;
        lottery.authority = msg.sender;
        lottery.ticketPrice = ticketPrice;
        lottery.lastTicketId = 0;
        lottery.winnerChosen = false;
        lottery.claimed = false;
        
        emit LotteryCreated(lotteryIdCounter, msg.sender, ticketPrice);
    }
    
    /**
     * @dev Buy a ticket for a specified lottery
     * @param lotteryId ID of the lottery to buy a ticket for
     */
    function buyTicket(uint256 lotteryId) external payable {
        Lottery storage lottery = lotteries[lotteryId];
        
        if(lottery.authority == address(0)) {
            revert("Lottery does not exist");
        }
        
        if(lottery.winnerChosen) {
            revert WinnerAlreadyExists();
        }
        
        if(msg.value != lottery.ticketPrice) {
            revert InsufficientFunds();
        }
        
        lottery.lastTicketId++;
        uint256 ticketId = lottery.lastTicketId;
        
        Ticket storage ticket = tickets[lotteryId][ticketId];
        ticket.id = ticketId;
        ticket.lotteryId = lotteryId;
        ticket.owner = msg.sender;
        
        lottery.totalPrize += msg.value;
        
        emit TicketPurchased(lotteryId, ticketId, msg.sender);
    }
    
    /**
     * @dev Pick a winner for the lottery
     * @param lotteryId ID of the lottery to pick a winner for
     */
    function pickWinner(uint256 lotteryId) external onlyLotteryAuthority(lotteryId) {
        Lottery storage lottery = lotteries[lotteryId];
        
        if(lottery.winnerChosen) {
            revert WinnerAlreadyExists();
        }
        
        if(lottery.lastTicketId == 0) {
            revert NoTickets();
        }
        
        // Generate pseudo-random number using block properties
        // Note: This is not cryptographically secure. In production, consider using Chainlink VRF
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            blockhash(block.number - 1),
            lotteryId
        )));
        
        uint256 winnerId = (randomNumber % lottery.lastTicketId) + 1;
        lottery.winnerId = winnerId;
        lottery.winnerChosen = true;
        
        emit WinnerSelected(lotteryId, winnerId);
    }
    
    /**
     * @dev Claim the prize for a winning ticket
     * @param lotteryId ID of the lottery
     * @param ticketId ID of the winning ticket
     */
    function claimPrize(uint256 lotteryId, uint256 ticketId) external {
        Lottery storage lottery = lotteries[lotteryId];
        Ticket storage ticket = tickets[lotteryId][ticketId];
        
        if(!lottery.winnerChosen) {
            revert WinnerNotChosen();
        }
        
        if(lottery.claimed) {
            revert AlreadyClaimed();
        }
        
        if(lottery.winnerId != ticketId) {
            revert InvalidWinner();
        }
        
        if(ticket.owner != msg.sender) {
            revert NotAuthorized();
        }
        
        lottery.claimed = true;
        uint256 prizeAmount = lottery.totalPrize;
        
        // Transfer the prize to the winner
        (bool success, ) = payable(msg.sender).call{value: prizeAmount}("");
        require(success, "Transfer failed");
        
        emit PrizeClaimed(lotteryId, ticketId, msg.sender, prizeAmount);
    }
    
    /**
     * @dev Get information about a specific lottery
     * @param lotteryId ID of the lottery to get information for
     */
    function getLotteryInfo(uint256 lotteryId) external view returns (
        uint256 id,
        address authority,
        uint256 ticketPrice,
        uint256 lastTicketId,
        uint256 winnerId,
        bool winnerChosen,
        bool claimed,
        uint256 totalPrize
    ) {
        Lottery storage lottery = lotteries[lotteryId];
        return (
            lottery.id,
            lottery.authority,
            lottery.ticketPrice,
            lottery.lastTicketId,
            lottery.winnerId,
            lottery.winnerChosen,
            lottery.claimed,
            lottery.totalPrize
        );
    }
    
    /**
     * @dev Get information about a specific ticket
     * @param lotteryId ID of the lottery
     * @param ticketId ID of the ticket
     */
    function getTicketInfo(uint256 lotteryId, uint256 ticketId) external view returns (
        uint256 id,
        uint256 lottery,
        address _owner
    ) {
        Ticket storage ticket = tickets[lotteryId][ticketId];
        return (
            ticket.id,
            ticket.lotteryId,
            ticket.owner
        );
    }
}