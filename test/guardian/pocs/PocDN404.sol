// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../src/DN404.sol";
import "../../../src/DN404Mirror.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IStrategy} from "./MaliciousStrategy.sol";

contract PocDN404 is DN404, Ownable {
    string private _name;
    string private _symbol;
    string private _baseURI;

    mapping (address => bool) strategyMapping;
    constructor(
        string memory name_,
        string memory symbol_
    ) {
        _initializeOwner(msg.sender);
        _name = name_;
        _symbol = symbol_;

    }

    function initializeDN404(
        uint256 initialTokenSupply,
        address initialSupplyOwner,
        address mirrorNFTContract
    ) public {
        _initializeDN404(initialTokenSupply, initialSupplyOwner, mirrorNFTContract);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function unit() public view returns (uint256) {
        return _unit();
    }

    function _tokenURI(uint256 tokenId) internal view override returns (string memory result) {
        if (bytes(_baseURI).length != 0) {
            result = string(abi.encodePacked(_baseURI, LibString.toString(tokenId)));
        }
    }
    // This allows the owner of the contract to mint more tokens.
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function enableStrategy(address strategy) public onlyOwner {
        strategyMapping[strategy] = true;
    }

    /// @dev Hook that is called after any NFT token transfers, including minting and burning.
    function _afterNFTTransfer(address from, address to, uint256 id) internal override {        
        if (strategyMapping[from]) {
            IStrategy(from).cleanUp(to, id);
        } 
        if (strategyMapping[to]) {
            IStrategy(to).manage(from, id);
        }
    }
}