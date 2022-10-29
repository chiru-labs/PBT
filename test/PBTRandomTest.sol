// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/IPBT.sol";
import "../src/mocks/PBTRandomMock.sol";

contract PBTRandomTest is Test {
    event PBTMint(uint256 indexed tokenId, address indexed chipAddress);
    event PBTChipRemapping(uint256 indexed tokenId, address indexed oldChipAddress, address indexed newChipAddress);
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

    function _createSignature(bytes32 payload, uint256 chipAddrNum) private returns (bytes memory signature) {
        return _createSignature(abi.encodePacked(payload), chipAddrNum);
    }

    function testMintTokenWithChip() public {
        // Change block number to the next block to set blockHash(blockNumber)
        vm.roll(blockNumber + 1);

        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);

        vm.startPrank(user1);
        vm.roll(blockNumber + 2);
        uint256 expectedTokenId = 328;

        // First mint will fail because seeding hasn't happened
        vm.expectRevert(InvalidChipAddress.selector);
        pbt.mintTokenWithChip(signature, blockNumber);

        // Seed chip addresses
        address[] memory chipAddresses = new address[](1);
        chipAddresses[0] = chipAddr1;
        pbt.seedChipAddresses(chipAddresses);

        // Mint should now succeed
        vm.expectEmit(true, true, true, true);
        emit PBTMint(expectedTokenId, chipAddr1);
        pbt.mintTokenWithChip(signature, blockNumber);

        // Make sure a chipAddr that has been minted can't mint again
        vm.expectRevert(ChipAlreadyLinkedToMintedToken.selector);
        pbt.mintTokenWithChip(signature, blockNumber);
    }

    modifier withSeededChips() {
        address[] memory chipAddresses = new address[](3);
        chipAddresses[0] = chipAddr1;
        chipAddresses[1] = chipAddr2;
        chipAddresses[2] = chipAddr3;
        pbt.seedChipAddresses(chipAddresses);
        _;
    }

    function testIsChipSignatureForToken() public withSeededChips {
        vm.roll(blockNumber + 1);

        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);

        vm.startPrank(user1);
        vm.roll(blockNumber + 2);
        uint256 tokenId = pbt.mintTokenWithChip(signature, blockNumber);
        assertEq(pbt.isChipSignatureForToken(tokenId, payload, signature), true);

        vm.expectRevert(NoMintedTokenForChip.selector);
        pbt.isChipSignatureForToken(tokenId + 1, payload, signature);
    }

    function testUpdateChips() public {
        // Change block number to the next block to set blockHash(blockNumber)
        vm.roll(blockNumber + 1);

        address[] memory oldChips = new address[](2);
        oldChips[0] = chipAddr1;
        oldChips[1] = chipAddr2;
        pbt.seedChipAddresses(oldChips);

        address[] memory newChips = new address[](2);
        newChips[0] = chipAddr3;
        newChips[1] = chipAddr4;

        // Chips haven't minted so they can't be updated
        vm.expectRevert(UpdatingChipForUnsetChipMapping.selector);
        pbt.updateChips(oldChips, newChips);

        // Mint the two chip addresses
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);
        vm.prank(user1);
        uint256 tokenId1 = pbt.mintTokenWithChip(signature, blockNumber);

        payload = abi.encodePacked(user2, blockhash(blockNumber));
        signature = _createSignature(payload, 102);
        vm.prank(user2);
        uint256 tokenId2 = pbt.mintTokenWithChip(signature, blockNumber);

        // updateChips should now succeed
        vm.expectEmit(true, true, true, true);
        emit PBTChipRemapping(tokenId1, chipAddr1, chipAddr3);
        vm.expectEmit(true, true, true, true);
        emit PBTChipRemapping(tokenId2, chipAddr2, chipAddr4);
        pbt.updateChips(oldChips, newChips);

        // Verify the call works as inteded
        PBTRandom.TokenData memory td = pbt.getTokenData(chipAddr1);
        assertEq(td.set, false);
        assertEq(td.tokenId, 0);
        assertEq(td.chipAddress, address(0));

        td = pbt.getTokenData(chipAddr2);
        assertEq(td.set, false);
        assertEq(td.tokenId, 0);
        assertEq(td.chipAddress, address(0));

        td = pbt.getTokenData(chipAddr3);
        assertEq(td.set, true);
        assertEq(td.tokenId, tokenId1);
        assertEq(td.chipAddress, chipAddr3);

        td = pbt.getTokenData(chipAddr4);
        assertEq(td.set, true);
        assertEq(td.tokenId, tokenId2);
        assertEq(td.chipAddress, chipAddr4);
    }
}
