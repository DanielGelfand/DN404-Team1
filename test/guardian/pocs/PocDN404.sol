// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../src/DN404.sol";
import "../../../src/DN404Mirror.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract PocDN404 is DN404, Ownable {
    string private _name;
    string private _symbol;
    string private _baseURI;

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


    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function mintNext(address to, uint256 amount) public onlyOwner {
        _mintNext(to, amount);
    }
}