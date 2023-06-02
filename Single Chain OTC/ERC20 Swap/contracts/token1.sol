// SPDX-License-Identifier: None
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract token1 is ERC20 {
    constructor() ERC20("Token1", "T1") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
