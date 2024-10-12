// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IPBT.sol";
import "./ERC721ReadOnly.sol";
import "solady/utils/ECDSA.sol";
import "solady/utils/SignatureCheckerLib.sol";

/// @dev Implementation of PBT where all chipId->tokenIds are preset in the contract by the contract owner.
contract PBTSimple is ERC721ReadOnly, IPBT {
    /// @dev Maximum duration for a signature to be valid since the timestamp
    ///      used in the signature.
    uint256 public immutable maxDurationWindow;

    /// @dev A mapping of the `chipId` to the nonce to be used in its signature.
    mapping(address chipId => bytes32 nonce) public chipNonce;

    /// @dev Mapping of `tokenId` to `chipId`.
    ///      The `chipId` is the public address of the chip's private key, and cannot be zero.
    mapping(address chipId => uint256 tokenId) internal _tokenIds;

    /// @dev Mapping of `chipId` to `tokenId`.
    ///      If the `chipId` is the zero address,
    ///      it means that there is no `chipId` paired to the `tokenId`.
    mapping(uint256 tokenId => address chipId) internal _chipIds;

    /// @dev The signature is invalid.
    error InvalidSignature();

    /// @dev There is no `tokenId` paired to the `chipId`.
    error NoMappedTokenForChip();

    /// @dev The signature timestamp is in the future.
    error SignatureTimestampInFuture();

    /// @dev The signature timestamp has exceeded the max duration window.
    error SignatureTimestampTooOld();

    /// @dev The `chipId` cannot be the zero address.
    error ChipIdIsZeroAddress();

    constructor(string memory name, string memory symbol, uint256 maxDurationWindow_)
        ERC721ReadOnly(name, symbol)
    {
        maxDurationWindow = maxDurationWindow_;
    }

    /// @dev Transfers the `tokenId` assigned to `chipId` to `to`.
    function transferToken(
        address to,
        address chipId,
        bytes memory chipSignature,
        uint256 signatureTimestamp,
        bool useSafeTransfer,
        bytes memory extras
    ) public virtual returns (uint256 tokenId) {
        tokenId = tokenIdFor(chipId);
        _validateSigAndUpdateNonce(to, chipId, chipSignature, signatureTimestamp, extras);
        if (useSafeTransfer) {
            _safeTransfer(ownerOf(tokenId), to, tokenId, "");
        } else {
            _transfer(ownerOf(tokenId), to, tokenId);
        }
    }

    /// @dev Returns if `signature` is indeed signed by the `chipId` assigned to `tokenId` for `data.
    function isChipSignatureForToken(uint256 tokenId, bytes memory data, bytes memory signature)
        public
        view
        returns (bool)
    {
        bytes32 hash = ECDSA.toEthSignedMessageHash(keccak256(data));
        return SignatureCheckerLib.isValidSignatureNow(_chipIds[tokenId], hash, signature);
    }

    /// @dev Returns the `tokenId` paired to `chipId`.
    ///      Reverts if there is no pair for `chipId`.
    function tokenIdFor(address chipId) public view returns (uint256 tokenId) {
        if (chipId == address(0)) revert ChipIdIsZeroAddress();
        tokenId = _tokenIds[chipId];
        if (_chipIds[tokenId] != chipId) revert NoMappedTokenForChip();
    }

    /// @dev For ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPBT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Mints to `to`, using `chipId`.
    function _mint(address to, address chipId, bytes memory chipSignature, uint256 signatureTimestamp, bytes memory extras)
        internal
        virtual
        returns (uint256 tokenId)
    {
        tokenId = _beforeMint(to, chipId, chipSignature, signatureTimestamp, extras);
        _mint(to, tokenId); // Reverts if `tokenId` already exists.
    }

    /// @dev Mints to `to`, using `chipId`. Performs a post transfer check.
    function _safeMint(
        address to,
        address chipId,
        bytes memory chipSignature,
        uint256 signatureTimestamp,
        bytes memory extras,
        bytes memory data
    ) internal virtual returns (uint256 tokenId) {
        tokenId = _beforeMint(to, chipId, chipSignature, signatureTimestamp, extras);
        _safeMint(to, tokenId, data); // Reverts if `tokenId` already exists.
    }

    /// @dev Called at the beginning of `_mint` and `_safeMint` for 
    function _beforeMint(address to, address chipId, bytes memory chipSignature, uint256 signatureTimestamp, bytes memory extras)
        internal
        virtual
        returns (uint256 tokenId)
    {
        _validateSigAndUpdateNonce(to, chipId, chipSignature, signatureTimestamp, extras);
        // For PBT mints, we have to require that the `tokenId` has an assigned `chipId`.
        tokenId = _tokenIds[chipId];
        if (_chipIds[tokenId] == address(0)) revert NoMappedTokenForChip();
    }

    /// @dev Validates the `chipSignature` and update the nonce for the future signature of `chipId`.
    function _validateSigAndUpdateNonce(
        address to,
        address chipId,
        bytes memory chipSignature,
        uint256 signatureTimestamp,
        bytes memory extras
    ) internal virtual {
        bytes32 hash = _getSignatureHash(signatureTimestamp, chipId, to, extras);
        if (!SignatureCheckerLib.isValidSignatureNow(chipId, hash, chipSignature)) {
            revert InvalidSignature();
        }
        chipNonce[chipId] = bytes32(uint256(hash) ^ uint256(blockhash(block.number - 1)));
    }

    /// @dev Returns the digest to be signed by the `chipId`.
    function _getSignatureHash(uint256 signatureTimestamp, address chipId, address to, bytes memory extras)
        internal
        virtual
        returns (bytes32)
    {
        if (signatureTimestamp > block.timestamp) revert SignatureTimestampInFuture();
        if (signatureTimestamp + maxDurationWindow < block.timestamp) revert SignatureTimestampTooOld();
        bytes32 hash = keccak256(
            abi.encode(address(this), block.chainid, chipNonce[chipId], to, signatureTimestamp, keccak256(extras))
        );
        return ECDSA.toEthSignedMessageHash(hash);
    }

    /// @dev Pairs `chipId` to `tokenId`.
    /// `tokenId` does not need to exist during pairing.
    /// Emits a {ChipSet} event.
    /// - To use it on a `chipId`, use `_setChip(tokenIdFor(chipId), newChipId)`.
    /// - Use this in a loop if you need.
    function _setChip(uint256 tokenId, address chipId) internal {
        if (chipId == address(0)) revert ChipIdIsZeroAddress();
        _chipIds[tokenId] = chipId;
        _tokenIds[chipId] = tokenId;
        emit ChipSet(tokenId, chipId);
    }

    /// @dev Removes the pairing of `tokenId` to its `chipId`.
    /// - To use it on a `chipId`, use `_unsetChip(tokenIdFor(chipId))`.
    /// - Use this in a loop if you need.
    function _unsetChip(uint256 tokenId) internal {
        _chipIds[tokenId] = address(0);
        emit ChipSet(tokenId, address(0));
    }
}
