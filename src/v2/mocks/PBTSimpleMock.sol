// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../PBTSimple.sol";

contract PBTSimpleMock is PBTSimple {
    constructor(string memory name_, string memory symbol_, uint256 maxDurationWindow_) PBTSimple(name_, symbol_, maxDurationWindow_) {}

    function setChip(uint256 tokenId, address chipId) public {
        _setChip(tokenId, chipId);
    }

    function unsetChip(uint256 tokenId) public {
        _unsetChip(tokenId);
    }

    function directGetTokenId(address chipId) public view returns (uint256) {
        return _tokenIds[chipId];
    }

    function directGetChipId(uint256 tokenId) public view returns (address) {
        return _chipIds[tokenId];
    }

    function mint(address to, address chipId, bytes memory chipSig, uint256 sigTimestamp, bytes memory extras) public returns (uint256) {
        return _mint(to, chipId, chipSig, sigTimestamp, extras);
    }
}
