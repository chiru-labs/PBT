// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev Contract for PBTs (Physical-Bound Tokens).
 * NFTs that are backed by a physical asset, through a chip embedded in the physical asset.
 * Note: this assumes that the chip remains attached to the physical object. Enforcing that is out of scope here.
 * 
 * Extension to 721, in which the 721 implementation must not support public transfer methods that are not authenticated by a chip signature.
 * This is because such transfers would break any guarantees that an NFT is backed by the physical chip.
 * 
 * Note: the ERC-165 identifier for this interface is <todo>.
 * TODO: print interface id here.
 * 
 * 
 * 
 * (This part borrowed from https://github.com/Verilink/ERC721Physical) Requirements for such chip:
 * Capable of cryptographically secure generation of asymmetric key pairs
 * Capable of securely storing the private key of the asymmetric key pair with no interface
 * Capable of signing messages from the private key of the asymmetric key pair
 * Capable of retrieving the public key of the asymmetric key pair
 * There are no restrictions on the asymmetric cryptographic algorithm, communication methods, or power requirements.
 * The recommended chip is a passive device supporting NFC and secp256k1 ECC.
 * 
 */

interface IPBT {
    /// @notice Returns the token id for a given chip address.
    /// @dev Throws if there is no existing token for the chip in the collection.
    /// @param chipAddress The address for the chip embedded in the physical item (computed from the chip's public key).
    /// @return The token id for the passed in chip address.
    function tokenIdFor(address chipAddress)
        external
        view
        virtual
        returns (uint256);

    /// @notice Returns true if the chip for the specified token id is the signer of the signature of the payload.
    /// @dev Throws if tokenId does not exist in the collection.
    /// @param tokenId The token id.
    /// @param payload Arbitrary data that is signed by the chip to produce the signature param.
    /// @param signature Chip's signature of the passed-in payload.
    /// @return Whether the signature of the payload was signed by the chip linked to the token id.
    function isChipSignatureForToken(
        uint256 tokenId,
        bytes32 payload,
        bytes calldata signature
    )
        external
        view
        virtual
        returns (bool);

    /// @notice Transfers the token into the message sender's wallet.
    /// @param signatureFromChip An EIP-191 signature of (msgSender, blockhash), where blockhash is the block hash for blockNumberUsedInSig.
    /// @param blockNumberUsedInSig The block number linked to the blockhash signed in signatureFromChip. Should be a recent block number.
    /// @param useSafeTransferFrom Whether EIP-721's safeTransferFrom should be used in the implementation, instead of transferFrom.
    ///
    /// @dev The implementation should check that block number be reasonably recent to avoid replay attacks of stale signatures.
    /// The implementation should also verify that the address signed in the signature matches msgSender.
    /// If the address recovered from the signature matches a chip address that's bound to an existing token, the token should be transferred to msgSender.
    /// If there is no existing token linked to the chip, the function should error.
    function transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig,
        bool useSafeTransferFrom
    )
        external
        virtual;

    /// @notice Calls transferTokenWithChip as defined above, with useSafeTransferFrom set to false.
    function transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig
    )
        external
        virtual;

    /// @notice Emitted when a token is minted
    event PBTMint(uint256 indexed tokenId, address indexed chipAddress);

    /// @notice Emitted when a token is mapped to a different chip.
    /// Chip replacements may be useful in certain scenarios (e.g. chip defect).
    event PBTChipRemapping(
        uint256 indexed tokenId,
        address indexed oldChipAddress,
        address indexed newChipAddress
    );
}
