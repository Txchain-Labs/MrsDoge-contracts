// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./SafeMath.sol";


library MrsDogeRoundBuyers {
    using SafeMath for uint256;

    struct Buyers {
        mapping(address => Buyer) list;
        address head;
        address lastBuyer;
        uint256 lastBuyerBlock;
        uint256 lastBuyerPayout;
    }

    struct Buyer {
    	address user;
    	uint256 ticketsBought;
        uint256 totalSpentOnTickets;
        uint256 lastBuyBlock;
        uint256 lastBuyTimestamp;
        uint256 payout;
    	address prev;
    	address next;
    }

    function maxLength() public pure returns (uint256) {
        return 3;
    }

    function topBuyer(Buyers storage self) public view returns (Buyer storage) {
        return self.list[self.head];
    }

    function updateBuyerForBuy(Buyer storage buyer, uint256 ticketsBought, uint256 price) private {
        buyer.ticketsBought = buyer.ticketsBought.add(ticketsBought);
        buyer.totalSpentOnTickets = buyer.totalSpentOnTickets.add(price);
        buyer.lastBuyBlock = block.number;
        buyer.lastBuyTimestamp = block.timestamp;
    }

    function handleBuy(Buyers storage self, address user, uint256 amount, uint256 price) public {
    	Buyer storage buyer = self.list[user];

        self.lastBuyer = user;
        self.lastBuyerBlock = block.number;

        //set user
    	if(buyer.user == address(0x0)) {
            buyer.user = user;
    	}
    	else {
    		Buyer storage buyerPrev = self.list[buyer.prev];
    		Buyer storage buyerNext = self.list[buyer.next];

    		// already first
    		if(buyer.user == self.head) {
                updateBuyerForBuy(buyer, amount, price);
    			return;
    		}

            //check they are in the list
            if(buyerPrev.user != address(0x0)) {
                // at end of list
                if(buyerNext.user == address(0x0)) {
                    buyerPrev.next = address(0x0);
                }
                else {
                    buyerPrev.next = buyerNext.user;
                    buyerNext.prev = buyerPrev.user;
                }
            }
    	  }

        updateBuyerForBuy(buyer, amount, price);
        buyer.prev = address(0x0);
        buyer.next = address(0x0);

        // insert into list
        Buyer storage checkBuyer = self.list[self.head];

        if(checkBuyer.user == address(0x0)) {
            self.head = user;
            return;
        }

        uint256 count = 0;

        // only store if in top 3
        while(count < maxLength()) {
            if(buyer.ticketsBought > checkBuyer.ticketsBought) {
                Buyer storage buyerPrev = self.list[checkBuyer.prev];

                if(buyerPrev.user != address(0x0)) {
                    buyerPrev.next = buyer.user;
                    buyer.prev = buyerPrev.user;
                }
                else {
                    self.head = buyer.user;
                    buyer.prev = address(0x0);
                }

                buyer.next = checkBuyer.user;
                checkBuyer.prev = buyer.user;

                return;
            }

            if(checkBuyer.next == address(0x0)) {
                checkBuyer.next = buyer.user;
                buyer.prev = checkBuyer.user;

                return;
            }

            count = count.add(1);
            checkBuyer = self.list[checkBuyer.next];
        }
    }

}
