// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../PBTRandom.sol";

contract PBTRandomMock is PBTRandom {
    constructor(string memory name_, string memory symbol_, uint256 supply_) PBTRandom(name_, symbol_, supply_) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function getTokenData(address addr) public view returns (TokenData memory) {
        return _tokenDatas[addr];
    }

    function updateChips(address[] calldata chipAddressesOld, address[] calldata chipAddressesNew) public {
        _updateChips(chipAddressesOld, chipAddressesNew);
    }

    function seedChipAddresses(address[] calldata chipAddresses) public {
        _seedChipAddresses(chipAddresses);
    }

    function mintTokenWithChip(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig)
        public
        returns (uint256)
    {
        return _mintTokenWithChip(signatureFromChip, blockNumberUsedInSig);
    }

    function getTokenDataForChipSignature(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig)
        public
        view
        returns (TokenData memory)
    {
        return _getTokenDataForChipSignature(signatureFromChip, blockNumberUsedInSig);
    }

    function getAvailableRemainingTokens(uint256 index) public view returns (uint256) {
        return _availableRemainingTokens[index];
    }

    function useRandomAvailableTokenId() public returns (uint256) {
        return _useRandomAvailableTokenId();
    }
}
