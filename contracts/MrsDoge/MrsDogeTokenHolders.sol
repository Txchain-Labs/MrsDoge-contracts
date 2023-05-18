// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./SafeMath.sol";
import "./IterableMapping.sol";


library MrsDogeTokenHolders {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    uint256 public constant smallHolderTokensAmount = 50000 * 10**18;
    uint256 public constant largeHolderTokensAmount = 500000 * 10**18;
    uint256 public constant hugeHolderTokensAmount = 5000000 * 10**18;

    struct Holders {
        IterableMapping.Map smallTokenHolders;
        IterableMapping.Map largeTokenHolders;
        IterableMapping.Map hugeTokenHolders;
        uint256 updatesLockedUntil;
    }

    enum HolderType {
        Small,
        Large,
        Huge
    }

    function lockUntil(Holders storage holders, uint256 blockNumber) public {
        holders.updatesLockedUntil = blockNumber;
    }

    function removeUser(Holders storage holders, address user) public {
        holders.smallTokenHolders.remove(user);
        holders.largeTokenHolders.remove(user);
        holders.hugeTokenHolders.remove(user);
    }

    function canSetUser(Holders storage holders, IterableMapping.Map storage tokenHolders, address user) private view returns (bool) {
        return block.number >= holders.updatesLockedUntil || tokenHolders.inserted[user];
    }

    function updateTokenHolderStatus(Holders storage holders, address user, uint256 balance) public {
        bool updatesLocked = block.number < holders.updatesLockedUntil;

        if(balance >= smallHolderTokensAmount) {
            require(canSetUser(holders, holders.smallTokenHolders, user), "MRSDogeTokenHolders: can't add use to small token holders mapping");
            holders.smallTokenHolders.set(user, balance);
        }
        else if(holders.smallTokenHolders.inserted[user]) {
            require(!updatesLocked, "MRSDogeTokenHolders: can't remove user from small token holders mapping");
            holders.smallTokenHolders.remove(user);
        }

        if(balance >= largeHolderTokensAmount) {
            require(canSetUser(holders, holders.largeTokenHolders, user), "MRSDogeTokenHolders: can't add use to large token holders mapping");
            holders.largeTokenHolders.set(user, balance);
        }
        else if(holders.largeTokenHolders.inserted[user]) {
            require(!updatesLocked, "MRSDogeTokenHolders: can't remove user from large token holders mapping");
            holders.largeTokenHolders.remove(user);
        }

        if(balance >= hugeHolderTokensAmount) {
            require(canSetUser(holders, holders.hugeTokenHolders, user), "MRSDogeTokenHolders: can't add use to huge token holders mapping");
            holders.hugeTokenHolders.set(user, balance);
        }
        else if(holders.hugeTokenHolders.inserted[user]) {
            require(!updatesLocked, "MRSDogeTokenHolders: can't remove user from huge token holders mapping");
            holders.hugeTokenHolders.remove(user);
        }
    }

    function isSmallHolder(Holders storage holders, address user) public view returns (bool) {
        return holders.smallTokenHolders.inserted[user];
    }

    function isLargeHolder(Holders storage holders, address user) public view returns (bool) {
        return holders.largeTokenHolders.inserted[user];
    }

    function isHugeHolder(Holders storage holders, address user) public view returns (bool) {
        return holders.hugeTokenHolders.inserted[user];
    }


    // gets up to 'count' random holders, and users can be chosen multiple times
    function getRandomHolders(Holders storage holders, uint256 seed, uint256 count, HolderType holderType) public view returns (address[] memory users) {
        IterableMapping.Map storage map;

        if(holderType == HolderType.Small) {
            map = holders.smallTokenHolders;
        }
        else if(holderType == HolderType.Large) {
            map = holders.largeTokenHolders;
        }
        else {
            map = holders.hugeTokenHolders;
        }

        //make sure random indexes differs based on holder type
        seed = uint256(keccak256(abi.encode(seed, uint256(holderType) + 1)));

        if(map.size() > 0) {
            if(map.size() < count) {
                count = map.size();
            }

            users = new address[](count);

            for(uint256 i = 0; i < count; i = i.add(1)) {
                uint256 index = seed % count;
                users[i] = map.getKeyAtIndex(index);

                seed = uint256(keccak256(abi.encode(seed)));
            }
        }
    }

}
