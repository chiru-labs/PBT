// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/mocks/PBTRandomMock.sol";

contract PBTRandomTest is Test {
    event PBTMint(uint256 indexed tokenId, address indexed chipAddress);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    PBTRandomMock public pbt;
    uint256 public tokenId1 = 1;
    uint256 public tokenId2 = 2;
    uint256 public tokenId3 = 3;
    address public user1 = vm.addr(1);
    address public user2 = vm.addr(2);
    address public user3 = vm.addr(3);
    address public chipAddr1 = vm.addr(101);
    address public chipAddr2 = vm.addr(102);
    address public chipAddr3 = vm.addr(103);
    address public chipAddr4 = vm.addr(104);
    uint256 public blockNumber = 10;

    function setUp() public {
        pbt = new PBTRandomMock("PBTRandom", "PBTR");
    }

    function _createSignature(bytes memory payload, uint256 chipAddrNum) private returns (bytes memory signature) {
        bytes32 payloadHash = keccak256(abi.encodePacked(payload));
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipAddrNum, signedHash);
        signature = abi.encodePacked(r, s, v);
    }

    function testMintTokenWithChip() public {
        // Change block number to the next block to set blockHash(blockNumber)
        vm.roll(blockNumber + 1);

        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);

        vm.startPrank(user1);
        vm.roll(blockNumber + 2);
        uint256 expectedTokenId = 328;

        vm.expectEmit(true, true, true, true);
        emit PBTMint(expectedTokenId, chipAddr1);
        pbt.mintTokenWithChip(signature, blockNumber);

        // Make sure a chipAddr that has been minted can't mint again
        vm.expectRevert(ChipAlreadyLinkedToMintedToken.selector);
        pbt.mintTokenWithChip(signature, blockNumber);
    }
}
