// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../ERC721ReadOnly.sol";

contract ERC721ReadOnlyMock is ERC721ReadOnly {
    constructor(string memory name_, string memory symbol_) ERC721ReadOnly(name_, symbol_) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}
