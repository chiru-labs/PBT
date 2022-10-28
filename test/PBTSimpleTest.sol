// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/mocks/PBTSimpleMock.sol";

contract PBTSimpleTest is Test {
    event PBTMint(uint256 indexed tokenId, address indexed chipAddress);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    PBTSimpleMock public pbt;
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
        pbt = new PBTSimpleMock("PBTSimple", "PBTS");
    }

    modifier mintedTokens() {
        pbt.mint(user1, tokenId1);
        pbt.mint(user2, tokenId2);
        _;
    }

    function testSeedChipToTokenMappingInvalidInput() public {
        address[] memory chipAddresses = new address[](2);
        chipAddresses[0] = chipAddr1;
        chipAddresses[1] = chipAddr2;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId1;

        vm.expectRevert(ArrayLengthMismatch.selector);
        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);
    }

    function testSeedChipToTokenMappingExistingToken() public mintedTokens {
        address[] memory chipAddresses = new address[](2);
        chipAddresses[0] = chipAddr1;
        chipAddresses[1] = chipAddr2;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        vm.expectRevert(SeedingChipDataForExistingToken.selector);
        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);

        // This call will succeed because the flag is set to false
        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, false);
    }

    function testSeedChipToTokenMapping() public {
        address[] memory chipAddresses = new address[](2);
        chipAddresses[0] = chipAddr1;
        chipAddresses[1] = chipAddr2;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);

        PBTSimple.TokenData memory td1 = pbt.getTokenData(chipAddr1);
        assertEq(td1.tokenId, tokenId1);
        assertEq(td1.chipAddress, chipAddr1);
        assertEq(td1.set, true);

        PBTSimple.TokenData memory td2 = pbt.getTokenData(chipAddr2);
        assertEq(td2.tokenId, tokenId2);
        assertEq(td2.chipAddress, chipAddr2);
        assertEq(td2.set, true);
    }

    function testUpdateChipsInvalidInput() public {
        address[] memory chipAddressesOld = new address[](2);
        chipAddressesOld[0] = chipAddr1;
        chipAddressesOld[1] = chipAddr2;

        address[] memory chipAddressesNew = new address[](1);
        chipAddressesNew[0] = chipAddr3;

        vm.expectRevert(ArrayLengthMismatch.selector);
        pbt.updateChips(chipAddressesOld, chipAddressesNew);
    }

    function testUpdateChipsUnsetChip() public {
        address[] memory chipAddressesOld = new address[](2);
        chipAddressesOld[0] = chipAddr1;
        chipAddressesOld[1] = chipAddr2;

        address[] memory chipAddressesNew = new address[](2);
        chipAddressesNew[0] = chipAddr3;
        chipAddressesNew[1] = chipAddr4;

        // An error will occur because tokenDatas have not been set
        vm.expectRevert(UpdatingChipForUnsetChipMapping.selector);
        pbt.updateChips(chipAddressesOld, chipAddressesNew);
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

    function testUpdateChips() public setChipTokenMapping {
        address[] memory chipAddressesOld = new address[](2);
        chipAddressesOld[0] = chipAddr1;
        chipAddressesOld[1] = chipAddr2;

        address[] memory chipAddressesNew = new address[](2);
        chipAddressesNew[0] = chipAddr3;
        chipAddressesNew[1] = chipAddr4;

        pbt.updateChips(chipAddressesOld, chipAddressesNew);

        // Validate that the old tokenDatas have been cleared
        PBTSimple.TokenData memory td1 = pbt.getTokenData(chipAddr1);
        assertEq(td1.tokenId, 0);
        assertEq(td1.chipAddress, address(0));
        assertEq(td1.set, false);
        PBTSimple.TokenData memory td2 = pbt.getTokenData(chipAddr2);
        assertEq(td2.tokenId, 0);
        assertEq(td2.chipAddress, address(0));
        assertEq(td2.set, false);

        // Validate the new tokenDatas have been set
        PBTSimple.TokenData memory td3 = pbt.getTokenData(chipAddr3);
        assertEq(td3.tokenId, tokenId1);
        assertEq(td3.chipAddress, chipAddr3);
        assertEq(td3.set, true);
        PBTSimple.TokenData memory td4 = pbt.getTokenData(chipAddr4);
        assertEq(td4.tokenId, tokenId2);
        assertEq(td4.chipAddress, chipAddr4);
        assertEq(td4.set, true);
    }

    function testTokenIdFor() public {
        // This will fail because chipAddr3 isn't set in tokenDatas
        vm.expectRevert(NoMappedTokenForChip.selector);
        pbt.tokenIdFor(chipAddr3);

        // Set chipAddr3 to tokenDatas
        address[] memory chipAddresses = new address[](1);
        chipAddresses[0] = chipAddr3;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId3;
        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);

        // Should error out because tokenId3 has not been minted
        vm.expectRevert(NoMintedTokenForChip.selector);
        pbt.tokenIdFor(chipAddr3);

        // Mint token, should no longer error
        pbt.mint(user1, tokenId3);
        assertEq(pbt.tokenIdFor(chipAddr3), tokenId3);
    }

    function testTokenIdMappedFor() public {
        // This will fail because chipAddr3 isn't set in tokenDatas
        vm.expectRevert(NoMappedTokenForChip.selector);
        pbt.tokenIdMappedFor(chipAddr3);

        // Set chipAddr3 to tokenDatas
        address[] memory chipAddresses = new address[](1);
        chipAddresses[0] = chipAddr3;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId3;
        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);

        assertEq(pbt.tokenIdMappedFor(chipAddr3), tokenId3);
    }

    function _createSignature(bytes memory payload, uint256 chipAddrNum) private returns (bytes memory signature) {
        bytes32 payloadHash = keccak256(abi.encodePacked(payload));
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipAddrNum, signedHash);
        signature = abi.encodePacked(r, s, v);
    }

    function testIsChipSignatureForToken() public setChipTokenMapping mintedTokens {
        // Create signature from payload
        bytes memory payload = abi.encodePacked("ThisIsPBTSimple");
        bytes32 payloadHash = keccak256(payload);
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(101, signedHash);
        bytes memory chipSignature = abi.encodePacked(r, s, v);

        assertEq(pbt.isChipSignatureForToken(tokenId1, payload, chipSignature), true);
    }

    function testMintTokenWithChip() public setChipTokenMapping {
        vm.roll(blockNumber + 1);

        // Create inputs
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit PBTMint(tokenId1, chipAddr1);
        uint256 tokenId = pbt.mintTokenWithChip(chipSignature, blockNumber);
        assertEq(tokenId, tokenId1);
        assertEq(pbt.balanceOf(user1), 1);
    }

    function testTransferTokenWithChip(bool useSafeTranfer) public setChipTokenMapping mintedTokens {
        vm.roll(blockNumber + 1);

        // Create inputs
        bytes memory payload = abi.encodePacked(user2, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);

        vm.prank(user2);
        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, user2, 1);
        pbt.transferTokenWithChip(chipSignature, blockNumber, useSafeTranfer);

        assertEq(pbt.balanceOf(user1), 0);
        assertEq(pbt.balanceOf(user2), 2);
    }

    function testGetTokenDataForChipSignatureInvalidBlockNumber() public setChipTokenMapping {
        vm.roll(blockNumber);

        // Create inputs
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);

        vm.prank(user1);
        vm.expectRevert(InvalidBlockNumber.selector);
        pbt.getTokenDataForChipSignature(chipSignature, blockNumber);
    }

    function testGetTokenDataForChipSignatureBlockNumTooOld() public setChipTokenMapping {
        // Create inputs
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);

        vm.roll(blockNumber + 101);
        vm.prank(user1);

        vm.expectRevert(BlockNumberTooOld.selector);
        pbt.getTokenDataForChipSignature(chipSignature, blockNumber);
    }

    function testGetTokenDataForChipSignature() public setChipTokenMapping {
        // Change block number to the next block to set blockHash(blockNumber)
        vm.roll(blockNumber + 1);

        // Create inputs
        bytes memory payload = abi.encodePacked(user1, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 101);

        vm.roll(blockNumber + 100);
        vm.prank(user1);
        PBTSimple.TokenData memory td = pbt.getTokenDataForChipSignature(chipSignature, blockNumber);

        assertEq(td.tokenId, tokenId1);
        assertEq(td.chipAddress, chipAddr1);
        assertEq(td.set, true);
    }

    function testGetTokenDataForChipSignatureInvalid() public setChipTokenMapping {
        // Change block number to the next block to set blockHash(blockNumber)
        vm.roll(blockNumber + 1);

        // Create an invalid chip signature
        bytes memory payload = abi.encodePacked(user3, blockhash(blockNumber));
        bytes memory chipSignature = _createSignature(payload, 9999);

        vm.roll(blockNumber + 100);
        vm.prank(user3);
        vm.expectRevert(InvalidSignature.selector);
        pbt.getTokenDataForChipSignature(chipSignature, blockNumber);
    }

    function testSupportsInterface() public {
        assertEq(pbt.supportsInterface(type(IPBT).interfaceId), true);
        assertEq(pbt.supportsInterface(type(IERC721).interfaceId), true);
    }
}
