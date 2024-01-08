// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


// TODO
// 1. test payable
// 2. add events
// 3. add require
// 4. add error
// 5. add tests

contract DiscreteGDA {
    uint256 public next_auction_id;
    mapping (uint256 => DGDA) public auctions;

    struct DGDA {
        address seller;
        uint256 sold;
        uint256 startBlock;
        // price function params
        uint256 p_k;
        uint256 p_alpha;
        uint256 p_n;
        uint256 p_lambda;
        // tokens to sell
        Token[] tokens;
    }

    struct Token {
        address contract_address;
        uint token_id;
    }

    constructor() {
        next_auction_id = 0;
    }

    function createAuction(uint256 k, uint256 alpha, uint256 n, uint256 lambda, Token[] memory _tokens) public {
        DGDA storage auction = auctions[next_auction_id];
        auction.seller = msg.sender;
        auction.startBlock = block.number;
        auction.sold = 0;
        for (uint i = 0; i < _tokens.length; i++) {
            auction.tokens.push(Token(_tokens[i].contract_address, _tokens[i].token_id));
        }
        auction.p_k = k;
        auction.p_alpha = alpha;
        auction.p_n = n;
        auction.p_lambda = lambda;

        next_auction_id++;
    }

    function getAuction(uint256 id) public view returns (DGDA memory) {
        return auctions[id];
    }

    function deleteAuction(uint256 id) public {
        delete auctions[id];
    }

    function bulkBuy(uint256 id, uint256 amount) payable public {
        uint256 price = _bulkBuyPrice(id, amount);
        DGDA memory auction = auctions[id];
        bool success = payable(auction.seller).send(msg.value);
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
