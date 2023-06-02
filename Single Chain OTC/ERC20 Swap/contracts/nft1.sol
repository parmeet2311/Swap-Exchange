//SPDX-License-Identifier: NONE
pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract nft1 is ERC721 {
    constructor() ERC721("nfts", "nfts") {}

    function mint(address collector, uint256 tokenId) public {
        _safeMint(collector, tokenId);
    }
}
