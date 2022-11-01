// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IPBT.sol";
import "./ERC721Readonly.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

error InvalidSignature();
error InvalidChipAddress();
error NoMintedTokenForChip();
error ArrayLengthMismatch();
error ChipAlreadyLinkedToMintedToken();
error UpdatingChipForUnsetChipMapping();
error InvalidRandomIndex();
error InvalidBlockNumber();
error BlockNumberTooOld();

/**
 * Implementation of PBT where all tokenIds are randomly chosen at mint time.
 */
contract PBTRandom is ERC721ReadOnly, IPBT {
    using ECDSA for bytes32;

    struct TokenData {
        uint128 tokenId;
        address chipAddress;
        bool set;
    }

    // Mapping from chipAddress to TokenData
    mapping(address => TokenData) _tokenDatas;

    // Max token supply
    uint128 public immutable maxSupply;
    uint128 private _numAvailableRemainingTokens;

    // Data structure used for Fisher Yates shuffle
    mapping(uint128 => uint128) internal _availableRemainingTokens;

    constructor(string memory name_, string memory symbol_, uint128 maxSupply_) ERC721ReadOnly(name_, symbol_) {
        maxSupply = maxSupply_;
        _numAvailableRemainingTokens = maxSupply_;
    }

    function _seedChipAddresses(address[] memory chipAddresses) internal {
        for (uint256 i = 0; i < chipAddresses.length; ++i) {
            address chipAddress = chipAddresses[i];
            _tokenDatas[chipAddress] = TokenData(0, chipAddress, false);
        }
    }

    // TODO: consider preventing multiple chip addresses mapping to the same tokenId (store a tokenId->chip mapping)
    function _updateChips(address[] calldata chipAddressesOld, address[] calldata chipAddressesNew) internal {
        if (chipAddressesOld.length != chipAddressesNew.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < chipAddressesOld.length; i++) {
            address oldChipAddress = chipAddressesOld[i];
            TokenData memory oldTokenData = _tokenDatas[oldChipAddress];
            if (!oldTokenData.set) {
                revert UpdatingChipForUnsetChipMapping();
            }
            address newChipAddress = chipAddressesNew[i];
            uint128 tokenId = oldTokenData.tokenId;
            _tokenDatas[newChipAddress] = TokenData(tokenId, newChipAddress, true);
            emit PBTChipRemapping(tokenId, oldChipAddress, newChipAddress);
            delete _tokenDatas[oldChipAddress];
        }
    }

    function tokenIdFor(address chipAddress) external view override returns (uint256) {
        TokenData memory tokenData = _tokenDatas[chipAddress];
        if (!tokenData.set) {
            revert NoMintedTokenForChip();
        }
        return tokenData.tokenId;
    }

    // Returns true if the signer of the signature of the payload is the chip for the token id
    function isChipSignatureForToken(uint256 tokenId, bytes memory payload, bytes memory signature)
        public
        view
        override
        returns (bool)
    {
        if (!_exists(tokenId)) {
            revert NoMintedTokenForChip();
        }
        bytes32 signedHash = keccak256(payload).toEthSignedMessageHash();
        address chipAddr = signedHash.recover(signature);
        TokenData memory tokenData = _tokenDatas[chipAddr];
        return tokenData.set && tokenData.tokenId == tokenId;
    }

    //
    // Parameters:
    //    to: the address of the new owner
    //    signatureFromChip: signature(receivingAddress + recentBlockhash), signed by an approved chip
    //
    // Contract should check that (1) recentBlockhash is a recent blockhash, (2) receivingAddress === to, and (3) the signing chip is allowlisted.
    function _mintTokenWithChip(bytes memory signatureFromChip, uint256 blockNumberUsedInSig)
        internal
        returns (uint256)
    {
        address chipAddr = _getChipAddrForChipSignature(signatureFromChip, blockNumberUsedInSig);

        TokenData memory tokenData = _tokenDatas[chipAddr];
        if (tokenData.set) {
            revert ChipAlreadyLinkedToMintedToken();
        } else if (tokenData.chipAddress != chipAddr) {
            revert InvalidChipAddress();
        }

        uint128 tokenId = _useRandomAvailableTokenId();
        _mint(_msgSender(), tokenId);
        _tokenDatas[chipAddr] = TokenData(tokenId, chipAddr, true);

        emit PBTMint(tokenId, chipAddr);

        return tokenId;
    }

    // Generates a pseudorandom number between [0,maxSupply) that has not yet been generated before, in O(1) time.
    //
    // Uses Durstenfeld's version of the Yates Shuffle https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle
    // with a twist to avoid having to manually spend gas to preset an array's values to be values 0...n.
    // It does this by interpreting zero-values for an index X as meaning that index X itself is an available value
    // that is returnable.
    //
    // How it works:
    //  - zero-initialize a mapping (_availableRemainingTokens) and track its length (_numAvailableRemainingTokens). functionally similar to an array with dynamic sizing
    //    - this mapping will track all remaining valid values that haven't been generated yet, through a combination of its indices and values
    //      - if _availableRemainingTokens[x] == 0, that means x has not been generated yet
    //      - if _availableRemainingTokens[x] != 0, that means _availableRemainingTokens[x] has not been generated yet
    //  - when prompted for a random number between [0,maxSupply) that hasn't already been used:
    //    - generate a random index randIndex between [0,_numAvailableRemainingTokens)
    //    - examine the value at _availableRemainingTokens[randIndex]
    //        - if the value is zero, it means randIndex has not been used, so we can return randIndex
    //        - if the value is non-zero, it means the value has not been used, so we can return _availableRemainingTokens[randIndex]
    //    - update the _availableRemainingTokens mapping state
    //        - set _availableRemainingTokens[randIndex] to either the index or the value of the last entry in the mapping (depends on the last entry's state)
    //        - decrement _numAvailableRemainingTokens to mimic the shrinking of an array
    function _useRandomAvailableTokenId() internal returns (uint128) {
        uint128 numAvailableRemainingTokens = _numAvailableRemainingTokens;

        // Devs can swap this out for something less gameable like chainlink if it makes sense for their use case.
        uint256 randomNum = uint256(
            keccak256(
                abi.encode(
                    _msgSender(),
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    address(this),
                    numAvailableRemainingTokens
                )
            )
        );
        uint128 randomIndex = uint128(randomNum % numAvailableRemainingTokens);
        return _getAvailableTokenAtIndex(randomIndex);
    }

    function _getAvailableTokenAtIndex(uint128 indexToUse) internal returns (uint128) {
        uint128 numAvailableRemainingTokens = _numAvailableRemainingTokens;
        if (indexToUse >= numAvailableRemainingTokens) {
            revert InvalidRandomIndex();
        }

        uint128 valAtIndex = _availableRemainingTokens[indexToUse];
        uint128 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint128 lastIndex = numAvailableRemainingTokens - 1;
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            uint128 lastValInArray = _availableRemainingTokens[lastIndex];
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                _availableRemainingTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                _availableRemainingTokens[indexToUse] = lastValInArray;
                delete _availableRemainingTokens[lastIndex];
            }
        }

        _numAvailableRemainingTokens--;

        return result;
    }

    function transferTokenWithChip(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig) public override {
        transferTokenWithChip(signatureFromChip, blockNumberUsedInSig, false);
    }

    function transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig,
        bool useSafeTransferFrom
    ) public override {
        _transferTokenWithChip(signatureFromChip, blockNumberUsedInSig, useSafeTransferFrom);
    }

    function _transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig,
        bool useSafeTransferFrom
    ) internal virtual {
        TokenData memory tokenData = _getTokenDataForChipSignature(signatureFromChip, blockNumberUsedInSig);
        uint128 tokenId = tokenData.tokenId;
        if (useSafeTransferFrom) {
            _safeTransfer(ownerOf(tokenId), _msgSender(), tokenId, "");
        } else {
            _transfer(ownerOf(tokenId), _msgSender(), tokenId);
        }
    }

    function _getTokenDataForChipSignature(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig)
        internal
        view
        returns (TokenData memory)
    {
        address chipAddr = _getChipAddrForChipSignature(signatureFromChip, blockNumberUsedInSig);
        TokenData memory tokenData = _tokenDatas[chipAddr];
        if (tokenData.set) {
            return tokenData;
        }
        revert InvalidSignature();
    }

    function _getChipAddrForChipSignature(bytes memory signatureFromChip, uint256 blockNumberUsedInSig)
        internal
        view
        returns (address)
    {
        // The blockNumberUsedInSig must be in a previous block because the blockhash of the current
        // block does not exist yet.
        if (block.number <= blockNumberUsedInSig) {
            revert InvalidBlockNumber();
        }

        if (block.number - blockNumberUsedInSig > getMaxBlockhashValidWindow()) {
            revert BlockNumberTooOld();
        }

        bytes32 blockHash = blockhash(blockNumberUsedInSig);
        bytes32 signedHash = keccak256(abi.encodePacked(_msgSender(), blockHash)).toEthSignedMessageHash();
        return signedHash.recover(signatureFromChip);
    }

    function getMaxBlockhashValidWindow() public pure virtual returns (uint256) {
        return 100;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPBT).interfaceId || super.supportsInterface(interfaceId);
    }
}
