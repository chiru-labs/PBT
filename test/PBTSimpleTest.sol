// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/mocks/PBTSimpleMock.sol";

contract PBTSimpleTest is Test {
    PBTSimpleMock public pbt;
    uint128 public tokenId1 = 1;
    uint128 public tokenId2 = 2;
    address public user1 = vm.addr(1);
    address public user2 = vm.addr(2);
    address public chipAddr1 = vm.addr(101);
    address public chipAddr2 = vm.addr(102);
    address public chipAddr3 = vm.addr(103);
    address public chipAddr4 = vm.addr(104);

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

        uint128[] memory tokenIds = new uint128[](1);
        tokenIds[0] = tokenId1;

        vm.expectRevert(ArrayLengthMismatch.selector);
        pbt.seedChipToTokenMapping(chipAddresses, tokenIds, true);
    }

    function testSeedChipToTokenMappingExistingToken() public mintedTokens {
        address[] memory chipAddresses = new address[](2);
        chipAddresses[0] = chipAddr1;
        chipAddresses[1] = chipAddr2;

        uint128[] memory tokenIds = new uint128[](2);
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

        uint128[] memory tokenIds = new uint128[](2);
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

        uint128[] memory tokenIds = new uint128[](2);
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
}
