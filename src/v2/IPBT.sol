// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Contract for PBTs (Physical Backed Tokens).
/// NFTs that are backed by a physical asset, through a chip embedded in the physical asset.
interface IPBT {
    /// @notice Returns the ERC-721 token ID for a given chip address.
    /// @dev Throws if there is no existing token for the chip in the collection.
    /// @param chipId The address for the chip embedded in the physical item 
    ///               (computed from the chip's public key).
    function tokenIdFor(address chipId) external view returns (uint256);

    /// @notice Returns true if `sig` is signed by the chip assigned to `tokenId`, else false.
    /// @dev Throws if `tokenId` does not exist in the collection.
    /// @param tokenId ERC-721 token ID.
    /// @param data    Arbitrary bytes string that is signed by the chip to produce `sig`.
    /// @param sig     EIP-191 signature by the chip to check.
    function isChipSignatureForToken(uint256 tokenId, bytes calldata data, bytes calldata sig)
        external
        view
        returns (bool);

    /// @notice Transfers the token into the message sender's wallet.
    /// @param chipId              Chip ID (address) of chip being transferred.
    /// @param chipSig             EIP-191 signature by the chip to authorize the transfer.
    /// @param sigTimestamp        Timestamp used in `chipSig`.
    /// @param useSafeTransferFrom Whether ERC-721's `safeTransferFrom` should be used,
    ///                            instead of `transferFrom`.
    /// @param payload             Additional data that can be used for additional logic/context
    ///                            when the PBT is transferred.
    function transferToken(
        address chipId,
        bytes calldata chipSig,
        uint256 sigTimestamp,
        bool useSafeTransferFrom,
        bytes calldata payload
    ) external;

    /// @notice Emitted when `tokenId` is minted by `chipId`.
    event PBTMint(uint256 indexed tokenId, address indexed chipId);

    /// @notice Emitted when `tokenId` is mapped to a different chip.
    /// Chip replacements may be useful in certain scenarios (e.g. chip defect).
    event PBTChipRemapping(uint256 indexed tokenId, address indexed oldChipId, address indexed newChipId);
}
