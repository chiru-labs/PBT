// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * An implementation of 721 that's publicly readonly (no approvals or transfers exposed).
 */
contract ERC721ReadOnly is ERC721 {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function approve(address, uint256) public virtual override {
        revert("ERC721 public approve not allowed");
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: invalid token ID");
        return address(0);
    }

    function setApprovalForAll(address, bool) public virtual override {
        revert("ERC721 public setApprovalForAll not allowed");
    }

    function isApprovedForAll(address, address) public view virtual override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public virtual override {
        revert("ERC721 public transferFrom not allowed");
    }

    function safeTransferFrom(address, address, uint256) public virtual override {
        revert("ERC721 public safeTransferFrom not allowed");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public virtual override {
        revert("ERC721 public safeTransferFrom not allowed");
    }
}
