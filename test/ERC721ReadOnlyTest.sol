// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/mocks/ERC721ReadOnlyMock.sol";

contract ERC721ReadOnlyTest is Test {
    address public user1 = vm.addr(1);
    address public user2 = vm.addr(2);
    uint256 public tokenId = 1;
    ERC721ReadOnlyMock public erc721;

    function setUp() public {
        erc721 = new ERC721ReadOnlyMock("ReadOnly", "RO");
        erc721.mint(user1, tokenId);
    }

    function testApprove() public {
        vm.expectRevert("ERC721 public approve not allowed");
        erc721.approve(user1, 1);
    }

    function testGetApproved() public {
        assertEq(erc721.getApproved(tokenId), address(0));
        vm.expectRevert("ERC721: invalid token ID");
        erc721.getApproved(tokenId + 100);
    }

    function testSetApprovalForAll() public {
        vm.expectRevert("ERC721 public setApprovalForAll not allowed");
        erc721.setApprovalForAll(user1, true);
    }

    function testIsApprovedForAll() public {
        assertEq(erc721.isApprovedForAll(user1, user2), false);
    }

    function testTransferFunctions() public {
        vm.expectRevert("ERC721 public transferFrom not allowed");
        erc721.transferFrom(user1, user2, tokenId);

        vm.expectRevert("ERC721 public safeTransferFrom not allowed");
        erc721.safeTransferFrom(user1, user2, tokenId);

        vm.expectRevert("ERC721 public safeTransferFrom not allowed");
        erc721.safeTransferFrom(user1, user2, tokenId, "");
    }
}
