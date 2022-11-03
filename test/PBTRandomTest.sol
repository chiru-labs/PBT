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
        pbt = new PBTRandomMock("PBTRandom", "PBTR", 10);
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
        uint256 expectedTokenId = 3;

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

    function testTokenIdFor() public {
        vm.expectRevert(NoMintedTokenForChip.selector);
        pbt.tokenIdFor(chipAddr1);

        vm.roll(blockNumber + 1);

        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);
        vm.startPrank(user1);

        address[] memory chipAddresses = new address[](1);
        chipAddresses[0] = chipAddr1;
        pbt.seedChipAddresses(chipAddresses);

        uint256 tokenId = pbt.mintTokenWithChip(signature, blockNumber);
        assertEq(pbt.tokenIdFor(chipAddr1), tokenId);
    }

    function testTransferTokenWithChip(bool useSafeTransfer) public withSeededChips {
        vm.roll(blockNumber + 1);
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);
        vm.prank(user1);
        uint256 tokenId = pbt.mintTokenWithChip(signature, blockNumber);
        assertEq(pbt.ownerOf(tokenId), user1);

        vm.roll(blockNumber + 10);
        payload = abi.encodePacked(user2, blockhash(blockNumber + 9));
        signature = _createSignature(payload, 101);
        vm.prank(user2);
        pbt.transferTokenWithChip(signature, blockNumber + 9, useSafeTransfer);
        assertEq(pbt.ownerOf(tokenId), user2);
    }

    function testGetTokenDataForChipSignatureInvalid() public withSeededChips {
        vm.startPrank(user1);
        vm.roll(blockNumber + 1);
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);

        vm.expectRevert(InvalidSignature.selector);
        pbt.getTokenDataForChipSignature(signature, blockNumber);
        pbt.mintTokenWithChip(signature, blockNumber);

        // Current block number is the same as the signature block number which is invalid
        vm.expectRevert(InvalidBlockNumber.selector);
        pbt.getTokenDataForChipSignature(signature, blockNumber + 1);

        // Block number used in signature is too old
        vm.roll(blockNumber + 101);
        vm.expectRevert(BlockNumberTooOld.selector);
        pbt.getTokenDataForChipSignature(signature, blockNumber);
    }

    function testGetTokenDataForChipSignature() public withSeededChips {
        vm.startPrank(user1);
        vm.roll(blockNumber + 1);
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory signature = _createSignature(payload, 101);
        uint256 tokenId = pbt.mintTokenWithChip(signature, blockNumber);

        PBTRandom.TokenData memory td = pbt.getTokenDataForChipSignature(signature, blockNumber);
        assertEq(td.set, true);
        assertEq(td.chipAddress, chipAddr1);
        assertEq(td.tokenId, tokenId);
    }

    function testUseRandomAvailableTokenId() public {
        // randomIndex: 7
        // lastIndex: 9
        // _availableRemainingTokens: [0, 0, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(4);
        assertEq(pbt.useRandomAvailableTokenId(), 7);
        assertEq(pbt.getAvailableRemainingTokens(7), 9);

        // randomIndex: 1
        // lastIndex: 8
        // _availableRemainingTokens: [0, 8, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(5);
        assertEq(pbt.useRandomAvailableTokenId(), 1);
        assertEq(pbt.getAvailableRemainingTokens(1), 8);

        // randomIndex: 7
        // lastIndex: 7
        // _availableRemainingTokens: [0, 8, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(6);
        assertEq(pbt.useRandomAvailableTokenId(), 9);
        assertEq(pbt.getAvailableRemainingTokens(7), 9);

        // randomIndex: 4
        // lastIndex: 6
        // _availableRemainingTokens: [0, 8, 0, 0, 6, 0, 0, 9, 0, 0]
        vm.roll(7);
        assertEq(pbt.useRandomAvailableTokenId(), 4);
        assertEq(pbt.getAvailableRemainingTokens(4), 6);

        // randomIndex: 1
        // lastIndex: 5
        // _availableRemainingTokens: [0, 5, 0, 0, 6, 0, 0, 9, 0, 0]
        vm.roll(8);
        assertEq(pbt.useRandomAvailableTokenId(), 8);
        assertEq(pbt.getAvailableRemainingTokens(1), 5);

        // randomIndex: 0
        // lastIndex: 4
        // _availableRemainingTokens: [6, 5, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(7);
        assertEq(pbt.useRandomAvailableTokenId(), 0);
        assertEq(pbt.getAvailableRemainingTokens(0), 6);

        // randomIndex: 1
        // lastIndex: 3
        // _availableRemainingTokens: [6, 3, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(8);
        assertEq(pbt.useRandomAvailableTokenId(), 5);
        assertEq(pbt.getAvailableRemainingTokens(1), 3);

        // randomIndex: 1
        // lastIndex: 2
        // _availableRemainingTokens: [6, 2, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(9);
        assertEq(pbt.useRandomAvailableTokenId(), 3);
        assertEq(pbt.getAvailableRemainingTokens(1), 2);

        // randomIndex: 0
        // lastIndex: 1
        // _availableRemainingTokens: [2, 0, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(10);
        assertEq(pbt.useRandomAvailableTokenId(), 6);
        assertEq(pbt.getAvailableRemainingTokens(0), 2);

        // randomIndex: 0
        // lastIndex: 0
        // _availableRemainingTokens: [2, 0, 0, 0, 0, 0, 0, 9, 0, 0]
        vm.roll(11);
        assertEq(pbt.useRandomAvailableTokenId(), 2);
        assertEq(pbt.getAvailableRemainingTokens(0), 2);

        // All tokens have been assigned so an error should be raised
        vm.expectRevert(NoMoreTokenIds.selector);
        pbt.useRandomAvailableTokenId();
    }

    function testSupportsInterface() public {
        assertEq(pbt.supportsInterface(type(IPBT).interfaceId), true);
        assertEq(pbt.supportsInterface(type(IERC721).interfaceId), true);
    }
}
