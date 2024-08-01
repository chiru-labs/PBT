// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Contract for PBTs (Physical Backed Tokens).
/// NFTs that are backed by a physical asset, through a chip embedded in the physical asset.
interface IPBT {
    /// @dev Returns the ERC-721 token ID for a given chip address.
    ///      Reverts if `chipId` has not been two-way-assigned to a token ID.
    ///      For minimalism, this will NOT revert if the `tokenId` does not exist.
    ///      If there is a need to check for token existence, external contracts can
    ///      call `ERC721.ownerOf(uint256 tokenId)` and check if it passes or reverts.
    /// @param chipId The address for the chip embedded in the physical item
    ///               (computed from the chip's public key).
    function tokenIdFor(address chipId) external view returns (uint256);

    /// @dev Returns true if `sig` is signed by the chip assigned to `tokenId`, else false.
    ///      Reverts if `tokenId` has not been two-way-assigned to a chip.
    ///      For minimalism, this will NOT revert if the `tokenId` does not exist.
    ///      If there is a need to check for token existence, external contracts can
    ///      call `ERC721.ownerOf(uint256 tokenId)` and check if it passes or reverts.
    /// @param tokenId ERC-721 token ID.
    /// @param data    Arbitrary bytes string that is signed by the chip to produce `sig`.
    /// @param sig     EIP-191 signature by the chip to check.
    function isChipSignatureForToken(uint256 tokenId, bytes calldata data, bytes calldata sig)
        external
        view
        returns (bool);

    /// @dev Transfers the token into the address.
    /// @param to                  The recipient. Dynamic to allow easier transfers to vaults.
    /// @param chipId              Chip ID (address) of chip being transferred.
    /// @param chipSig             EIP-191 signature by the chip to authorize the transfer.
    /// @param sigTimestamp        Timestamp used in `chipSig`.
    /// @param useSafeTransferFrom Whether ERC-721's `safeTransferFrom` should be used,
    ///                            instead of `transferFrom`.
    /// @param extras              Additional data that can be used for additional logic/context
    ///                            when the PBT is transferred.
    function transferToken(
        address to,
        address chipId,
        bytes calldata chipSig,
        uint256 sigTimestamp,
        bool useSafeTransferFrom,
        bytes calldata extras
    ) external;

    /// @dev Emitted when `chipId` is two-way-assigned to `tokenId`.
    /// `tokenId` may not necessarily exist during assignment.
    /// Indexers can combine this event with the {ERC721.Transfer} event to
    /// infer which tokens exists and have an assigned chip ID.
    event ChipSet(uint256 indexed tokenId, address indexed chipId);
}
