// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IPBT.sol";
import "./ERC721ReadOnly.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @dev Implementation of PBT where all chipId->tokenIds are preset in the contract by the contract owner.
contract PBTSimple is ERC721ReadOnly, IPBT {
    /// @dev Maximum duration for a signature to be valid since the timestamp
    ///      used in the signature.
    uint256 public immutable maxDurationWindow;

    /// @dev A mapping of the `chipId` to the nonce to be used in its signature.
    mapping(address chipId => uint256 nonce) public chipNonce;

    /// @dev Mapping of `tokenId` to `chipId`.
    ///      The `chipId` is the public address of the chip's private key, and cannot be zero.
    mapping(address chipId => uint256 tokenId) internal _tokenIds;

    /// @dev Mapping of `chipId` to `tokenId`.
    ///      If the `chipId` is the zero address,
    ///      it means that there is no chip assigned to the `tokenId`.
    mapping(uint256 tokenId => address chipId) internal _chipIds;

    error InvalidSignature();
    error NoMappedTokenForChip();
    error DigestTimestampInFuture();
    error DigestTimestampTooOld();
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
        bytes memory chipSig,
        uint256 sigTimestamp,
        bool useSafeTransfer,
        bytes memory /* extras */
    ) public virtual {
        _validateSigAndUpdateNonce(to, chipId, chipSig, sigTimestamp);
        _transferPBT(to, tokenIdFor(chipId), useSafeTransfer, "");
    }

    /// @dev Returns if `sig` is indeed signed by the `chipId` assigned to `tokenId` for `data.
    function isChipSignatureForToken(uint256 tokenId, bytes memory data, bytes memory sig)
        public
        view
        returns (bool)
    {
        bytes32 sigHash = ECDSA.toEthSignedMessageHash(keccak256(data));
        return SignatureChecker.isValidSignatureNow(_chipIds[tokenId], sigHash, sig);
    }

    /// @dev Returns the `tokenId` two-way-assigned to `chipId`.
    ///      Reverts if there is no assignment for `chipId`.
    function tokenIdFor(address chipId) public view returns (uint256 tokenId) {
        if (chipId == address(0)) revert ChipIdIsZeroAddress();
        tokenId = _tokenIds[chipId];
        if (_chipIds[tokenId] == address(0)) revert NoMappedTokenForChip();
    }

    /// @dev For ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPBT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Mints to `to`, using `chipId`.
    function _mintPBT(address to, address chipId, bytes memory chipSig, uint256 sigTimestamp)
        internal
        virtual
        returns (uint256 tokenId)
    {
        tokenId = _beforeMintPBT(to, chipId, chipSig, sigTimestamp);
        _mint(to, tokenId); // Reverts if `tokenId` already exists.
    }

    /// @dev Mints to `to`, using `chipId`. Performs a post transfer check.
    function _safeMintPBT(
        address to,
        address chipId,
        bytes memory chipSig,
        uint256 sigTimestamp,
        bytes memory data
    ) internal virtual returns (uint256 tokenId) {
        tokenId = _beforeMintPBT(to, chipId, chipSig, sigTimestamp);
        _safeMint(to, tokenId, data); // Reverts if `tokenId` already exists.
    }

    /// @dev Called at the beginning of `_mint` and `_safeMint` for 
    function _beforeMintPBT(address to, address chipId, bytes memory chipSig, uint256 sigTimestamp)
        internal
        virtual
        returns (uint256 tokenId)
    {
        _validateSigAndUpdateNonce(to, chipId, chipSig, sigTimestamp);
        // For PBT mints, we have to require that the `tokenId` has an assigned `chipId`.
        tokenId = _tokenIds[chipId];
        if (_chipIds[tokenId] == address(0)) revert NoMappedTokenForChip();
    }

    /// @dev Validates the `chipSig` and update the nonce for the future signature of `chipId`.
    function _validateSigAndUpdateNonce(
        address to,
        address chipId,
        bytes memory chipSig,
        uint256 sigTimestamp
    ) internal virtual {
        bytes32 sigHash = _sigHash(sigTimestamp, chipId, to);
        if (!SignatureChecker.isValidSignatureNow(chipId, sigHash, chipSig)) {
            revert InvalidSignature();
        }
        chipNonce[chipId] = uint256(sigHash) ^ uint256(blockhash(block.number - 1));
    }

    /// @dev Returns the digest to be signed by the `chipId`.
    function _sigHash(uint256 sigTimestamp, address chipId, address to)
        internal
        virtual
        returns (bytes32)
    {
        if (sigTimestamp > block.timestamp) revert DigestTimestampInFuture();
        if (sigTimestamp + maxDurationWindow < block.timestamp) revert DigestTimestampTooOld();
        bytes32 hash = keccak256(
            abi.encode(address(this), block.chainid, chipNonce[chipId], to, sigTimestamp)
        );
        return ECDSA.toEthSignedMessageHash(hash);
    }

    /// @dev Transfers a PBT to `to`.
    function _transferPBT(address to, uint256 tokenId, bool useSafeTransfer, bytes memory data)
        internal
    {
        if (useSafeTransfer) {
            _safeTransfer(ownerOf(tokenId), to, tokenId, data);
        } else {
            _transfer(ownerOf(tokenId), to, tokenId);
        }
    }

    /// @dev Two-way-assigns `chipId` to `tokenId`.
    /// `tokenId` does not need to exist during assignment.
    /// Emits a {ChipSet} event.
    /// - To change the `chipId`, use `_setChip(tokenIdFor(chipId), newChipId)`.
    /// - Use this in a loop if you need.
    function _setChip(uint256 tokenId, address chipId) internal {
        if (chipId == address(0)) revert ChipIdIsZeroAddress();
        _tokenIds[_chipIds[tokenId]] = 0;
        _tokenIds[chipId] = tokenId;
        _chipIds[tokenId] = chipId;
        emit ChipSet(tokenId, chipId);
    }
}
