//SPDX-License-Identifier: NONE
pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract nft2 is ERC721 {
    constructor() ERC721("nfts2", "nfts2") {}

    function mint(address collector, uint256 tokenId) public {
        _safeMint(collector, tokenId);
    }
}
