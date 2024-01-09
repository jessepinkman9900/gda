// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract DiscreteGDA {
    // Storage
    uint256 public next_auction_id;
    mapping (uint256 => DGDA) public auctions;

    // Struct
    struct DGDA {
        address seller;
        uint256 sold;
        uint256 startBlock;
        // price function params
        uint256 p_k;
        uint256 p_alpha;
        uint256 p_lambda;
        // tokens to sell
        Token[] tokens;
    }

    struct Token {
        address contract_address;
        uint token_id;
    }


    // Event
    event AuctionCreated(address seller, uint256 auctionId, uint256 k, uint256 alpha, uint256 numberOfTokens, uint256 lambda, Token[] tokens);
    event AuctionDeleted(uint256 auctionId, DGDA auction);
    event BulkBuyTokens(address buyer, uint256 auctionId, uint256 amount, uint256 price, Token[] tokens);

    // Method
    constructor() {
        next_auction_id = 0;
    }

    function createAuction(uint256 k, uint256 alpha, uint256 lambda, Token[] memory _tokens) public {
        require(k > 0, "Starting price k must be greater than 0");
        require(alpha > 0, "Price scaling factor must be greater than 0");
        require(lambda > 0, "Price function decay factor must be greater than 0");
        require(_tokens.length > 0, "List of tokens to be sold must be non-empty");

        DGDA storage auction = auctions[next_auction_id];
        auction.seller = msg.sender;
        auction.startBlock = block.number;
        auction.sold = 0;
        for (uint i = 0; i < _tokens.length; i++) {
            auction.tokens.push(Token(_tokens[i].contract_address, _tokens[i].token_id));
        }
        auction.p_k = k;
        auction.p_alpha = alpha;
        auction.p_lambda = lambda;


        emit AuctionCreated(msg.sender, next_auction_id, k, alpha, auction.tokens.length, lambda, auction.tokens);
        next_auction_id++;
    }

    function getAuction(uint256 id) public view returns (DGDA memory) {
        return auctions[id];
    }

    function deleteAuction(uint256 id) public {
        require(id < next_auction_id, "Invalid auction id");
        DGDA memory auction = auctions[id];
        delete auctions[id];
        emit AuctionDeleted(id, auction);
    }

    function bulkBuy(uint256 id, uint256 amount) payable public {
        require(id < next_auction_id, "Invalid auction id");
        DGDA storage auction = auctions[id];

        uint256 price = _bulkBuyPrice(id, amount);

        require(msg.value >= price, "Insufficient funds provided for the sale");
        require(amount <= (auction.tokens.length - auction.sold), "Amount is greater than the remaining amount of tokens to be sold");
        // bool success = payable(auction.seller).send(msg.value);

        Token[] memory tokens = new Token[](amount);
        for(uint i=auction.sold; i<auction.sold + amount; i++) {
            tokens[i - auction.sold] = auction.tokens[i];
        }

        // update storage
        auction.sold = auction.sold + amount;

        emit BulkBuyTokens(msg.sender, id, amount, price, tokens);
    }

    function _bulkBuyPrice(uint256 id, uint256 amount) public view returns (uint256) {
        DGDA memory auction = auctions[id];

        uint256 time = block.number - auction.startBlock;
        uint lt = auction.p_lambda * time;
        uint256 price_num = auction.p_k * (auction.p_alpha ** auction.sold) * ((auction.p_alpha ** amount) - 1) * (100000 ** (lt));
        uint256 price_den = (auction.p_alpha - 1) * (271828 ** (lt));

        return price_num / price_den;
    }
}
