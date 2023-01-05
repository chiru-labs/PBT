// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/mocks/PBTLocketMock.sol";

contract PBTSimpleTest is Test {
    event PBTMint(uint256 indexed tokenId, address indexed chipAddress);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    PBTLocketMock public pbt;
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
        pbt = new PBTLocketMock("PBTLocket", "PBTL");
    }

    modifier mintedTokens() {
        pbt.mint(user1, tokenId1);
        pbt.mint(user2, tokenId2);
        _;
    }

    modifier setChipTokenMapping() {
        address[] memory chipAddresses = new address[](2);
        chipAddresses[0] = chipAddr1;
        chipAddresses[1] = chipAddr2;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);

        _;
    }

    function _createSignature(bytes memory payload, uint256 chipAddrNum) private returns (bytes memory signature) {
        bytes32 payloadHash = keccak256(abi.encodePacked(payload));
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipAddrNum, signedHash);
        signature = abi.encodePacked(r, s, v);
    }

    function testLockAndUnlock(bool useSafeTransfer) public setChipTokenMapping mintedTokens {
        vm.roll(blockNumber + 1);

        // Create inputs
        bytes memory payload = abi.encodePacked(user2, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);

        vm.startPrank(user2);
        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTransfer);

        pbt.lock(tokenId1);
        assertEq(pbt.checkLock(tokenId1), true);

        vm.expectRevert(TokenLocked.selector);
        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTransfer);

        pbt.unlock(tokenId1);
        assertEq(pbt.checkLock(tokenId1), false);

        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTransfer);
    }

    function testUnlockForSelfReceiver(bool useSafeTransfer) public setChipTokenMapping mintedTokens {
        vm.roll(blockNumber + 1);

        // Create inputs
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);
        bytes memory payload2 = abi.encodePacked(user2, blockhash(blockNumber));
        bytes memory chipSignature2 = _createSignature(payload2, 101);
        bytes memory payload3 = abi.encodePacked(user3, blockhash(blockNumber));
        bytes memory chipSignature3 = _createSignature(payload3, 101);

        vm.startPrank(user2);
        pbt.transferTokenWithChip(chipSignature2, blockNumber, useSafeTransfer);

        pbt.unlockForReceiver(tokenId1, user1);
        assertEq(pbt.checkLock(tokenId1), false);
        vm.stopPrank();

        vm.prank(user3);
        pbt.transferTokenWithChip(chipSignature3, blockNumber, useSafeTransfer);

        vm.startPrank(user1);
        vm.expectRevert(InvalidOwner.selector);
        pbt.lock(tokenId1);

        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTransfer);
        pbt.lock(tokenId1);
        vm.stopPrank();

        vm.prank(user3);
        vm.expectRevert(TokenLocked.selector);
        pbt.transferTokenWithChip(chipSignature3, blockNumber, useSafeTransfer);
    }

    function testUnlockForReceiver(bool useSafeTransfer) public setChipTokenMapping mintedTokens {
        vm.roll(blockNumber + 1);

        // Create inputs
        bytes memory payload = abi.encodePacked(user2, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);
        bytes memory payload3 = abi.encodePacked(user3, blockhash(blockNumber));
        bytes memory chipSignature3 = _createSignature(payload3, 101);

        vm.startPrank(user2);
        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTransfer);

        pbt.unlockForReceiver(tokenId1, user2);
        assertEq(pbt.checkLock(tokenId1), false);
        vm.stopPrank();

        vm.prank(user3);
        pbt.transferTokenWithChip(chipSignature3, blockNumber, useSafeTransfer);

        vm.startPrank(user2);
        vm.expectRevert(InvalidOwner.selector);
        pbt.lock(tokenId1);

        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTransfer);
        pbt.lock(tokenId1);
        vm.stopPrank();

        vm.prank(user3);
        vm.expectRevert(TokenLocked.selector);
        pbt.transferTokenWithChip(chipSignature3, blockNumber, useSafeTransfer);
    }


    function testSupportsInterface() public {
        assertEq(pbt.supportsInterface(type(IPBT).interfaceId), true);
        assertEq(pbt.supportsInterface(type(IERC721).interfaceId), true);
    }
}
