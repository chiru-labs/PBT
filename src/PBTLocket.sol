// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./PBTSimple.sol";

error InvalidOwner();
error TokenLocked();

/**
 * Implementation of PBTSimple where transfers are locked from the public.
 */
contract PBTLocket is PBTSimple {
    using ECDSA for bytes32;

    mapping(uint256 => bool) _locks;
    mapping(uint256 => address) _giver;
    mapping(uint256 => address) _receiver;

    constructor(string memory name_, string memory symbol_) PBTSimple(name_, symbol_) {}

    modifier tokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != _msgSender()) revert InvalidOwner();
        _;
    }

    function transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig,
        bool useSafeTransferFrom
    ) public override {
        uint256 tokenId = _getTokenDataForChipSignature(signatureFromChip, blockNumberUsedInSig).tokenId;
        if (_locks[tokenId]) revert TokenLocked();
        if (useSafeTransferFrom) {
            _safeTransfer(ownerOf(tokenId), _msgSender(), tokenId, "");
        } else {
            _transfer(ownerOf(tokenId), _msgSender(), tokenId);
        }
    }

    function lock(uint256 tokenId) public tokenOwner(tokenId) {
        if (_giver[tokenId] == _msgSender() || _receiver[tokenId] == _msgSender()) {
            _giver[tokenId] = address(0);
            _receiver[tokenId] = address(0);
        } else if (ownerOf(tokenId) != _msgSender()) {
            revert InvalidOwner();
        }

        _locks[tokenId] = true;
    }

    function unlock(uint256 tokenId) public tokenOwner(tokenId) {
        _locks[tokenId] = false;
    }

    function unlockForReceiver(uint256 tokenId, address receiver) public tokenOwner(tokenId) {
        _locks[tokenId] = false;
        _giver[tokenId] = _msgSender();
        _receiver[tokenId] = receiver;
    }

    function checkLock(uint256 tokenId) public view returns (bool) {
        return _locks[tokenId];
    }
}
