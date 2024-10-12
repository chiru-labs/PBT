// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../utils/SoladyTest.sol";
import "solady/utils/LibBitmap.sol";
import "solady/utils/ECDSA.sol";
import "../../src/v2/mocks/PBTSimpleMock.sol";

contract PBTSimpleTest is SoladyTest {
    using LibBitmap for *;
    LibBitmap.Bitmap chipIdHasAssignment;

    PBTSimpleMock pbt;

    uint256 internal constant _MAX_DURATION_WINDOW = 1000;

    function setUp() public {
        pbt = new PBTSimpleMock("PBTSimple", "PBTS", _MAX_DURATION_WINDOW);
    }

    function testSetAndGetChip() public {
        for (uint i; i < 3; ++i) {
            uint tokenId = i << 64;
            address chipId = address(uint160((i + 1) << 128));
            pbt.setChip(tokenId, chipId);
        }
        for (uint i; i < 3; ++i) {
            uint tokenId = i << 64;
            address chipId = address(uint160((i + 1) << 128));
            assertEq(pbt.tokenIdFor(chipId), tokenId);
        }
        for (uint i; i < 3; ++i) {
            uint tokenId = i << 64;
            address oldChipId = address(uint160((i + 1) << 128));
            address newChipId = address(uint160((i + 1) << 32));
            pbt.setChip(pbt.tokenIdFor(oldChipId), newChipId);
            assertEq(pbt.tokenIdFor(newChipId), tokenId);
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.tokenIdFor(oldChipId);
        }
        for (uint i; i < 3; ++i) {
            uint tokenId = i << 64;
            address oldChipId = address(uint160((i + 1) << 128));
            address newChipId = address(uint160((i + 1) << 32));
            assertEq(pbt.tokenIdFor(newChipId), tokenId);
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.tokenIdFor(oldChipId);
        }
    }

    function testSetAndGetChip(bytes32) public {
        uint tokenId0 = _random() & 7;
        address chipId0 = address(uint160( (_random() & 7) + 1 ));
        pbt.setChip(tokenId0, chipId0);
        assertEq(pbt.tokenIdFor(chipId0), tokenId0);

        uint tokenId1 = _random() & 7;
        address chipId1 = address(uint160( (_random() & 7) + 1 ));
        pbt.setChip(tokenId1, chipId1);
        assertEq(pbt.tokenIdFor(chipId1), tokenId1);

        vm.expectRevert();
        pbt.tokenIdFor(address(0));

        if (chipId0 == chipId1 && tokenId0 != tokenId1) {
            assertEq(pbt.tokenIdFor(chipId1), tokenId1);
            address chipId2 = _sampleNotEq(chipId1);
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.tokenIdFor(address(chipId2));
            if (_randomChance(2)) {
                pbt.unsetChip(tokenId1);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId1);
                return;
            }
        }
        if (chipId0 != chipId1 && tokenId0 != tokenId1) {
            assertEq(pbt.tokenIdFor(chipId0), tokenId0);
            assertEq(pbt.tokenIdFor(chipId1), tokenId1);
            address chipId2 = _sampleNotEq(chipId0, chipId1);
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.tokenIdFor(address(chipId2));
            if (_randomChance(2)) {
                pbt.unsetChip(tokenId1);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId1);
                assertEq(pbt.tokenIdFor(chipId0), tokenId0);
                pbt.unsetChip(tokenId0);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId0);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId1);
                return;
            }
        }
        if (chipId0 == chipId1 && tokenId0 == tokenId1) {
            assertEq(pbt.tokenIdFor(chipId0), tokenId0);
            assertEq(pbt.tokenIdFor(chipId1), tokenId1);
            address chipId2 = _sampleNotEq(chipId0, chipId1);
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.tokenIdFor(address(chipId2));
            if (_randomChance(2)) {
                pbt.unsetChip(tokenId1);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId1);
                return;
            }
        }
        if (chipId0 != chipId1 && tokenId0 == tokenId1) {
            assertEq(pbt.tokenIdFor(chipId1), tokenId1);
            address chipId2 = _sampleNotEq(chipId1);
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.tokenIdFor(address(chipId2));
            if (_randomChance(2)) {
                pbt.unsetChip(tokenId1);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId1);
                vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
                pbt.tokenIdFor(chipId0);
                return;
            }
        }
    }

    function _sampleNotEq(address a) internal returns (address c) {
        while (true) {
            c = address(uint160( (_random() & 7) + 1 ));
            if (c != a) break;
        }
    }

    function _sampleNotEq(address a, address b) internal returns (address c) {
        while (true) {
            c = address(uint160( (_random() & 7) + 1 ));
            if (c != a && c != b) break;
        }
    }

    function testAdvanceBlock(bytes32) public {
        _mine();
        bytes32 blockHash0 = blockhash(block.number - 1);
        emit LogBytes32(blockHash0);
        assert(blockHash0 != bytes32(0));
        _mine();
        bytes32 blockHash1 = blockhash(block.number - 1);
        emit LogBytes32(blockHash1);
        assert(blockHash1 != bytes32(0));
        assert(blockHash0 != blockHash1);
    }

    function _mine() internal {
        unchecked {
            vm.warp(_bound(_random(), _MAX_DURATION_WINDOW * 2, _MAX_DURATION_WINDOW * 10));
            vm.roll(block.number + (_random() & 7) + 1);    
        }
    }

    struct _TestTemps {
        uint tokenId;
        address chipId;
        uint chipPrivateKey;
        address to;
        uint sigTimestamp;
        bytes extras;
        bytes chipSig;
        bytes data;
        uint warppedTimestamp;
    }

    function _testTemps() internal returns (_TestTemps memory t) {
        _mine();
        t.tokenId = _random();
        (t.chipId, t.chipPrivateKey) = _randomSigner();

        t.to = _randomNonZeroAddress();
        t.sigTimestamp = block.timestamp - _bound(_random(), 0, _MAX_DURATION_WINDOW);
        if (_randomChance(2)) {
            t.extras = _randomBytes();    
        }
        t.chipSig = _genSig(t);
    }

    function testMintAndEverything(bytes32) public {
        _TestTemps memory t = _testTemps();

        if (_randomChance(8)) {
            t.data = _randomBytes();
            assertFalse(pbt.isChipSignatureForToken(t.tokenId, t.data, _genSig(t, t.data)));    
        }
        
        if (_randomChance(8)) {
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);
            pbt.mint(t.to, t.chipId, t.chipSig, t.sigTimestamp, t.extras);            
            return;
        }
        pbt.setChip(t.tokenId, t.chipId);    

        if (_randomChance(8)) {
            pbt.unsetChip(t.tokenId);  
            vm.expectRevert(PBTSimple.NoMappedTokenForChip.selector);  
            pbt.mint(t.to, t.chipId, t.chipSig, t.sigTimestamp, t.extras);
            return;
        }        

        if (_randomChance(8)) {
            t.warppedTimestamp = _bound(_random(), 0, block.timestamp + _MAX_DURATION_WINDOW * 2);
            vm.warp(t.warppedTimestamp);
            if (t.warppedTimestamp < t.sigTimestamp) {
                vm.expectRevert(PBTSimple.SignatureTimestampInFuture.selector);
                pbt.mint(t.to, t.chipId, t.chipSig, t.sigTimestamp, t.extras);
                return;
            }
            if (t.warppedTimestamp >= t.sigTimestamp + _MAX_DURATION_WINDOW) {
                vm.expectRevert(PBTSimple.SignatureTimestampTooOld.selector);
                pbt.mint(t.to, t.chipId, t.chipSig, t.sigTimestamp, t.extras);
                return;
            }
        }

        assertEq(pbt.tokenIdFor(t.chipId), t.tokenId);
        assertEq(pbt.chipNonce(t.chipId), bytes32(0));
        assertEq(pbt.mint(t.to, t.chipId, t.chipSig, t.sigTimestamp, t.extras), t.tokenId);
        assertEq(pbt.ownerOf(t.tokenId), t.to);
        assert(pbt.chipNonce(t.chipId) != bytes32(0));
        assertEq(pbt.tokenIdFor(t.chipId), t.tokenId);

        if (_randomChance(8)) {
            t.data = _randomBytes();
            bytes memory sig = _genSig(t, t.data);
            assertTrue(pbt.isChipSignatureForToken(t.tokenId, t.data, sig));    
            pbt.unsetChip(t.tokenId);
            assertFalse(pbt.isChipSignatureForToken(t.tokenId, t.data, sig));
            return;
        }
        
        t.to = _randomNonZeroAddress();
        t.chipSig = _genSig(t);
        pbt.transferToken(t.to, t.chipId, t.chipSig, t.sigTimestamp, _randomChance(2), t.extras);
        assertEq(pbt.ownerOf(t.tokenId), t.to);
    }

    function _genSig(_TestTemps memory t, bytes memory data) internal returns (bytes memory) {
        bytes32 hash = ECDSA.toEthSignedMessageHash(keccak256(data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(t.chipPrivateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    function _genSig(_TestTemps memory t) internal returns (bytes memory) {
        return _genSig(t, abi.encode(address(pbt), block.chainid, pbt.chipNonce(t.chipId), t.to, t.sigTimestamp, keccak256(t.extras)));
    }

    function _randomBytes() internal returns (bytes memory result) {
        uint256 r = _random();
        uint256 n = r & 0x3ff;
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            mstore(0x00, r)
            let t := keccak256(0x00, 0x20)
            if gt(byte(0, r), 16) { n := and(r, 0x7f) }
            codecopy(add(result, 0x20), byte(0, t), codesize())
            codecopy(add(result, n), byte(1, t), codesize())
            mstore(0x40, add(n, add(0x40, result)))
            mstore(result, n)
            if iszero(byte(3, t)) { result := 0x60 }
        }
    }

    function _truncateBytes(bytes memory b, uint256 n)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            if gt(mload(b), n) { mstore(b, n) }
            result := b
        }
    }
}
