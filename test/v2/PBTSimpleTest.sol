// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/SoladyTest.sol";
import "../../src/v2/mocks/PBTSimpleMock.sol";

contract PBTSimpleTest is SoladyTest {
    PBTSimpleMock pbt;

    function setUp() public {
        pbt = new PBTSimpleMock("PBTSimple", "PBTS", 1000);
    }

    function testSetAndGetChip(bytes32) public {
        uint256 set;
        for (uint i; i < 5; ++i) {
            uint tokenId = _bound(_random(), 0, 3);
            address chipId = address(uint160(_bound(_random(), 1, 3)));
            pbt.setChip(tokenId, chipId);
            set |= 1 << uint160(chipId);
        }
        vm.expectRevert(PBTSimple.ChipIdIsZeroAddress.selector);
        pbt.tokenIdFor(address(0));
        for (uint256 j = 1; j < 5; ++j) {
            address chipId = address(uint160(j));
            if (set & (1 << j) != 0) {
                pbt.tokenIdFor(chipId);
            } else {
                vm.expectRevert();
                pbt.tokenIdFor(chipId);
            }
        }
    }

}
