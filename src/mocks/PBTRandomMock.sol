// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../PBTRandom.sol";

contract PBTRandomMock is PBTRandom {
    constructor(string memory name_, string memory symbol_) PBTRandom(name_, symbol_, 1000) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function getTokenData(address addr) public view returns (TokenData memory) {
        return _tokenDatas[addr];
    }

    function updateChips(address[] calldata chipAddressesOld, address[] calldata chipAddressesNew) public {
        _updateChips(chipAddressesOld, chipAddressesNew);
    }

    function mintTokenWithChip(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig) public {
        _mintTokenWithChip(signatureFromChip, blockNumberUsedInSig);
    }

    function getTokenDataForChipSignature(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig)
        public
        returns (TokenData memory)
    {
        return _getTokenDataForChipSignature(signatureFromChip, blockNumberUsedInSig);
    }
}
