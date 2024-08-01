// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IPBT.sol";
import "./ERC721ReadOnly.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @notice Implementation of PBT where all chipId->tokenIds are preset in the contract by the contract owner.
contract PBTSimple is ERC721ReadOnly, IPBT {
    /// @dev Mapping of token ID to chip ID.
    ///      The chip ID is the public address of the chip's private key, and cannot be zero.
    mapping(address chipId => uint256 tokenId) public chipIdToTokenId;

    /// @dev Mapping of chip ID to token ID.
    ///      If the chip ID is the zero address, it means that there is no chip assigned
    ///      to the token ID.
    mapping(uint256 tokenId => address chipId) public tokenIdToChipId;

    /// @dev A mapping of the chip ID to the previous nonce used in its signature.
    mapping(address chipId => uint256 nonce) public previousNonce;

    /// @dev Maximum duration for a signature to be valid since the timestamp
    ///      used in the signature.
    uint256 public immutable maxDurationWindow;

    error InvalidSignature();
    error NoMappedTokenForChip();
    error NoMintedTokenForChip();
    error ArrayLengthsMismatch();
    error SeedingChipDataForExistingToken();
    error InvalidBlockNumber();
    error BlockNumberTooOld();
    error NoSetTokenIdForChip();
    error DigestTimestampInFuture();
    error DigestTimestampTooOld();
    error ChipIdIsZeroAddress();

    constructor(string memory name, string memory symbol, uint256 maxDurationWindow_)
        ERC721ReadOnly(name, symbol)
    {
        maxDurationWindow = maxDurationWindow_;
    }

    function transferToken(
        address chipId,
        bytes calldata chipSig,
        uint256 sigTimestamp,
        bool useSafeTransfer,
        bytes calldata /* extras */
    ) public virtual {
        uint256 tokenId = tokenIdFor(chipId); // Reverts if there is no token assigned to `chipId`.
        bytes32 sigHash = _sigHash(sigTimestamp, chipId, msg.sender);
        if (!SignatureChecker.isValidSignatureNow(chipId, sigHash, chipSig)) {
            revert InvalidSignature();
        }
        previousNonce[chipId] = uint256(sigHash) ^ uint256(blockhash(block.number - 1));
        _transferPBT(ownerOf(tokenId), tokenId, useSafeTransfer);
    }

    function isChipSignatureForToken(uint256 tokenId, bytes calldata data, bytes calldata sig)
        public
        view
        returns (bool)
    {
        bytes32 sigHash = ECDSA.toEthSignedMessageHash(keccak256(data));
        return SignatureChecker.isValidSignatureNow(tokenIdToChipId[tokenId], sigHash, sig);
    }

    function tokenIdFor(address chipId) public view returns (uint256 tokenId) {
        if (chipId == address(0)) revert ChipIdIsZeroAddress();
        tokenId = chipIdToTokenId[chipId];
        if (tokenIdToChipId[tokenId] == address(0)) revert NoMappedTokenForChip();
        if (!_exists(tokenId)) revert NoMintedTokenForChip();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPBT).interfaceId || super.supportsInterface(interfaceId);
    }

    function _mint(address to, address chipId, bytes calldata chipSig, uint256 sigTimestamp)
        internal
        virtual
        returns (uint256 tokenId)
    {
        bytes32 sigHash = _sigHash(sigTimestamp, chipId, to);
        // `isValidSignatureNow` will be false if `chipId` is zero.
        if (!SignatureChecker.isValidSignatureNow(chipId, sigHash, chipSig)) {
            revert InvalidSignature();
        }
        previousNonce[chipId] = uint256(sigHash) ^ uint256(blockhash(block.number - 1));
        tokenId = chipIdToTokenId[chipId];
        if (tokenIdToChipId[tokenId] == address(0)) revert NoMappedTokenForChip();
        _mint(to, tokenId); // Reverts if `tokenId` already exists.
        emit PBTMint(tokenId, chipId);
    }

    /// @dev Returns the digest to be signed by the `chipId`.
    function _sigHash(uint256 sigTimestamp, address chipId, address nftRecipient)
        internal
        virtual
        returns (bytes32)
    {
        if (sigTimestamp > block.timestamp) revert DigestTimestampInFuture();
        if (sigTimestamp + maxDurationWindow < block.timestamp) revert DigestTimestampTooOld();
        bytes32 hash = keccak256(
            abi.encode(
                address(this), block.chainid, previousNonce[chipId], nftRecipient, sigTimestamp
            )
        );
        return ECDSA.toEthSignedMessageHash(hash);
    }

    function _transferPBT(address from, uint256 tokenId, bool useSafeTransfer) internal {
        if (useSafeTransfer) {
            _safeTransfer(from, msg.sender, tokenId, "");
        } else {
            _transfer(from, msg.sender, tokenId);
        }
    }

    function _seedChipToTokenMapping(address[] memory chipIds, uint256[] memory tokenIds)
        internal
    {
        _seedChipToTokenMapping(chipIds, tokenIds, true);
    }

    function _seedChipToTokenMapping(
        address[] memory chipIds,
        uint256[] memory tokenIds,
        bool revertIfTokenExists
    ) internal {
        uint256 tokenIdsLength = tokenIds.length;
        if (tokenIdsLength != chipIds.length) revert ArrayLengthsMismatch();
        for (uint256 i; i < tokenIdsLength; ++i) {
            address chipId = chipIds[i];
            if (chipId == address(0)) revert ChipIdIsZeroAddress();
            uint256 tokenId = tokenIds[i];
            if (revertIfTokenExists && _exists(tokenId)) revert SeedingChipDataForExistingToken();
            chipIdToTokenId[chipId] = tokenId;
            tokenIdToChipId[tokenId] = chipId;
        }
    }

    function _updateChips(address[] calldata chipIdsOld, address[] calldata chipIdsNew) internal {
        if (chipIdsOld.length != chipIdsNew.length) revert ArrayLengthsMismatch();
        for (uint256 i; i < chipIdsOld.length; ++i) {
            address oldChipId = chipIdsOld[i];
            address newChipId = chipIdsNew[i];
            if (oldChipId == address(0)) revert ChipIdIsZeroAddress();
            if (newChipId == address(0)) revert ChipIdIsZeroAddress();
            uint256 tokenId = chipIdToTokenId[oldChipId];
            chipIdToTokenId[oldChipId] = 0;
            chipIdToTokenId[newChipId] = tokenId;
            tokenIdToChipId[tokenId] = newChipId;
            if (_exists(tokenId)) emit PBTChipRemapping(tokenId, oldChipId, newChipId);
        }
    }
}
