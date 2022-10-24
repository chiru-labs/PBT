// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../PBTWithTransferAuth.sol";

contract PBTWithTransferAuthMock is PBTWithTransferAuth {
    constructor(string memory name_, string memory symbol_) PBTWithTransferAuth(name_, symbol_) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function seedChipToTokenMapping(
        address[] memory chipAddresses,
        uint256[] memory tokenIds,
        bool throwIfTokenAlreadyMinted
    ) public {
        _seedChipToTokenMapping(chipAddresses, tokenIds, throwIfTokenAlreadyMinted);
    }

    function getTokenData(address addr) public view returns (TokenData memory) {
        return _tokenDatas[addr];
    }

    function updateChips(address[] calldata chipAddressesOld, address[] calldata chipAddressesNew) public {
        _updateChips(chipAddressesOld, chipAddressesNew);
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

    function requestTransfers(uint256 _tokenId) public { 
        requestTransfer(_tokenId);
    }

    function actionTransferRequests(uint256 _tokenId, bool decision) public { 
        actionTransferRequest(_tokenId, decision);
    }
}
